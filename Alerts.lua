-- ============================================================
-- MilestoneKeys - Alerts.lua
-- Handles the three alert delivery modes:
--   sound_chat  →  plays a sound + prints to chat
--   sound       →  plays a sound only
--   frame       →  large on-screen flash frame
-- ============================================================

-- -------------------------------------------------------
-- Sound definitions
-- -------------------------------------------------------
local SOUNDS = {
    alarm   = (SOUNDKIT and SOUNDKIT.UI_RAID_WARNING)           or 567478,
    gong    = (SOUNDKIT and SOUNDKIT.UI_CHALLENGE_MODE_COMPLETE) or 568633,
    levelup = (SOUNDKIT and SOUNDKIT.UI_PLAYER_LEVEL_UP)        or 888079,
}

local SOUND_FALLBACK = SOUNDKIT and SOUNDKIT.UI_RAID_WARNING or 567478

-- Public accessor so UI.lua can preview sounds without duplicating the table.
function MK_GetSoundID(key)
    return SOUNDS[key] or SOUND_FALLBACK
end

-- -------------------------------------------------------
-- Alert frame  (created once, reused)
-- -------------------------------------------------------
local AlertFrame
local LockMenu

local function SaveFramePos(profile)
    local point, _, _, x, y = AlertFrame:GetPoint(1)
    profile.alertFramePos = { point = point, x = x, y = y }
end

local function ApplyFramePos(profile)
    local pos = profile.alertFramePos
    if pos then
        AlertFrame:ClearAllPoints()
        AlertFrame:SetPoint(pos.point, UIParent, pos.point, pos.x, pos.y)
    else
        AlertFrame:ClearAllPoints()
        AlertFrame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end
end

local function ShowLockMenu(frame)
    if not LockMenu then
        LockMenu = CreateFrame("Frame", "MKAlertLockMenu", UIParent, "UIDropDownMenuTemplate")
    end

    UIDropDownMenu_Initialize(LockMenu, function(_, level)
        local MK      = _G["MilestoneKeys"]
        local profile = MK.db.profile
        local info    = UIDropDownMenu_CreateInfo()

        info.text         = "Alert Frame"
        info.isTitle      = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info              = UIDropDownMenu_CreateInfo()
        info.text         = "Lock Position"
        info.notCheckable = true
        info.func         = function()
            SaveFramePos(profile)
            frame:SetMovable(false)
            frame:EnableMouse(false)
        end
        UIDropDownMenu_AddButton(info, level)

        info              = UIDropDownMenu_CreateInfo()
        info.text         = "Unlock Position"
        info.notCheckable = true
        info.func         = function()
            frame:SetMovable(true)
            frame:EnableMouse(true)
        end
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, LockMenu, "cursor", 0, -3)
end

