-- ============================================================
-- MilestoneKeys - Predict.lua
-- MDT route integration and in-run predictive alerts.
--
-- UI section: shown at config-open time if MDT is loaded.
-- Predictive mode: on SCENARIO_CRITERIA_UPDATE, looks ahead
-- through remaining MDT pulls and warns when the next pull
-- will cross a milestone threshold.
--
-- MDT storage (confirmed from MDT source):
--   MDT.mapInfo[dungeonIdx].mapID    = WoW challengeMapID
--   MDT:GetDB().presets[dungeonIdx][presetIdx].text
--   MDT:GetDB().presets[dungeonIdx][presetIdx].value.pulls
--   pulls[pullIdx][enemyIdx] = { cloneIdx, ... }  (keys are strings)
--   MDT.dungeonEnemies[dungeonIdx][enemyIdx].count  = forces per kill
--   MDT.dungeonEnemies[dungeonIdx][enemyIdx].clones = all instances in dungeon
-- ============================================================

function MK_Predict_Init(MK)
    -- No startup work needed; everything is lazy / event-driven.
end

-- -------------------------------------------------------
-- MDT helpers
-- -------------------------------------------------------
local function GetMDT()
    return _G["MDT"]
end

-- MDT.mapInfo[dungeonIdx].mapID == WoW's challengeMapID.
local function GetMDTDungeonIdx(challengeMapID)
    local MDT = GetMDT()
    if not MDT or not challengeMapID then return nil end
    local mapInfo = MDT.mapInfo
    if not mapInfo then return nil end
    for idx, info in pairs(mapInfo) do
        if type(info) == "table" and info.mapID == challengeMapID then
            return idx
        end
    end
    return nil
end

-- Returns the presets array for a dungeon, or nil if none.
-- MDT exposes its global DB via MDT:GetDB() — it does not use MDT.db.
local function GetDungeonPresets(MDT, dungeonIdx)
    if type(MDT.GetDB) ~= "function" then return nil end
    local db = MDT:GetDB()
    local presets = db.presets and db.presets[dungeonIdx]
    return (presets and #presets > 0) and presets or nil
end

-- Returns the currently selected preset for a dungeon, or nil.
local function GetActivePreset(MDT, dungeonIdx)
    local presets = GetDungeonPresets(MDT, dungeonIdx)
    if not presets then return nil end
    local db  = MDT:GetDB()
    local sel = db.currentPreset
    local idx = (sel and sel[dungeonIdx]) or 1
    return presets[idx]
end

-- Total dungeon forces = sum of enemy.count * #enemy.clones for all enemies.
-- MDT has no public GetDungeonTotalCount(); we compute it from dungeonEnemies.
local function GetDungeonTotal(MDT, dungeonIdx)
    local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIdx]
    if not enemies then return nil end
    local total = 0
    for _, enemy in pairs(enemies) do
        if type(enemy) == "table" and enemy.count and enemy.clones then
            total = total + enemy.count * #enemy.clones
        end
    end
    return total > 0 and total or nil
end

-- Sum forces from pulls 1..upToPull and return as %.
-- pulls[pullIdx][enemyIdx] = { cloneIdx, ... }  (color key is a string, skip it)
local function CalcPullForces(MDT, dungeonIdx, preset, upToPull)
    if not preset or not preset.value or not preset.value.pulls then return nil end
    local pulls   = preset.value.pulls
    local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIdx]
    if not enemies then return nil end
    local total   = GetDungeonTotal(MDT, dungeonIdx)
    if not total or total == 0 then return nil end

    local count = 0
    local ok = pcall(function()
        for pullIdx = 1, upToPull do
            local pull = pulls[pullIdx]
            if not pull then break end
            for enemyIdx, clones in pairs(pull) do
                -- Pull keys are strings ("1", "5", …); skip non-numeric metadata like "color".
                if tonumber(enemyIdx) and type(clones) == "table" then
                    local enemy = enemies[enemyIdx]
                    if enemy then
                        count = count + (enemy.count or 0) * #clones
                    end
                end
            end
        end
    end)

    if not ok then return nil end
    return (count / total) * 100
end

-- -------------------------------------------------------
-- In-run predictive alerts (called from EvaluateForces)
-- -------------------------------------------------------
local lastWarnedPull = nil

function MK_Predict_OnCriteriaUpdate(MK)
    if not MK.db.profile.options.predictiveAlerts then return end
    local MDT = GetMDT()
    if not MDT then return end

    local mapID = MK:GetChallengeMapID()
    if not mapID then return end
    local dungeonIdx = GetMDTDungeonIdx(mapID)
    if not dungeonIdx then return end

    local preset = GetActivePreset(MDT, dungeonIdx)
    if not preset or not preset.value or not preset.value.pulls then return end

    local currentPct = MK:GetCurrentForcesPercent()
    local milestones = MK:GetActiveDungeonProfile()
    local numPulls   = #preset.value.pulls

    for pullIdx = 1, numPulls do
        local pctAfter = CalcPullForces(MDT, dungeonIdx, preset, pullIdx)
        if pctAfter and pctAfter > currentPct then
            if lastWarnedPull ~= pullIdx then
                for _, ms in ipairs(milestones) do
                    if ms.enabled and currentPct < ms.threshold and pctAfter >= ms.threshold then
                        print(string.format(
                            "|cffF5B80E[MilestoneKeys]|r Next pull will push you past |cff00FF96%d%%|r",
                            ms.threshold
                        ))
                        lastWarnedPull = pullIdx
                        break
                    end
                end
            end
            break
        end
    end
