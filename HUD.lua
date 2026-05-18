-- ============================================================
-- MilestoneKeys - HUD.lua
-- Persistent in-run milestone tracker frame.
-- Visible only during an active M+ key.
-- Left-drag to reposition; position auto-saved on drag stop.
-- ============================================================

local HudFrame     = nil
local HudRows      = {}   -- { frame, label, strike, flashGroup, originalIndex }
local HudMK        = nil
local IsPreviewMode = false

local ROW_HEIGHT    = 20
local HEADER_HEIGHT = 26
local PADDING       = 4
local SIDE_PAD      = 12

local function SaveHudPos(profile)
    local point, _, _, x, y = HudFrame:GetPoint(1)
    profile.hudFramePos = { point = point, x = x, y = y }
end

local function ApplyHudPos(profile)
    HudFrame:ClearAllPoints()
    local pos = profile.hudFramePos
    if pos then
        HudFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        HudFrame:SetPoint("RIGHT", UIParent, "RIGHT", -20, 0)
    end
end

local function RebuildHudRows()
    for _, row in ipairs(HudRows) do
        row.frame:Hide()
    end
    HudRows = {}

    local milestones = HudMK:GetActiveDungeonProfile()
    local rowCount   = 0

    for i, ms in ipairs(milestones) do
        if ms.enabled then
            rowCount = rowCount + 1
            local yOff = -(HEADER_HEIGHT + PADDING + (rowCount - 1) * ROW_HEIGHT)

            local rowFrame = CreateFrame("Frame", nil, HudFrame)
            rowFrame:SetHeight(ROW_HEIGHT)
            rowFrame:SetPoint("TOPLEFT", HudFrame, "TOPLEFT",  SIDE_PAD, yOff)
            rowFrame:SetPoint("RIGHT",   HudFrame, "RIGHT",   -SIDE_PAD, 0)
            rowFrame:Show()

            local lbl = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
            lbl:SetAllPoints(rowFrame)
            lbl:SetJustifyH("LEFT")
            lbl:SetJustifyV("MIDDLE")
            lbl:SetTextColor(0.9, 0.9, 0.9, 1)
            lbl:SetText(string.format("%s  •  %s", MK_FormatForces(ms.threshold, nil, nil), ms.label))

            local strike = rowFrame:CreateTexture(nil, "OVERLAY")
            strike:SetHeight(1)
            strike:SetPoint("LEFT",  rowFrame, "LEFT",  0, 0)
            strike:SetPoint("RIGHT", rowFrame, "RIGHT", 0, 0)
            strike:SetColorTexture(0.7, 0.7, 0.7, 0.8)
            strike:Hide()

            local ag       = rowFrame:CreateAnimationGroup()
            local flashOut = ag:CreateAnimation("Alpha")
            flashOut:SetOrder(1)
            flashOut:SetDuration(0.1)
            flashOut:SetFromAlpha(1)
            flashOut:SetToAlpha(0.3)
            local flashIn  = ag:CreateAnimation("Alpha")
            flashIn:SetOrder(2)
            flashIn:SetDuration(0.3)
            flashIn:SetFromAlpha(0.3)
            flashIn:SetToAlpha(1)
            ag:SetScript("OnFinished", function()
                lbl:SetTextColor(0.53, 0.53, 0.53, 1)
                strike:Show()
            end)

            table.insert(HudRows, {
                frame         = rowFrame,
                label         = lbl,
                strike        = strike,
                flashGroup    = ag,
                originalIndex = i,
            })
        end
    end

    local totalHeight = HEADER_HEIGHT + PADDING + rowCount * ROW_HEIGHT + PADDING
    HudFrame:SetHeight(math.max(totalHeight, 50))
end

-- -------------------------------------------------------
-- Public API
-- -------------------------------------------------------
function MK_HUD_Init(MK)
    HudMK = MK
    local profile = MK.db.profile

    HudFrame = CreateFrame("Frame", "MilestoneKeysHUDFrame", UIParent, "BackdropTemplate")
    HudFrame:SetWidth(280)
    HudFrame:SetHeight(50)
    HudFrame:SetFrameStrata("MEDIUM")
    HudFrame:SetClampedToScreen(true)
    HudFrame:Hide()

    HudFrame:SetBackdrop({
        bgFile  = "Interface\\Buttons\\WHITE8x8",
        tile    = false, tileSize = 0,
        insets  = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    HudFrame:SetBackdropColor(0, 0, 0, profile.hudFrameAlpha or 0.8)

    local accent = HudFrame:CreateTexture(nil, "BORDER")
    accent:SetWidth(4)
    accent:SetPoint("TOPLEFT",    HudFrame, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", HudFrame, "BOTTOMLEFT", 0, 0)
    accent:SetColorTexture(0.96, 0.69, 0.13, 1)

    local header = HudFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    header:SetPoint("TOPLEFT", HudFrame, "TOPLEFT",  SIDE_PAD, -PADDING)
    header:SetPoint("RIGHT",   HudFrame, "RIGHT",   -SIDE_PAD, 0)
    header:SetJustifyH("LEFT")
    header:SetText("|cffF5B80EMilestones|r")

    HudFrame:RegisterForDrag("LeftButton")
    HudFrame:SetScript("OnDragStart", function(self)
        if self:IsMovable() then self:StartMoving() end
    end)
    HudFrame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveHudPos(profile)
    end)

    ApplyHudPos(profile)
    MK_HUD_SetLocked(profile.hudLocked or false)
end

function MK_HUD_OnRunStart()
    if not HudMK.db.profile.options.showHUD then return end
    RebuildHudRows()
    if #HudRows > 0 then
        HudFrame:Show()
    end
end

function MK_HUD_OnRunEnd()
    IsPreviewMode = false
    if HudFrame then HudFrame:Hide() end
end

function MK_HUD_OnMilestoneTriggered(index)
    for _, row in ipairs(HudRows) do
        if row.originalIndex == index then
            row.flashGroup:Stop()
            row.flashGroup:Play()
            break
        end
    end
end

function MK_HUD_SetAlpha(alpha)
    if HudFrame then HudFrame:SetBackdropColor(0, 0, 0, alpha) end
end

function MK_HUD_SetLocked(locked)
    if not HudFrame then return end
    if locked then
        HudFrame:SetMovable(false)
        HudFrame:EnableMouse(false)
    else
        HudFrame:SetMovable(true)
        HudFrame:EnableMouse(true)
    end
end

function MK_HUD_TogglePreview()
    if not HudFrame then return end
    IsPreviewMode = not IsPreviewMode
    if IsPreviewMode then
        RebuildHudRows()
        HudFrame:Show()
    elseif not HudMK:IsRunActive() then
        HudFrame:Hide()
    end
end

function MK_HUD_IsPreview()
    return IsPreviewMode
end
