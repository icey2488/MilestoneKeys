-- ============================================================
-- MilestoneKeys - UI.lua
-- Configuration panel built with AceGUI-3.0.
-- Opens via /mk  or  /milestonekeys
-- ============================================================

local AG = LibStub("AceGUI-3.0")

-- -------------------------------------------------------
-- Called from Core.lua:OnInitialize
-- -------------------------------------------------------
function MK_UI_Init(MK)

    -- ── Slash commands ──────────────────────────────────
    SLASH_MILESTONEKEYS1 = "/mk"
    SLASH_MILESTONEKEYS2 = "/milestonekeys"
    SlashCmdList["MILESTONEKEYS"] = function(arg)
        if arg == "test" then
            local kLevel = MK:GetKeystoneLevel()
            MK_TriggerAlert(
                { label = "Test Alert", alertType = "sound_chat" },
                42.7,
                kLevel > 0 and kLevel or 10
            )
        elseif arg == "" then
            MK_UI_Toggle(MK)
        else
            print("|cffF5B80E[MilestoneKeys]|r Unknown command '|cffFFFFFF" .. arg .. "|r'. Use |cffFFFFFF/mk test|r or |cffFFFFFF/mk|r.")
        end
    end
end

-- -------------------------------------------------------
-- Panel singleton
-- -------------------------------------------------------
local Panel = nil

