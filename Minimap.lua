-- ============================================================
-- MilestoneKeys - Minimap.lua
-- LibDBIcon-1.0 minimap launcher button.
-- Left-click: toggle config panel.
-- Right-click: compact dropdown (Enable All / Disable All / Test).
-- Tooltip: live forces % when a key is active.
-- ============================================================

local DropdownFrame

local function ShowRightClickMenu(MK)
    if not DropdownFrame then
        DropdownFrame = CreateFrame("Frame", "MKMinimapDropdown", UIParent, "UIDropDownMenuTemplate")
    end

    UIDropDownMenu_Initialize(DropdownFrame, function(_, level)
        local info = UIDropDownMenu_CreateInfo()

        info.text         = "MilestoneKeys"
        info.isTitle      = true
        info.notCheckable = true
        UIDropDownMenu_AddButton(info, level)

        info              = UIDropDownMenu_CreateInfo()
        info.text         = "Enable All Milestones"
        info.notCheckable = true
        info.func         = function()
            for _, ms in ipairs(MK:GetMilestones()) do
                ms.enabled = true
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info              = UIDropDownMenu_CreateInfo()
        info.text         = "Disable All Milestones"
        info.notCheckable = true
        info.func         = function()
            for _, ms in ipairs(MK:GetMilestones()) do
                ms.enabled = false
            end
        end
        UIDropDownMenu_AddButton(info, level)

        info              = UIDropDownMenu_CreateInfo()
        info.text         = "Test Alert"
        info.notCheckable = true
        info.func         = function()
            local kLevel = MK:GetKeystoneLevel()
            MK_TriggerAlert(
                { label = "Test Alert", alertType = "sound_chat" },
                42.7,
                kLevel > 0 and kLevel or 10
            )
        end
        UIDropDownMenu_AddButton(info, level)
    end, "MENU")

    ToggleDropDownMenu(1, nil, DropdownFrame, "cursor", 0, -3)
end

function MK_Minimap_Init(MK)
    local LDB    = LibStub("LibDataBroker-1.1")
    local DBIcon = LibStub("LibDBIcon-1.0")

    local broker = LDB:NewDataObject("MilestoneKeys", {
        type  = "launcher",
        icon  = "Interface\\Icons\\Achievement_Dungeon_GloryoftheHero",
        label = "MilestoneKeys",
        OnClick = function(_, button)
            if button == "LeftButton" then
                MK_UI_Toggle(MK)
            elseif button == "RightButton" then
                ShowRightClickMenu(MK)
            end
        end,
        OnTooltipShow = function(tt)
            tt:AddLine("|cffF5B80EMilestoneKeys|r")
            if MK:IsRunActive() then
                tt:AddLine(
                    string.format("Forces: |cff00FF96%.1f%%|r", MK:GetCurrentForcesPercent()),
                    1, 1, 1
                )
            else
                tt:AddLine("|cff888888No active key|r", 1, 1, 1)
            end
            tt:AddLine(" ")
            tt:AddLine("|cffFFFFFFLeft-click:|r  Open config",  0.8, 0.8, 0.8)
            tt:AddLine("|cffFFFFFFRight-click:|r Options menu", 0.8, 0.8, 0.8)
        end,
    })

    DBIcon:Register("MilestoneKeys", broker, MK.db.profile.minimapPos)

    if not MK.db.profile.options.minimapEnabled then
        DBIcon:Hide("MilestoneKeys")
    end

    MK._dbicon = DBIcon
end
