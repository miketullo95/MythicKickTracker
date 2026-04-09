-- TulloKickTracker
-- FocusTracker.lua — Watches focus changes, applies raid markers, updates party data

local addonName, ns = ...
local FocusTracker = {}
ns.FocusTracker = FocusTracker

-- ============================================================
--  Module init (called from Core.lua:OnEnable)
-- ============================================================
function FocusTracker:Initialize()
    local frame = CreateFrame("Frame")
    self.frame = frame

    frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_FOCUS_CHANGED" then
            FocusTracker:OnFocusChanged()
        end
    end)
end

-- ============================================================
--  Focus changed handler
-- ============================================================
function FocusTracker:OnFocusChanged()
    local me = UnitName("player")

    -- Focus was cleared
    if not UnitExists("focus") then
        ns.partyData[me].mobName = nil
        ns.Panel:Refresh()
        ns.PartySync:BroadcastAssignment()
        return
    end

    -- Don't assign players (e.g. accidentally focusing a teammate)
    if UnitIsPlayer("focus") then
        ns.partyData[me].mobName = nil
        ns.Panel:Refresh()
        ns.PartySync:BroadcastAssignment()
        return
    end

    -- Valid mob focus — record name and apply marker
    local mobName = UnitName("focus") or "Unknown"
    ns.partyData[me].mobName = mobName

    local markerIndex = ns.db.myMarker
    if markerIndex and markerIndex > 0 then
        SetRaidTarget("focus", markerIndex)
    end

    ns.Panel:Refresh()
    ns.PartySync:BroadcastAssignment()
end

-- ============================================================
--  Called when the player changes their marker selection
--  (from Panel dropdown or Settings). Re-applies to current
--  focus if one exists.
-- ============================================================
function FocusTracker:OnMarkerChanged()
    local me = UnitName("player")
    ns.partyData[me].marker = ns.db.myMarker

    if UnitExists("focus") and not UnitIsPlayer("focus") then
        local markerIndex = ns.db.myMarker
        if markerIndex and markerIndex > 0 then
            SetRaidTarget("focus", markerIndex)
        end
    end

    -- Auto-announce if in a valid dungeon/party and setting is on
    if ns.db.autoAnnounce and ns.IsInValidDungeon() then
        ns.PartySync:AnnounceMarker()
    end

    ns.PartySync:BroadcastMarker()
    ns.Panel:Refresh()
end

-- (Initialized by Core.lua:OnEnable → ns.FocusTracker:Initialize())
