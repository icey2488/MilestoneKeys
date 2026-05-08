-- ============================================================
-- MilestoneKeys - Core.lua
-- Tracks enemy forces % in an active M+ run and fires
-- player-defined milestone alerts.
-- ============================================================

local ADDON_NAME = "MilestoneKeys"
local MK = LibStub("AceAddon-3.0"):NewAddon(ADDON_NAME, "AceEvent-3.0")

-- -------------------------------------------------------
-- Default saved variable schema
-- -------------------------------------------------------
local DB_DEFAULTS = {
    profile = {
        milestones = {
            -- Each entry: { threshold=number, label=string, alertType=string, enabled=bool }
            { threshold = 20,  label = "20% Forces",   alertType = "sound_chat", enabled = true },
            { threshold = 40,  label = "40% Forces",   alertType = "sound_chat", enabled = true },
            { threshold = 60,  label = "60% Forces",   alertType = "sound_chat", enabled = true },
            { threshold = 80,  label = "80% Forces",   alertType = "sound_chat", enabled = true },
            { threshold = 100, label = "100% Forces!", alertType = "sound_chat", enabled = true },
        },
        dungeonProfiles = {},  -- [challengeMapID] = { milestones = {...} }
        alertSound  = "alarm",
        chatOutput  = true,
        frameAlerts = true,
        options = {
            minimapEnabled     = true,
            perDungeonProfiles = false,
            partySync          = false,
            predictiveAlerts   = false,
            forcesDisplayMode  = "pct_0",  -- pct_0, pct_1, pct_2, nominal
            showHUD            = true,
        },
        minimapPos      = {},  -- LibDBIcon writes position here
        alertFramePos   = nil, -- { point, x, y } saved when locked; nil = centered
        alertFrameAlpha = 1.0,
        hudFramePos     = nil, -- { point, x, y }
        hudFrameAlpha   = 0.8,
        hudLocked       = false,
    },
}

-- -------------------------------------------------------
-- Internal state  (reset on every key start)
-- -------------------------------------------------------
local State = {
    active               = false,
    keystoneLevel        = 0,
    activeChallengeMapID = nil,
    forcesIndex          = nil,
    triggered            = {},
    lastPct              = 0,
    lastQuantity         = 0,
    lastTotal            = 0,
}

-- -------------------------------------------------------
-- Addon lifecycle
-- -------------------------------------------------------
function MK:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("MilestoneKeysDB", DB_DEFAULTS, true)
    MK_UI_Init(self)
    MK_Minimap_Init(self)
    MK_Sync_Init(self)
    MK_Predict_Init(self)
    MK_HUD_Init(self)
end

