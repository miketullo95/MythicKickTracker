-- TulloKickTracker
-- PartySync.lua — AceComm broadcast/receive for marker + assignment data

local addonName, ns = ...
local PartySync = {}
ns.PartySync = PartySync

-- ============================================================
--  Comm prefixes
-- ============================================================
local PREFIX_MARKER     = "TKT_MRK"  -- player changed their marker
local PREFIX_ASSIGNMENT = "TKT_ASN"  -- player's current focus assignment
local PREFIX_HELLO      = "TKT_HI"   -- presence ping on zone-in

-- ============================================================
--  Mock party data (dev test mode)
-- ============================================================
local MOCK_PLAYERS = {
    { name = "Raenah",    marker = 1, mobName = "Vexamus", hasAddon = true  },
    { name = "Drakkthar", marker = 4, mobName = "Amalgam", hasAddon = true  },
    { name = "Fyria",     marker = 6, mobName = nil,       hasAddon = true  },
    { name = "Zorvex",    marker = 0, mobName = nil,       hasAddon = false },
}

function PartySync:InjectMockParty()
    local me = UnitName("player")
    for _, mock in ipairs(MOCK_PLAYERS) do
        if mock.name ~= me then
            ns.partyData[mock.name] = {
                marker   = mock.marker,
                mobName  = mock.mobName,
                hasAddon = mock.hasAddon,
            }
        end
    end
end

function PartySync:ClearMockParty()
    local me        = UnitName("player")
    local mockNames = {}
    for _, mock in ipairs(MOCK_PLAYERS) do mockNames[mock.name] = true end
    for name in pairs(ns.partyData) do
        if name ~= me and mockNames[name] then
            ns.partyData[name] = nil
        end
    end
end

-- ============================================================
--  Helper: pick correct comm channel
-- ============================================================
local function CommChannel()
    if IsInRaid()  then return "RAID"  end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- ============================================================
--  Broadcasts
-- ============================================================
function PartySync:BroadcastMarker()
    local ch = CommChannel()
    if not ch then return end
    ns.TKT:SendCommMessage(PREFIX_MARKER, ns.TKT:Serialize(ns.db.myMarker), ch)
end

function PartySync:BroadcastAssignment()
    local ch = CommChannel()
    if not ch then return end
    local me      = UnitName("player")
    local mobName = (ns.partyData[me] and ns.partyData[me].mobName) or ""
    ns.TKT:SendCommMessage(PREFIX_ASSIGNMENT, ns.TKT:Serialize(mobName), ch)
end

function PartySync:BroadcastHello()
    local ch = CommChannel()
    if not ch then return end
    ns.TKT:SendCommMessage(PREFIX_HELLO, ns.TKT:Serialize(ns.db.myMarker), ch)
end

-- ============================================================
--  Receive handler
-- ============================================================
function PartySync:OnCommReceived(prefix, message, distribution, sender)
    if sender == UnitName("player") then return end

    local ok, data = ns.TKT:Deserialize(message)
    if not ok then return end

    if not ns.partyData[sender] then
        ns.partyData[sender] = { marker = 0, mobName = nil, hasAddon = true }
    end
    ns.partyData[sender].hasAddon = true

    if prefix == PREFIX_HELLO or prefix == PREFIX_MARKER then
        ns.partyData[sender].marker = tonumber(data) or 0
        ns.Panel:Refresh()
    elseif prefix == PREFIX_ASSIGNMENT then
        ns.partyData[sender].mobName = (data ~= "" and data) or nil
        ns.Panel:Refresh()
    end
end

-- ============================================================
--  Announce to party chat
-- ============================================================
function PartySync:AnnounceMarker()
    local markerIdx = ns.db.myMarker
    if markerIdx == 0 then
        ns.Print("You haven't chosen a kick marker yet. Pick one in the panel or /kt config.")
        return
    end
    local ch = CommChannel()
    if not ch then
        ns.Print("You're not in a group — no one to announce to.")
        return
    end
    local msg = string.format(
        "[TulloKickTracker] My kick marker is %s %s — watch for my interrupts!",
        ns.MarkerChatIcon(markerIdx),
        ns.MarkerName(markerIdx)
    )
    SendChatMessage(msg, ch)
end

-- ============================================================
--  Initialize
-- ============================================================
function PartySync:Initialize()
    ns.TKT:RegisterComm(PREFIX_MARKER,     function(...) PartySync:OnCommReceived(...) end)
    ns.TKT:RegisterComm(PREFIX_ASSIGNMENT, function(...) PartySync:OnCommReceived(...) end)
    ns.TKT:RegisterComm(PREFIX_HELLO,      function(...) PartySync:OnCommReceived(...) end)

    local helloFrame = CreateFrame("Frame")
    helloFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    helloFrame:SetScript("OnEvent", function()
        C_Timer.After(2.0, function()
            if ns.IsInValidDungeon() then PartySync:BroadcastHello() end
        end)
    end)
end

-- (Initialized by Core.lua:OnEnable → ns.PartySync:Initialize())
