-- ============================================================
-- MilestoneKeys - Sync.lua
-- Broadcasts milestone triggers to party members via
-- addon messages (prefix "MKSYNV1").
-- Receivers print the alert attributed to the sender.
-- Deduplicates against locally-triggered milestones.
-- ============================================================

local SYNC_PREFIX = "MKSYNV1"

function MK_Sync_Init(MK)
    C_ChatInfo.RegisterAddonMessagePrefix(SYNC_PREFIX)

    MK:RegisterEvent("CHAT_MSG_ADDON", function(_, prefix, message, _, sender)
        if prefix ~= SYNC_PREFIX then return end
        if not MK.db.profile.options.partySync then return end

        local threshStr, label = message:match("^(%d+)|(.+)$")
        if not threshStr then return end
        local threshold = tonumber(threshStr)

        -- Skip if we already fired our own alert for this milestone
        if MK:IsMilestoneTriggeredByThreshold(threshold) then return end

        local senderName = (sender or ""):match("^([^%-]+)") or sender
        print(string.format(
            "|cffF5B80E[MilestoneKeys]|r |cffFFFFFF%s|r: %s",
            senderName, label
        ))
    end)
end

-- Called from Core.lua:EvaluateForces after a milestone fires.
function MK_Sync_Broadcast(milestone)
    local MK = _G["MilestoneKeys"]
    if not MK.db.profile.options.partySync then return end
    if not IsInGroup() then return end

    local msg = string.format("%d|%s", milestone.threshold, milestone.label)
    C_ChatInfo.SendAddonMessage(SYNC_PREFIX, msg, "PARTY")
end
