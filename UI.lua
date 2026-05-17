-- ============================================================
-- MilestoneKeys - UI.lua
-- Configuration panel built with AceGUI-3.0.
-- Opens via /mk  or  /milestonekeys
-- ============================================================

local AG = LibStub("AceGUI-3.0")

-- Alert-type helpers: encode/decode independent sound/chat/frame flags as a
-- plain substring string so all combinations are backward-compatible.
local function ParseAlertFlags(aType)
    aType = aType or "sound_chat"
    return {
        sound = aType:find("sound", 1, true) ~= nil,
        chat  = aType:find("chat",  1, true) ~= nil,
        frame = aType:find("frame", 1, true) ~= nil,
    }
end

local function FlagsToAlertType(flags)
    local parts = {}
    if flags.sound then table.insert(parts, "sound") end
    if flags.chat  then table.insert(parts, "chat")  end
    if flags.frame then table.insert(parts, "frame") end
    return #parts > 0 and table.concat(parts, "_") or "none"
end

-- Attach a hover tooltip to an AceGUI widget.
-- Hooks the outer frame plus interactive children (Dropdown button, Slider thumb)
-- so the tip reliably fires regardless of which element the cursor lands on.
local function AddTooltip(widget, title, body)
    local function showTip(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end
    local function hideTip() GameTooltip:Hide() end
    widget.frame:SetScript("OnEnter", showTip)
    widget.frame:SetScript("OnLeave", hideTip)
    if widget.button then   -- Dropdown toggle button eats mouse before outer frame
        widget.button:HookScript("OnEnter", showTip)
        widget.button:HookScript("OnLeave", hideTip)
    end
    if widget.slider then   -- Slider thumb eats mouse before outer frame
        widget.slider:HookScript("OnEnter", showTip)
        widget.slider:HookScript("OnLeave", hideTip)
    end
end

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
                { label = "Test Alert", alertType = "sound_chat_frame" },
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
    frame:SetTitle("MilestoneKeys  |cffF5B80Ev1.1|r")
    frame:SetStatusText("Set force % milestones for Mythic+ runs")
    frame:SetWidth(820)
    frame:SetHeight(620)
    frame:SetLayout("Fill")

    -- Off-screen safety: clear saved position if the frame would land off-screen.
    local uiState = MK.db.profile.uiState
    if uiState.left and uiState.top then
        local screenW = GetScreenWidth()
        local screenH = GetScreenHeight()
        local fw = uiState.width  or 820
        local fh = uiState.height or 620
        if uiState.left > screenW or uiState.top > screenH
           or uiState.left + fw < 0 or uiState.top - fh > screenH then
            uiState.left, uiState.top = nil, nil
        end
    end
    frame:SetStatusTable(uiState)

    -- Minimum size guard (SetResizeBounds is the modern API; fall back to SetMinResize).
    if frame.frame.SetResizeBounds then
        frame.frame:SetResizeBounds(700, 450)
    elseif frame.frame.SetMinResize then
        frame.frame:SetMinResize(700, 450)
    end

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

    -- Auto-select the dungeon the player is currently in (unless overridden this session).
    local autoMapID, autoReason = nil, nil
    if not MK.sessionManualDungeonOverride then
        autoMapID, autoReason = MK:GetCurrentDungeonContext()
    end

    local initialDropVal = "global"
    if autoMapID then
        initialDropVal = tostring(autoMapID)
        selectedMapID  = autoMapID
    end

    local function GetContextText(reason)
        if reason == "active_key" then
            return "|cFF40FF40\xF0\x9F\x93\x8D Current key|r"
        elseif reason == "in_instance" then
            return "|cFFFFCC40\xF0\x9F\x93\x8D Current dungeon|r"
        end
        return ""
    end

    local profileRow = AG:Create("SimpleGroup")
    profileRow:SetFullWidth(true)
    profileRow:SetLayout("Flow")
    outerScroll:AddChild(profileRow)

    local dungeonDrop = AG:Create("Dropdown")
    dungeonDrop:SetLabel("Editing profile for")
    dungeonDrop:SetWidth(280)

    local contextLabel = AG:Create("Label")
    contextLabel:SetWidth(160)
    contextLabel:SetText(GetContextText(autoReason))

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
    dungeonDrop:SetValue(initialDropVal)
    dungeonDrop:SetCallback("OnValueChanged", function(_, _, val)
        MK.sessionManualDungeonOverride = true
        contextLabel:SetText("")
        selectedMapID = (val == "global") and nil or tonumber(val)
        if RebuildList then RebuildList() end
        if refreshMDTRoutes then refreshMDTRoutes() end
    end)
    profileRow:AddChild(dungeonDrop)
    profileRow:AddChild(contextLabel)

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

    -- Column headers aligned to the milestone row controls below
    local hdrRow = AG:Create("SimpleGroup")
    hdrRow:SetFullWidth(true)
    hdrRow:SetLayout("Flow")
    local function MkHdr(text, w)
        local l = AG:Create("Label")
        l:SetText("|cffF5B80E" .. text .. "|r")
        l:SetFontObject(GameFontNormalSmall)
        l:SetWidth(w)
        return l
    end
    hdrRow:AddChild(MkHdr("On",       28))
    hdrRow:AddChild(MkHdr("Forces %", 50))
    hdrRow:AddChild(MkHdr("Label",   110))
    hdrRow:AddChild(MkHdr("Alerts",  200))
    outerScroll:AddChild(hdrRow)

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
            labelBox:SetWidth(110)
            labelBox:SetCallback("OnEnterPressed", function(_, _, val)
                MK:UpdateMilestone(i, "label", val, selectedMapID)
                labelBox:ClearFocus()
            end)
            row:AddChild(labelBox)

            -- ── Per-output checkboxes + All / None ────
            local flags = ParseAlertFlags(ms.alertType)

            local sndChk = AG:Create("CheckBox")
            sndChk:SetLabel("Sound")
            sndChk:SetWidth(70)
            sndChk:SetValue(flags.sound)
            sndChk:SetCallback("OnValueChanged", function(_, _, val)
                flags.sound = val
                MK:UpdateMilestone(i, "alertType", FlagsToAlertType(flags), selectedMapID)
            end)
            row:AddChild(sndChk)

            local chatChk = AG:Create("CheckBox")
            chatChk:SetLabel("Chat")
            chatChk:SetWidth(65)
            chatChk:SetValue(flags.chat)
            chatChk:SetCallback("OnValueChanged", function(_, _, val)
                flags.chat = val
                MK:UpdateMilestone(i, "alertType", FlagsToAlertType(flags), selectedMapID)
            end)
            row:AddChild(chatChk)

            local frmChk = AG:Create("CheckBox")
            frmChk:SetLabel("Frame")
            frmChk:SetWidth(70)
            frmChk:SetValue(flags.frame)
            frmChk:SetCallback("OnValueChanged", function(_, _, val)
                flags.frame = val
                MK:UpdateMilestone(i, "alertType", FlagsToAlertType(flags), selectedMapID)
            end)
            row:AddChild(frmChk)

            local allBtn = AG:Create("Button")
            allBtn:SetText("All")
            allBtn:SetWidth(50)
            allBtn:SetCallback("OnClick", function()
                flags.sound = true; flags.chat = true; flags.frame = true
                sndChk:SetValue(true); chatChk:SetValue(true); frmChk:SetValue(true)
                MK:UpdateMilestone(i, "alertType", FlagsToAlertType(flags), selectedMapID)
            end)
            row:AddChild(allBtn)

            local noneBtn = AG:Create("Button")
            noneBtn:SetText("None")
            noneBtn:SetWidth(70)
            noneBtn:SetCallback("OnClick", function()
                flags.sound = false; flags.chat = false; flags.frame = false
                sndChk:SetValue(false); chatChk:SetValue(false); frmChk:SetValue(false)
                MK:UpdateMilestone(i, "alertType", FlagsToAlertType(flags), selectedMapID)
            end)
            row:AddChild(noneBtn)

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
        local k   = snd.key  -- explicit per-iteration capture for closures
        local row = AG:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        outerScroll:AddChild(row)

        local chk = AG:Create("CheckBox")
        chk:SetLabel(snd.label)
        chk:SetValue(MK.db.profile.alertSound == k)
        chk:SetWidth(185)
        chk:SetCallback("OnValueChanged", function(_, _, val)
            if not val then chk:SetValue(true); return end
            MK.db.profile.alertSound = k
            for key, c in pairs(soundChkMap) do
                if key ~= k then c:SetValue(false) end
            end
        end)
        soundChkMap[k] = chk
        row:AddChild(chk)

        local playBtn = AG:Create("Button")
        playBtn:SetText("Play")
        playBtn:SetWidth(60)
        playBtn:SetCallback("OnClick", function()
            MK_PlaySound(k)
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
    AddTooltip(chatChk, "Chat Output", "Print a message to chat when a milestone is crossed.")

    -- Frame alert toggle
    local frameChk = AG:Create("CheckBox")
    frameChk:SetLabel("On-screen frame alerts")
    frameChk:SetValue(MK.db.profile.frameAlerts)
    frameChk:SetWidth(200)
    frameChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.frameAlerts = val
    end)
    outerScroll:AddChild(frameChk)
    AddTooltip(frameChk, "On-Screen Frame Alerts", "Show a large banner on screen when a milestone is crossed.")

    -- Forces display: single dropdown covering all format options
    local displayDrop = AG:Create("Dropdown")
    displayDrop:SetLabel("Forces display")
    displayDrop:SetWidth(240)
    displayDrop:SetList(
        {
            ["pct_0"]   = "Percentage  (85%)",
            ["pct_1"]   = "Percentage  (84.9%)",
            ["pct_2"]   = "Percentage  (84.94%)",
            ["nominal"] = "Nominal  (382/450)",
        },
        { "pct_0", "pct_1", "pct_2", "nominal" }
    )
    displayDrop:SetValue(MK.db.profile.options.forcesDisplayMode or "pct_0")
    displayDrop:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.forcesDisplayMode = val
    end)
    outerScroll:AddChild(displayDrop)
    AddTooltip(displayDrop, "Forces Display",
        "How forces are shown in alerts and tooltips.\nNominal: raw count (e.g. 382/450). Percentage: e.g. 84.9%.")

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
    AddTooltip(alphaSlider, "Alert Frame Opacity",
        "Transparency of the on-screen alert banner.\n0.2 = nearly invisible  •  1.0 = fully opaque.")

    -- HUD frame opacity slider
    local hudAlphaSlider = AG:Create("Slider")
    hudAlphaSlider:SetLabel("HUD Frame Opacity")
    hudAlphaSlider:SetSliderValues(0.1, 1.0, 0.05)
    hudAlphaSlider:SetValue(MK.db.profile.hudFrameAlpha or 0.8)
    hudAlphaSlider:SetWidth(200)
    hudAlphaSlider:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.hudFrameAlpha = val
        MK_HUD_SetAlpha(val)
    end)
    outerScroll:AddChild(hudAlphaSlider)
    AddTooltip(hudAlphaSlider, "HUD Frame Opacity",
        "Transparency of the in-run milestone tracker.\n0.1 = nearly invisible  •  1.0 = fully opaque.")

    -- HUD preview toggle
    local hudPreviewBtn = AG:Create("Button")
    hudPreviewBtn:SetText(MK_HUD_IsPreview() and "Hide HUD Preview" or "Preview HUD")
    hudPreviewBtn:SetWidth(160)
    hudPreviewBtn:SetCallback("OnClick", function()
        MK_HUD_TogglePreview()
        hudPreviewBtn:SetText(MK_HUD_IsPreview() and "Hide HUD Preview" or "Preview HUD")
    end)
    outerScroll:AddChild(hudPreviewBtn)
    AddTooltip(hudPreviewBtn, "Preview HUD",
        "Show or hide the milestone HUD outside of a key\nso you can reposition and inspect it.")

    -- HUD lock checkbox
    local hudLockChk = AG:Create("CheckBox")
    hudLockChk:SetLabel("Lock HUD position")
    hudLockChk:SetValue(MK.db.profile.hudLocked or false)
    hudLockChk:SetWidth(180)
    hudLockChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.hudLocked = val
        MK_HUD_SetLocked(val)
    end)
    outerScroll:AddChild(hudLockChk)
    AddTooltip(hudLockChk, "Lock HUD Position",
        "Prevent the HUD from being accidentally dragged.\nWhen locked the frame is click-through.")

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
    AddTooltip(minimapChk, "Minimap Button", "Toggle the MilestoneKeys icon on the minimap.")

    -- HUD toggle
    local hudChk = AG:Create("CheckBox")
    hudChk:SetLabel("Show milestone HUD during keys")
    hudChk:SetValue(MK.db.profile.options.showHUD)
    hudChk:SetFullWidth(true)
    hudChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.showHUD = val
    end)
    outerScroll:AddChild(hudChk)
    AddTooltip(hudChk, "Milestone HUD",
        "Show a persistent tracker frame during Mythic+ runs\nlisting all milestones and their completion status.")

    -- Per-dungeon profiles toggle
    local perDungeonChk = AG:Create("CheckBox")
    perDungeonChk:SetLabel("Per-dungeon profiles (uses above profile during run)")
    perDungeonChk:SetValue(MK.db.profile.options.perDungeonProfiles)
    perDungeonChk:SetFullWidth(true)
    perDungeonChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.perDungeonProfiles = val
    end)
    outerScroll:AddChild(perDungeonChk)
    AddTooltip(perDungeonChk, "Per-Dungeon Profiles",
        "Store a separate milestone set for each dungeon.\nThe profile selected above is used during that dungeon's run.")

    -- Party sync toggle
    local syncChk = AG:Create("CheckBox")
    syncChk:SetLabel("Broadcast milestones to party")
    syncChk:SetValue(MK.db.profile.options.partySync)
    syncChk:SetWidth(240)
    syncChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.partySync = val
    end)
    outerScroll:AddChild(syncChk)
    AddTooltip(syncChk, "Party Sync",
        "Send a party chat message via MKSYNV1 prefix\nwhen you cross a milestone threshold.")

    -- Predictive alerts toggle
    local predictChk = AG:Create("CheckBox")
    predictChk:SetLabel("MDT predictive pull alerts")
    predictChk:SetValue(MK.db.profile.options.predictiveAlerts)
    predictChk:SetWidth(220)
    predictChk:SetCallback("OnValueChanged", function(_, _, val)
        MK.db.profile.options.predictiveAlerts = val
    end)
    outerScroll:AddChild(predictChk)
    AddTooltip(predictChk, "MDT Predictive Alerts",
        "Warn in chat when the next MDT pull will push you\npast a milestone threshold. Requires MDT.")

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
            { label = "Test Milestone", alertType = "sound_chat_frame" },
            42.7,
            kLevel > 0 and kLevel or 10
        )
    end)
    outerScroll:AddChild(testBtn)

    local resetWinBtn = AG:Create("Button")
    resetWinBtn:SetText("Reset window")
    resetWinBtn:SetWidth(140)
    resetWinBtn:SetCallback("OnClick", function()
        wipe(MK.db.profile.uiState)
        C_Timer.After(0, function()
            if Panel then
                AG:Release(Panel)
                Panel = nil
            end
            Panel = BuildPanel(MK)
        end)
    end)
    outerScroll:AddChild(resetWinBtn)
    AddTooltip(resetWinBtn, "Reset Window",
        "Reset the options panel to its default size and position.")

    -- ====================================================
    -- SECTION: MDT Route Import  (Predict.lua)
    -- ====================================================
    refreshMDTRoutes = MK_Predict_BuildUI(MK, outerScroll, function() return selectedMapID end, function() RebuildList() end)

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