local function BuildPanel(MK)
    local selectedMapID    = nil   -- nil = global profile
    local RebuildList      = nil   -- forward declaration (assigned below)
    local refreshMDTRoutes = nil   -- forward declaration (assigned after MDT section)

    local frame = AG:Create("Frame")
    frame:SetTitle("MilestoneKeys  |cffF5B80Ev1.0|r")
    frame:SetStatusText("Set force % milestones for Mythic+ runs")
    frame:SetWidth(560)
    frame:SetHeight(720)
    frame:SetLayout("Flow")

    -- ====================================================
    -- SECTION: Dungeon profile selector
    -- ====================================================
    local profileSep = AG:Create("Heading")
    profileSep:SetFullWidth(true)
    profileSep:SetText("Profile")
    frame:AddChild(profileSep)

    local dungeonDrop = AG:Create("Dropdown")
    dungeonDrop:SetLabel("Editing profile for")
    dungeonDrop:SetWidth(280)

    local function BuildDungeonList()
        local list  = { global = "|cffFFFFFFGlobal (all dungeons)|r" }
        local order = { "global" }
        local ok, mapTable = pcall(function() return C_ChallengeMode.GetMapTable() end)
        if ok and type(mapTable) == "table" then
            for _, mapID in ipairs(mapTable) do
                local name = C_ChallengeMode.GetMapUIInfo(mapID)
                if name then
                    local key = tostring(mapID)
                    list[key] = name
                    table.insert(order, key)
                end
            end
        end
        return list, order
    end

    local dList, dOrder = BuildDungeonList()
    dungeonDrop:SetList(dList, dOrder)
    dungeonDrop:SetValue("global")
    dungeonDrop:SetCallback("OnValueChanged", function(_, _, val)
        selectedMapID = (val == "global") and nil or tonumber(val)
        if RebuildList then RebuildList() end
        if refreshMDTRoutes then refreshMDTRoutes() end
    end)
    frame:AddChild(dungeonDrop)

    -- ====================================================
    -- SECTION: Milestones list
    -- ====================================================
    local headerLabel = AG:Create("Label")
    headerLabel:SetText("|cffF5B80EMilestones|r")
    headerLabel:SetFullWidth(true)
    headerLabel:SetFontObject(GameFontNormalLarge)
    frame:AddChild(headerLabel)

    local sep1 = AG:Create("Heading")
    sep1:SetFullWidth(true)
    sep1:SetText("")
    frame:AddChild(sep1)

    local scrollFrame = AG:Create("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetHeight(180)
    scrollFrame:SetLayout("Flow")
    frame:AddChild(scrollFrame)

    RebuildList = function()
        scrollFrame:ReleaseChildren()
        local milestones = MK:GetMilestones(selectedMapID)

        if #milestones == 0 then
            local empty = AG:Create("Label")
            if selectedMapID then
                empty:SetText("|cff888888No milestones for this dungeon yet. Add one below.|r")
            else
                empty:SetText("|cff888888No milestones yet. Add one below.|r")
            end
            empty:SetFullWidth(true)
            scrollFrame:AddChild(empty)
            return
        end

        for i, ms in ipairs(milestones) do
            -- Row container
            local row = AG:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")

            -- ── Enabled checkbox ─────────────────────
            local chk = AG:Create("CheckBox")
            chk:SetLabel("")
            chk:SetValue(ms.enabled)
            chk:SetWidth(28)
            chk:SetCallback("OnValueChanged", function(_, _, val)
                MK:UpdateMilestone(i, "enabled", val, selectedMapID)
            end)
            row:AddChild(chk)

            -- ── Threshold edit box ────────────────────
            local pctBox = AG:Create("EditBox")
            pctBox:SetLabel("")
            pctBox:SetText(tostring(ms.threshold))
            pctBox:SetWidth(50)
            pctBox:SetCallback("OnEnterPressed", function(_, _, val)
                local num = math.floor(tonumber(val) or 0)
                if num >= 1 and num <= 100 then
                    local list = MK:GetMilestones(selectedMapID)
                    local duplicate = false
                    for j, other in ipairs(list) do
                        if j ~= i and other.threshold == num then
                            duplicate = true
                            break
                        end
                    end
                    if not duplicate then
                        MK:UpdateMilestone(i, "threshold", num, selectedMapID)
                        MK:SortMilestones(selectedMapID)
                    end
                end
                RebuildList()
            end)
            row:AddChild(pctBox)

            -- ── Label edit box ────────────────────────
            local labelBox = AG:Create("EditBox")
            labelBox:SetLabel("")
            labelBox:SetText(ms.label)
            labelBox:SetWidth(180)
            labelBox:SetCallback("OnEnterPressed", function(_, _, val)
                MK:UpdateMilestone(i, "label", val, selectedMapID)
                labelBox:ClearFocus()
            end)
            row:AddChild(labelBox)

            -- ── Alert type dropdown ───────────────────
            local alertDrop = AG:Create("Dropdown")
            alertDrop:SetLabel("")
            alertDrop:SetWidth(120)
            alertDrop:SetList(
                {
                    sound_chat = "All Alerts",
                    sound      = "Sound Only",
                    chat       = "Chat Only",
                    frame      = "Frame Only",
                },
                { "sound_chat", "sound", "chat", "frame" }
            )
            alertDrop:SetValue(ms.alertType or "sound_chat")
            alertDrop:SetCallback("OnValueChanged", function(_, _, val)
                MK:UpdateMilestone(i, "alertType", val, selectedMapID)
            end)
            row:AddChild(alertDrop)

            -- ── Delete button ─────────────────────────
            local delBtn = AG:Create("Button")
            delBtn:SetText("✕")
            delBtn:SetWidth(36)
            delBtn:SetCallback("OnClick", function()
                MK:RemoveMilestone(i, selectedMapID)
                RebuildList()
            end)
            row:AddChild(delBtn)

            scrollFrame:AddChild(row)
        end
    end

    -- ====================================================
    -- SECTION: Add new milestone
    -- ====================================================
    local sep2 = AG:Create("Heading")
    sep2:SetFullWidth(true)
    sep2:SetText("Add Milestone")
    frame:AddChild(sep2)

    local newThreshold = 50
    local sliderLabel  = AG:Create("Label")
    sliderLabel:SetText(string.format("Threshold: |cff00FF96%d%%|r", newThreshold))
    sliderLabel:SetWidth(160)
    frame:AddChild(sliderLabel)

    local slider = AG:Create("Slider")
    slider:SetSliderValues(1, 100, 1)
    slider:SetValue(newThreshold)
    slider:SetLabel("Force %")
    slider:SetWidth(200)
    slider:SetCallback("OnValueChanged", function(_, _, val)
        newThreshold = val
        sliderLabel:SetText(string.format("Threshold: |cff00FF96%d%%|r", val))
    end)
    frame:AddChild(slider)

    local newLabelBox = AG:Create("EditBox")
    newLabelBox:SetLabel("Label")
    newLabelBox:SetWidth(200)
    newLabelBox:SetText("My Milestone")
    frame:AddChild(newLabelBox)

    local addBtn = AG:Create("Button")
    addBtn:SetText("Add Milestone")
    addBtn:SetWidth(130)
    addBtn:SetCallback("OnClick", function()
        local lbl = newLabelBox:GetText()
        if lbl == "" then lbl = string.format("%d%% Forces", newThreshold) end
        if MK:AddMilestone(newThreshold, lbl, "sound_chat", selectedMapID) then
            newLabelBox:SetText("My Milestone")
            RebuildList()
        else
            print("|cffF5B80E[MilestoneKeys]|r A milestone at |cff00FF96" .. newThreshold .. "%%|r already exists.")
        end
    end)
    frame:AddChild(addBtn)

    -- ====================================================
    -- SECTION: Settings
    -- ====================================================
    local sep3 = AG:Create("Heading")
    sep3:SetFullWidth(true)
    sep3:SetText("Settings")
    frame:AddChild(sep3)

    -- Sound picker
    local soundDrop = AG:Create("Dropdown")
    soundDrop:SetLabel("Alert Sound")
    soundDrop:SetWidth(180)
    soundDrop:SetList(
        { alarm = "Alarm Horn", gong = "Gong", levelup = "Level Up" },
        { "alarm", "gong", "levelup" }
    )
    soundDrop:SetValue(MK.db.profile.alertSound)
    soundDrop:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.alertSound = val
    end)
    frame:AddChild(soundDrop)

    -- Chat output toggle
    local chatChk = AG:Create("CheckBox")
    chatChk:SetLabel("Chat output")
    chatChk:SetValue(MK.db.profile.chatOutput)
    chatChk:SetWidth(160)
    chatChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.chatOutput = val
    end)
    frame:AddChild(chatChk)

    -- Frame alert toggle
    local frameChk = AG:Create("CheckBox")
    frameChk:SetLabel("On-screen frame alerts")
    frameChk:SetValue(MK.db.profile.frameAlerts)
    frameChk:SetWidth(200)
    frameChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.frameAlerts = val
    end)
    frame:AddChild(frameChk)

    -- Minimap button toggle
    local minimapChk = AG:Create("CheckBox")
    minimapChk:SetLabel("Show minimap button")
    minimapChk:SetValue(MK.db.profile.options.minimapEnabled)
    minimapChk:SetWidth(200)
    minimapChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.minimapEnabled = val
        if MK._dbicon then
            if val then
                MK._dbicon:Show("MilestoneKeys")
            else
                MK._dbicon:Hide("MilestoneKeys")
            end
        end
    end)
    frame:AddChild(minimapChk)

    -- Per-dungeon profiles toggle
    local perDungeonChk = AG:Create("CheckBox")
    perDungeonChk:SetLabel("Per-dungeon profiles (uses above profile during run)")
    perDungeonChk:SetValue(MK.db.profile.options.perDungeonProfiles)
    perDungeonChk:SetFullWidth(true)
    perDungeonChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.perDungeonProfiles = val
    end)
    frame:AddChild(perDungeonChk)

    -- Party sync toggle
    local syncChk = AG:Create("CheckBox")
    syncChk:SetLabel("Broadcast milestones to party")
    syncChk:SetValue(MK.db.profile.options.partySync)
    syncChk:SetWidth(240)
    syncChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.partySync = val
    end)
    frame:AddChild(syncChk)

    -- Predictive alerts toggle
    local predictChk = AG:Create("CheckBox")
    predictChk:SetLabel("MDT predictive pull alerts")
    predictChk:SetValue(MK.db.profile.options.predictiveAlerts)
    predictChk:SetWidth(220)
    predictChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.predictiveAlerts = val
    end)
    frame:AddChild(predictChk)

    -- Test button
    local sep4 = AG:Create("Heading")
    sep4:SetFullWidth(true)
    sep4:SetText("")
    frame:AddChild(sep4)

    local testBtn = AG:Create("Button")
    testBtn:SetText("Test Alert  (/mk test)")
    testBtn:SetWidth(180)
    testBtn:SetCallback("OnClick", function()
        local kLevel = MK:GetKeystoneLevel()
        MK_TriggerAlert(
            { label = "Test Milestone", alertType = "sound_chat" },
            42.7,
            kLevel > 0 and kLevel or 10
        )
    end)
    frame:AddChild(testBtn)

    -- ====================================================
    -- SECTION: MDT Route Import  (Predict.lua)
    -- ====================================================
    refreshMDTRoutes = MK_Predict_BuildUI(MK, frame, function() return selectedMapID end)

    -- ── Close cleans up reference ──────────────────────
    frame:SetCallback("OnClose", function(widget)
        AG:Release(widget)
        Panel = nil
    end)

    RebuildList()

    return frame
end

-- -------------------------------------------------------
-- Toggle
-- -------------------------------------------------------
function MK_UI_Toggle(MK)
    if Panel then
        AG:Release(Panel)
        Panel = nil
    else
        Panel = BuildPanel(MK)
    end
end