function MK:OnEnable()
    self:RegisterEvent("CHALLENGE_MODE_START")
    self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    self:RegisterEvent("CHALLENGE_MODE_RESET")
    self:RegisterEvent("SCENARIO_CRITERIA_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- PLAYER_ENTERING_WORLD handles both fresh login and /reload-during-run
end

-- -------------------------------------------------------
-- Event handlers
-- -------------------------------------------------------
function MK:PLAYER_ENTERING_WORLD()
    if C_ChallengeMode.IsChallengeModeActive() then
        self:InitRun()
    end
end

function MK:CHALLENGE_MODE_START()
    self:InitRun()
end

function MK:CHALLENGE_MODE_COMPLETED()
    State.active = false
    MK_HUD_OnRunEnd()
end

function MK:CHALLENGE_MODE_RESET()
    State.active               = false
    State.activeChallengeMapID = nil
    wipe(State.triggered)
    State.lastPct = 0
    MK_HUD_OnRunEnd()
end

function MK:SCENARIO_CRITERIA_UPDATE()
    if not State.active then return end
    self:EvaluateForces()
end

-- -------------------------------------------------------
-- Run initialisation
-- -------------------------------------------------------
function MK:InitRun()
    local level = C_ChallengeMode.GetActiveKeystoneInfo()
    State.active               = true
    State.keystoneLevel        = type(level) == "number" and level or 0
    State.activeChallengeMapID = C_ChallengeMode.GetActiveChallengeMapID()
    State.forcesIndex          = self:DetectForcesIndex()

    wipe(State.triggered)
    State.lastPct = 0

    if State.forcesIndex then
        self:EvaluateForces()
    end
    MK_HUD_OnRunStart()
end

-- -------------------------------------------------------
-- Dynamically find the criteria index that represents
-- enemy forces.
-- -------------------------------------------------------
local FORCES_FLAGS_MASK = 0x80

local function GetCriteriaInfo(index)
    if C_ScenarioInfo and C_ScenarioInfo.GetCriteriaInfo then
        return C_ScenarioInfo.GetCriteriaInfo(index)
    elseif C_Scenario and C_Scenario.GetCriteriaInfo then
        return C_Scenario.GetCriteriaInfo(index)
    end
    return nil
end

local function GetStepInfo()
    if C_ScenarioInfo and C_ScenarioInfo.GetStepInfo then
        return C_ScenarioInfo.GetStepInfo()
    elseif C_Scenario and C_Scenario.GetStepInfo then
        return C_Scenario.GetStepInfo()
    end
    return nil, nil, 0
end

function MK:DetectForcesIndex()
    local _, _, numCriteria = GetStepInfo()
    numCriteria = numCriteria or 0
    local bestIndex, bestTotal = nil, 0

    for i = 1, numCriteria do
        local info = GetCriteriaInfo(i)
        if info then
            -- Explicit forces flag (preferred)
            if bit.band(info.flags or 0, FORCES_FLAGS_MASK) > 0 then
                return i
            end
            -- TWW: forces criteria uses weighted progress; totalQuantity is hidden (0)
            if info.isWeightedProgress then
                return i
            end
            if (info.totalQuantity or 0) > bestTotal then
                bestTotal = info.totalQuantity
                bestIndex = i
            end
        end
    end

    return bestIndex
end

-- -------------------------------------------------------
-- Core evaluation loop
-- -------------------------------------------------------
function MK:EvaluateForces()
    local idx = State.forcesIndex
    if not idx then
        State.forcesIndex = self:DetectForcesIndex()
        idx = State.forcesIndex
        if not idx then return end
    end

    local info = GetCriteriaInfo(idx)
    if not info then return end

    local pct, qty, tot
    if info.isWeightedProgress then
        -- TWW: quantity IS the percentage (0-100); raw counts are hidden
        pct = info.quantity
        qty = nil
        tot = nil
    else
        if info.totalQuantity == 0 then return end
        pct = (info.quantity / info.totalQuantity) * 100
        qty = info.quantity
        tot = info.totalQuantity
    end

    State.lastPct      = pct
    State.lastQuantity = qty or 0
    State.lastTotal    = tot or 0

    local milestones = self:GetActiveDungeonProfile()

    for i, milestone in ipairs(milestones) do
        if milestone.enabled
            and not State.triggered[i]
            and pct >= milestone.threshold
        then
            State.triggered[i] = true
            MK_TriggerAlert(milestone, pct, State.keystoneLevel, qty, tot)
            MK_Sync_Broadcast(milestone)
            MK_HUD_OnMilestoneTriggered(i)
        end
    end

    MK_Predict_OnCriteriaUpdate(self)
end

-- -------------------------------------------------------
-- Dungeon profile resolution
-- -------------------------------------------------------
function MK:GetActiveDungeonProfile()
    local opts = self.db.profile.options
    if opts.perDungeonProfiles and State.activeChallengeMapID then
        local dp = self.db.profile.dungeonProfiles[State.activeChallengeMapID]
        if dp and dp.milestones and #dp.milestones > 0 then
            return dp.milestones
        end
    end
    return self.db.profile.milestones
end

function MK:GetDungeonMilestones(mapID)
    local dp = self.db.profile.dungeonProfiles
    if not dp[mapID] then
        dp[mapID] = { milestones = {} }
    end
    return dp[mapID].milestones
end

-- -------------------------------------------------------
-- Public helpers
-- -------------------------------------------------------
function MK:GetCurrentForcesPercent()
    return State.lastPct
end

function MK:GetCurrentForcesInfo()
    return State.lastPct, State.lastQuantity, State.lastTotal
end

function MK:IsRunActive()
    return State.active
end

function MK:GetKeystoneLevel()
    return State.keystoneLevel
end

function MK:GetChallengeMapID()
    return State.activeChallengeMapID
end

function MK:IsMilestoneTriggeredByThreshold(threshold)
    local milestones = self:GetActiveDungeonProfile()
    for i, ms in ipairs(milestones) do
        if ms.threshold == threshold and State.triggered[i] then
            return true
        end
    end
    return false
end

-- -------------------------------------------------------
-- Milestone CRUD  (mapID=nil → global profile)
-- -------------------------------------------------------
function MK:GetMilestones(mapID)
    if mapID then
        return self:GetDungeonMilestones(mapID)
    end
    return self.db.profile.milestones
end

function MK:AddMilestone(threshold, label, alertType, mapID)
    local list = self:GetMilestones(mapID)
    for _, ms in ipairs(list) do
        if ms.threshold == threshold then return false end
    end
    table.insert(list, {
        threshold = threshold,
        label     = label,
        alertType = alertType or "sound_chat",
        enabled   = true,
    })
    self:SortMilestones(mapID)
    return true
end

function MK:RemoveMilestone(index, mapID)
    table.remove(self:GetMilestones(mapID), index)
end

function MK:UpdateMilestone(index, key, value, mapID)
    local list = self:GetMilestones(mapID)
    if list[index] then
        list[index][key] = value
    end
end

function MK:SortMilestones(mapID)
    table.sort(self:GetMilestones(mapID), function(a, b)
        return a.threshold < b.threshold
    end)
end

-- -------------------------------------------------------
-- Forces formatting  (single source of truth)
-- -------------------------------------------------------
function MK_FormatForces(pct, quantity, total)
    local MK_   = _G["MilestoneKeys"]
    local mode  = MK_.db.profile.options.forcesDisplayMode or "pct_1"
    if mode == "nominal" then
        local q = quantity or math.floor(pct)
        local t = total or 100
        return string.format("%d/%d forces", q, t)
    elseif mode == "pct_0" then
        return string.format("%.0f%% forces", pct)
    elseif mode == "pct_2" then
        return string.format("%.2f%% forces", pct)
    else  -- pct_1
        return string.format("%.1f%% forces", pct)
    end
end

-- Expose the addon object globally so UI/Alerts/Sync/Predict can reference it
_G["MilestoneKeys"] = MK