end

-- -------------------------------------------------------
-- UI section builder (called from UI.lua:BuildPanel)
-- Returns a refresh function the caller invokes when the
-- selected dungeon changes.
-- -------------------------------------------------------
function MK_Predict_BuildUI(MK, frame, getSelectedMapID)
    local AG  = LibStub("AceGUI-3.0")
    local MDT = GetMDT()

    local sepMDT = AG:Create("Heading")
    sepMDT:SetFullWidth(true)
    sepMDT:SetText("MDT Route Import")
    frame:AddChild(sepMDT)

    if not MDT then
        local muted = AG:Create("Label")
        muted:SetText("|cff888888Install MDT to enable route import.|r")
        muted:SetFullWidth(true)
        frame:AddChild(muted)
        return function() end
    end

    -- ── Preset dropdown ─────────────────────────────────
    local selectedPresetIdx = 1

    local presetDrop = AG:Create("Dropdown")
    presetDrop:SetLabel("Saved Route")
    presetDrop:SetWidth(240)
    frame:AddChild(presetDrop)

    presetDrop:SetCallback("OnValueChanged", function(_, _, val)
        selectedPresetIdx = tonumber(val) or 1
    end)

    local function RefreshRouteList()
        local mapID = getSelectedMapID()
        local list, order = {}, {}

        if not mapID then
            list["0"] = "|cff888888Select a dungeon profile above to load MDT routes|r"
            order     = { "0" }
            selectedPresetIdx = 0
            presetDrop:SetList(list, order)
            presetDrop:SetValue("0")
            return
        end

        local dungeonIdx = GetMDTDungeonIdx(mapID)
        if dungeonIdx then
            local presets = GetDungeonPresets(MDT, dungeonIdx)
            if presets then
                for i, p in ipairs(presets) do
                    local key = tostring(i)
                    list[key] = p.text or ("Route " .. i)
                    table.insert(order, key)
                end
            end
        end

        if not next(list) then
            list["0"]  = "|cff888888No saved MDT routes for this dungeon|r"
            order      = { "0" }
            selectedPresetIdx = 0
        else
            selectedPresetIdx = 1
        end

        presetDrop:SetList(list, order)
        presetDrop:SetValue(order[1])
    end

    RefreshRouteList()

    -- ── Pull number input ───────────────────────────────
    local selectedPull = 1

    local pullBox = AG:Create("EditBox")
    pullBox:SetLabel("Up to pull #")
    pullBox:SetWidth(80)
    pullBox:SetText("1")
    pullBox:SetCallback("OnEnterPressed", function(_, _, val)
        selectedPull = math.max(1, tonumber(val) or 1)
        pullBox:ClearFocus()
    end)
    frame:AddChild(pullBox)

    -- ── Calculate & Add button ──────────────────────────
    local calcBtn = AG:Create("Button")
    calcBtn:SetText("Calculate & Add")
    calcBtn:SetWidth(150)
    calcBtn:SetCallback("OnClick", function()
        local mapID = getSelectedMapID()
        if not mapID then
            print("|cffF5B80E[MilestoneKeys]|r Select a dungeon profile first.")
            return
        end
        local dungeonIdx = GetMDTDungeonIdx(mapID)
        if not dungeonIdx then
            print("|cffF5B80E[MilestoneKeys]|r This dungeon has no MDT data.")
            return
        end
        local presets = GetDungeonPresets(MDT, dungeonIdx)
        local preset  = presets and presets[selectedPresetIdx]
        if not preset then
            print("|cffF5B80E[MilestoneKeys]|r No route selected or route data missing.")
            return
        end
        local pct = CalcPullForces(MDT, dungeonIdx, preset, selectedPull)
        if not pct then
            print("|cffF5B80E[MilestoneKeys]|r Could not calculate forces — check MDT route data.")
            return
        end
        local threshold = math.max(1, math.min(100, math.floor(pct + 0.5)))
        local label     = string.format("Pull %d (~%d%%)", selectedPull, threshold)
        if MK:AddMilestone(threshold, label, "sound_chat", mapID) then
            print(string.format("|cffF5B80E[MilestoneKeys]|r Added: |cff00FF96%s|r", label))
        else
            print(string.format(
                "|cffF5B80E[MilestoneKeys]|r Milestone at |cff00FF96%d%%|r already exists.",
                threshold
            ))
        end
    end)
    frame:AddChild(calcBtn)

    return RefreshRouteList
end