local function GetAlertFrame()
    if AlertFrame then return AlertFrame end

    local MK      = _G["MilestoneKeys"]
    local profile = MK.db.profile

    AlertFrame = CreateFrame("Frame", "MilestoneKeysAlertFrame", UIParent)
    AlertFrame:SetSize(420, 70)
    AlertFrame:SetFrameStrata("HIGH")
    AlertFrame:SetClampedToScreen(true)
    AlertFrame:Hide()

    -- Draggable by default
    AlertFrame:SetMovable(true)
    AlertFrame:EnableMouse(true)
    AlertFrame:RegisterForDrag("LeftButton")
    AlertFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    AlertFrame:SetScript("OnDragStop",  function(self)
        self:StopMovingOrSizing()
        -- Auto-save position whenever the player moves the frame
        SaveFramePos(profile)
    end)

    -- Right-click → lock/unlock menu
    AlertFrame:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" then
            ShowLockMenu(self)
        end
    end)

    -- Backdrop
    local bg = AlertFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.72)

    -- Accent bar (left edge)
    local accent = AlertFrame:CreateTexture(nil, "BORDER")
    accent:SetSize(4, 70)
    accent:SetPoint("LEFT", AlertFrame, "LEFT", 0, 0)
    accent:SetColorTexture(0.96, 0.69, 0.13, 1)

    -- Icon (forces skull)
    local icon = AlertFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(40, 40)
    icon:SetPoint("LEFT", AlertFrame, "LEFT", 16, 0)
    icon:SetTexture("Interface\\Icons\\Achievement_Dungeon_GloryoftheHero")
    AlertFrame.icon = icon

    -- Milestone label
    local title = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", AlertFrame, "TOPLEFT", 64, -10)
    title:SetPoint("RIGHT", AlertFrame, "RIGHT", -12, 0)
    title:SetTextColor(0.96, 0.69, 0.13, 1)
    title:SetJustifyH("LEFT")
    AlertFrame.title = title

    -- Sub-label (forces %)
    local sub = AlertFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    sub:SetPoint("BOTTOMLEFT", AlertFrame, "BOTTOMLEFT", 64, 10)
    sub:SetPoint("RIGHT", AlertFrame, "RIGHT", -12, 0)
    sub:SetTextColor(0.9, 0.9, 0.9, 1)
    sub:SetJustifyH("LEFT")
    AlertFrame.sub = sub

    -- Border
    local border = CreateFrame("Frame", nil, AlertFrame, "BackdropTemplate")
    border:SetAllPoints()
    border:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
    })
    border:SetBackdropBorderColor(0.96, 0.69, 0.13, 0.6)

    -- Animation group: fade in → hold → fade out
    local ag = AlertFrame:CreateAnimationGroup()

    local fadeIn = ag:CreateAnimation("Alpha")
    fadeIn:SetOrder(1)
    fadeIn:SetDuration(0.2)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)

    local hold = ag:CreateAnimation("Alpha")
    hold:SetOrder(2)
    hold:SetDuration(2.8)
    hold:SetFromAlpha(1)
    hold:SetToAlpha(1)

    local fadeOut = ag:CreateAnimation("Alpha")
    fadeOut:SetOrder(3)
    fadeOut:SetDuration(0.5)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)

    ag:SetScript("OnPlay", function()
        AlertFrame:Show()
        AlertFrame:SetAlpha(0)
    end)
    ag:SetScript("OnFinished", function()
        AlertFrame:Hide()
    end)

    AlertFrame.anim = ag

    -- Restore saved position and alpha
    ApplyFramePos(profile)
    AlertFrame:SetAlpha(profile.alertFrameAlpha or 1.0)

    return AlertFrame
end

-- Called from UI.lua to get the live frame reference for the alpha slider.
function MK_GetAlertFrame()
    return GetAlertFrame()
end

-- -------------------------------------------------------
-- Main entry point  (called from Core.lua)
-- -------------------------------------------------------

-- Check whether alertType includes a specific output mode (plain substring).
-- Handles legacy values ("sound_chat", "sound", "chat", "frame") and new
-- combinations ("sound_chat_frame", "sound_frame", "chat_frame", "none").
local function hasAlert(aType, flag)
    return aType and aType:find(flag, 1, true) ~= nil
end

-- quantity/total are the raw C_Scenario values; nil when called from /mk test.
function MK_TriggerAlert(milestone, currentPct, keystoneLevel, quantity, total)
    local MK      = _G["MilestoneKeys"]
    local profile = MK.db.profile
    local aType   = milestone.alertType or "sound_chat"
    local opts    = profile.options

    -- Build a forces string once, shared by chat and frame output.
    local forcesStr
    if opts.showNominalForces and quantity and total then
        forcesStr = string.format("%d/%d forces", quantity, total)
    else
        local dec = opts.forcesDecimals or 1
        forcesStr = string.format("%." .. dec .. "f%% forces", currentPct)
    end

    -- ── Sound ────────────────────────────────────────────
    if hasAlert(aType, "sound") then
        local soundId = SOUNDS[profile.alertSound] or SOUND_FALLBACK
        PlaySound(soundId, "Master")
    end

    -- ── Chat ─────────────────────────────────────────────
    if hasAlert(aType, "chat") and profile.chatOutput then
        local msg = string.format(
            "|cffF5B80E[MilestoneKeys]|r |cffFFFFFF%s|r — |cff00FF96%s|r (+%d)",
            milestone.label,
            forcesStr,
            keystoneLevel
        )
        print(msg)
    end

    -- ── Frame ─────────────────────────────────────────────
    if hasAlert(aType, "frame") and profile.frameAlerts then
        local f = GetAlertFrame()
        f.title:SetText(milestone.label)
        f.sub:SetText(string.format("%s  •  +%d Key", forcesStr, keystoneLevel))
        f.anim:Stop()
        f.anim:Play()
    end
end
