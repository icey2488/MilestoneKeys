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
    local RebuildList      = nil   -- forward declaration
    local refreshMDTRoutes = nil   -- forward declaration

    -- Tracked so RebuildList can hide stale native close buttons.
    local activeCloseBtns = {}

    -- ── Outer frame ─────────────────────────────────────
    local frame = AG:Create("Frame")
    frame:SetTitle("MilestoneKeys  |cffF5B80Ev1.0|r")
    frame:SetStatusText("Set force % milestones for Mythic+ runs")
    frame:SetWidth(540)
    frame:SetHeight(520)
    frame:SetLayout("Fill")

    -- Single scrollable container holding all sections.
    local outerScroll = AG:Create("ScrollFrame")
    outerScroll:SetFullWidth(true)
    outerScroll:SetFullHeight(true)
    outerScroll:SetLayout("Flow")
    frame:AddChild(outerScroll)

    -- ====================================================
    -- SECTION: Dungeon profile selector
    -- ====================================================
    local profileSep = AG:Create("Heading")
    profileSep:SetFullWidth(true)
    profileSep:SetText("Profile")
    outerScroll:AddChild(profileSep)

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
    outerScroll:AddChild(dungeonDrop)

    -- ====================================================
    -- SECTION: Milestones list
    -- ====================================================
    local headerLabel = AG:Create("Label")
    headerLabel:SetText("|cffF5B80EMilestones|r")
    headerLabel:SetFullWidth(true)
    headerLabel:SetFontObject(GameFontNormalLarge)
    outerScroll:AddChild(headerLabel)

    local sep1 = AG:Create("Heading")
    sep1:SetFullWidth(true)
    sep1:SetText("")
    outerScroll:AddChild(sep1)

    local scrollFrame = AG:Create("ScrollFrame")
    scrollFrame:SetFullWidth(true)
    scrollFrame:SetHeight(180)
    scrollFrame:SetLayout("Flow")
    outerScroll:AddChild(scrollFrame)

    RebuildList = function()
        -- Hide stale native close buttons before AceGUI releases the rows.
        for _, btn in ipairs(activeCloseBtns) do
            btn:Hide()
        end
        wipe(activeCloseBtns)

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
            labelBox:SetWidth(155)
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

            scrollFrame:AddChild(row)

            -- ── Delete: native UIPanelCloseButton ─────
            -- Parented to row.frame so it scrolls with the list.
            -- Hidden at the top of each RebuildList to avoid stale copies
            -- persisting on pooled AceGUI frames.
            local delBtn = CreateFrame("Button", nil, row.frame, "UIPanelCloseButton")
            delBtn:SetSize(24, 24)
            delBtn:SetPoint("RIGHT", row.frame, "RIGHT", -2, 0)
            delBtn:SetScript("OnClick", function()
                delBtn:Hide()
                MK:RemoveMilestone(i, selectedMapID)
                RebuildList()
            end)
            table.insert(activeCloseBtns, delBtn)
        end
    end

    -- ====================================================
    -- SECTION: Add new milestone
    -- ====================================================
    local sep2 = AG:Create("Heading")
    sep2:SetFullWidth(true)
    sep2:SetText("Add Milestone")
    outerScroll:AddChild(sep2)

    local newThreshold = 50
    local sliderLabel  = AG:Create("Label")
    sliderLabel:SetText(string.format("Threshold: |cff00FF96%d%%|r", newThreshold))
    sliderLabel:SetWidth(160)
    outerScroll:AddChild(sliderLabel)

    local slider = AG:Create("Slider")
    slider:SetSliderValues(1, 100, 1)
    slider:SetValue(newThreshold)
    slider:SetLabel("Force %")
    slider:SetWidth(200)
    slider:SetCallback("OnValueChanged", function(_, _, val)
        newThreshold = val
        sliderLabel:SetText(string.format("Threshold: |cff00FF96%d%%|r", val))
    end)
    outerScroll:AddChild(slider)

    local newLabelBox = AG:Create("EditBox")
    newLabelBox:SetLabel("Label")
    newLabelBox:SetWidth(200)
    newLabelBox:SetText("My Milestone")
    outerScroll:AddChild(newLabelBox)

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
    outerScroll:AddChild(addBtn)

    -- ====================================================
    -- SECTION: Settings
    -- ====================================================
    local sep3 = AG:Create("Heading")
    sep3:SetFullWidth(true)
    sep3:SetText("Settings")
    outerScroll:AddChild(sep3)

    -- Alert Sound — radio-style list with per-sound preview, like BigWigs.
    local soundLabel = AG:Create("Label")
    soundLabel:SetText("Alert Sound")
    soundLabel:SetFullWidth(true)
    outerScroll:AddChild(soundLabel)

    local SOUND_LIST = {
        { key = "alarm",   label = "Alarm Horn" },
        { key = "gong",    label = "Gong" },
        { key = "levelup", label = "Level Up" },
    }

    local soundChkMap = {}

    for _, snd in ipairs(SOUND_LIST) do
        local row = AG:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        outerScroll:AddChild(row)

        local chk = AG:Create("CheckBox")
        chk:SetLabel(snd.label)
        chk:SetValue(MK.db.profile.alertSound == snd.key)
        chk:SetWidth(185)
        chk:SetCallback("OnValueChanged", function(_, _, val)
            if not val then chk:SetValue(true); return end
            MK.db.profile.alertSound = snd.key
            for k, c in pairs(soundChkMap) do
                if k ~= snd.key then c:SetValue(false) end
            end
        end)
        soundChkMap[snd.key] = chk
        row:AddChild(chk)

        local playBtn = AG:Create("Button")
        playBtn:SetText("\226\150\182")  -- UTF-8 bytes for ▶
        playBtn:SetWidth(36)
        playBtn:SetCallback("OnClick", function()
            PlaySound(MK_GetSoundID(snd.key), "Master")
        end)
        row:AddChild(playBtn)
    end

    -- Chat output toggle
    local chatChk = AG:Create("CheckBox")
    chatChk:SetLabel("Chat output")
    chatChk:SetValue(MK.db.profile.chatOutput)
    chatChk:SetWidth(160)
    chatChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.chatOutput = val
    end)
    outerScroll:AddChild(chatChk)

    -- Frame alert toggle
    local frameChk = AG:Create("CheckBox")
    frameChk:SetLabel("On-screen frame alerts")
    frameChk:SetValue(MK.db.profile.frameAlerts)
    frameChk:SetWidth(200)
    frameChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.frameAlerts = val
    end)
    outerScroll:AddChild(frameChk)

    -- Alert frame opacity slider
    local alphaSlider = AG:Create("Slider")
    alphaSlider:SetLabel("Alert Frame Opacity")
    alphaSlider:SetSliderValues(0.2, 1.0, 0.05)
    alphaSlider:SetValue(MK.db.profile.alertFrameAlpha or 1.0)
    alphaSlider:SetWidth(200)
    alphaSlider:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.alertFrameAlpha = val
        local af = MK_GetAlertFrame()
        if af then af:SetAlpha(val) end
    end)
    outerScroll:AddChild(alphaSlider)

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
    outerScroll:AddChild(minimapChk)

    -- Per-dungeon profiles toggle
    local perDungeonChk = AG:Create("CheckBox")
    perDungeonChk:SetLabel("Per-dungeon profiles (uses above profile during run)")
    perDungeonChk:SetValue(MK.db.profile.options.perDungeonProfiles)
    perDungeonChk:SetFullWidth(true)
    perDungeonChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.perDungeonProfiles = val
    end)
    outerScroll:AddChild(perDungeonChk)

    -- Party sync toggle
    local syncChk = AG:Create("CheckBox")
    syncChk:SetLabel("Broadcast milestones to party")
    syncChk:SetValue(MK.db.profile.options.partySync)
    syncChk:SetWidth(240)
    syncChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.partySync = val
    end)
    outerScroll:AddChild(syncChk)

    -- Predictive alerts toggle
    local predictChk = AG:Create("CheckBox")
    predictChk:SetLabel("MDT predictive pull alerts")
    predictChk:SetValue(MK.db.profile.options.predictiveAlerts)
    predictChk:SetWidth(220)
    predictChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.predictiveAlerts = val
    end)
    outerScroll:AddChild(predictChk)

    -- Test button
    local sep4 = AG:Create("Heading")
    sep4:SetFullWidth(true)
    sep4:SetText("")
    outerScroll:AddChild(sep4)

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
    outerScroll:AddChild(testBtn)

    -- ====================================================
    -- SECTION: MDT Route Import  (Predict.lua)
    -- ====================================================
    refreshMDTRoutes = MK_Predict_BuildUI(MK, outerScroll, function() return selectedMapID end)

    -- ── Close cleans up reference ──────────────────────
    frame:SetCallback("OnClose", function(widget)
        for _, btn in ipairs(activeCloseBtns) do
            btn:Hide()
        end
        wipe(activeCloseBtns)
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
