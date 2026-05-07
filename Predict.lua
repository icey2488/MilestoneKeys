-- ============================================================
-- MilestoneKeys - Predict.lua
-- MDT route integration and in-run predictive alerts.
--
-- UI section: shown at config-open time if MDT is loaded.
-- Predictive mode: on SCENARIO_CRITERIA_UPDATE, looks ahead
-- through remaining MDT pulls and warns when the next pull
-- will cross a milestone threshold.
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

-- MDT uses its own dungeon index separate from challengeMapID.
-- We match via MDT.mapInfo[idx].mapID or .challengeMapID.
local function GetMDTDungeonIdx(challengeMapID)
    local MDT = GetMDT()
    if not MDT or not challengeMapID then return nil end
    local mapInfo = MDT.mapInfo or MDT.dungeonMapInfo
    if not mapInfo then return nil end
    for idx, info in pairs(mapInfo) do
        if info.mapID == challengeMapID or info.challengeMapID == challengeMapID then
            return idx
        end
    end
    return nil
end

local function GetActiveRoute(MDT, dungeonIdx)
    if not MDT.db or not MDT.db.profile then return nil end
    local routes = MDT.db.profile.routes and MDT.db.profile.routes[dungeonIdx]
    if not routes or #routes == 0 then return nil end
    local sel = MDT.db.profile.selectedRoute
    local idx = (sel and sel[dungeonIdx]) or 1
    return routes[idx]
end

-- Sum forces count from pull 1 up to upToPull, return as %.
-- MDT route.value[pullIdx][subZone][npcIdx] = { cloneIdx, ... }
-- MDT.dungeonEnemies[dungeonIdx][npcIdx].count = number per clone
local function CalcPullForces(MDT, dungeonIdx, route, upToPull)
    if not route or not route.value then return nil end
    local enemies = MDT.dungeonEnemies and MDT.dungeonEnemies[dungeonIdx]
    if not enemies then return nil end
    local total = MDT:GetDungeonTotalCount(dungeonIdx)
    if not total or total == 0 then return nil end

    local count = 0
    local ok = pcall(function()
        for pullIdx = 1, upToPull do
            local pull = route.value[pullIdx]
            if not pull then break end
            for _, subZone in pairs(pull) do
                if type(subZone) == "table" then
                    for npcIdx, clones in pairs(subZone) do
                        if type(clones) == "table" then
                            local enemy = enemies[npcIdx]
                            if enemy then
                                for _ in ipairs(clones) do
                                    count = count + (enemy.count or 0)
                                end
                            end
                        end
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

    local route = GetActiveRoute(MDT, dungeonIdx)
    if not route or not route.value then return end

    local currentPct = MK:GetCurrentForcesPercent()
    local milestones = MK:GetActiveDungeonProfile()
    local numPulls   = #route.value

    -- Find the first pull beyond the current forces level
    for pullIdx = 1, numPulls do
        local pctAfter = CalcPullForces(MDT, dungeonIdx, route, pullIdx)
        if pctAfter and pctAfter > currentPct then
            -- This is the next un-cleared pull; warn once per pull index
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
        return function() end  -- no-op refresh
    end

    -- ── Route dropdown ──────────────────────────────────
    local selectedRouteIdx = 1

    local routeDrop = AG:Create("Dropdown")
    routeDrop:SetLabel("Saved Route")
    routeDrop:SetWidth(240)
    frame:AddChild(routeDrop)

    routeDrop:SetCallback("OnValueChanged", function(_, _, val)
        selectedRouteIdx = tonumber(val) or 1
    end)

    local function RefreshRouteList()
        local mapID     = getSelectedMapID()
        local dungeonIdx = mapID and GetMDTDungeonIdx(mapID)
        local list, order = {}, {}

        if dungeonIdx and MDT.db and MDT.db.profile and MDT.db.profile.routes then
            local routes = MDT.db.profile.routes[dungeonIdx]
            if routes then
                for i, r in ipairs(routes) do
                    local key = tostring(i)
                    list[key] = r.text or ("Route " .. i)
                    table.insert(order, key)
                end
            end
        end

        if not next(list) then
            list["0"]  = "|cff888888No saved routes for this dungeon|r"
            order      = { "0" }
            selectedRouteIdx = 0
        else
            selectedRouteIdx = 1
        end

        routeDrop:SetList(list, order)
        routeDrop:SetValue(order[1])
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
        local routes  = MDT.db and MDT.db.profile and MDT.db.profile.routes
        local route   = routes and routes[dungeonIdx] and routes[dungeonIdx][selectedRouteIdx]
        if not route then
            print("|cffF5B80E[MilestoneKeys]|r No route selected or route data missing.")
            return
        end
        local pct = CalcPullForces(MDT, dungeonIdx, route, selectedPull)
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
