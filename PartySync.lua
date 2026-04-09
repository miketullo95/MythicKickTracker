-- TulloKickTracker
-- PartySync.lua — AceComm broadcast/receive for marker + assignment data

local addonName, ns = ...
local PartySync = {}
ns.PartySync = PartySync

-- ============================================================
--  Comm prefixes
-- ============================================================
local PREFIX_MARKER     = "MKT_MRK"  -- player changed their marker
local PREFIX_ASSIGNMENT = "MKT_ASN"  -- player's current focus assignment
local PREFIX_HELLO      = "MKT_HI"   -- presence ping on zone-in

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
    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "party" or instanceType == "raid") then
        return "INSTANCE_CHAT"
    end
    if IsInRaid()  then return "RAID"  end
    if IsInGroup() then return "PARTY" end
    return nil
end

-- ============================================================
--  Broadcasts
-- ============================================================
function PartySync:BroadcastMarker()
    if ns.db.testMode then return end
    local ch = CommChannel()
    if not ch then return end
    ns.TKT:SendCommMessage(PREFIX_MARKER, ns.TKT:Serialize(ns.db.myMarker), ch)
end

function PartySync:BroadcastAssignment()
    if ns.db.testMode then return end
    local ch = CommChannel()
    if not ch then return end
    local me      = UnitName("player")
    local mobName = (ns.partyData[me] and ns.partyData[me].mobName) or ""
    ns.TKT:SendCommMessage(PREFIX_ASSIGNMENT, ns.TKT:Serialize(mobName), ch)
end

function PartySync:BroadcastHello()
    if ns.db.testMode then return end
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
