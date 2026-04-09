-- TulloKickTracker
-- Core.lua — Addon bootstrap, database defaults, slash commands, shared state

local addonName, ns = ...

-- ============================================================
--  Addon object (Ace3)
-- ============================================================
local TKT = LibStub("AceAddon-3.0"):NewAddon("TulloKickTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceComm-3.0",
    "AceSerializer-3.0"
)
ns.TKT = TKT

-- ============================================================
--  Raid marker constants
-- ============================================================
ns.MARKERS = {
    { index = 1, name = "Star",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    { index = 2, name = "Circle",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { index = 3, name = "Diamond",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { index = 4, name = "Triangle", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { index = 5, name = "Moon",     icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { index = 6, name = "Square",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { index = 7, name = "Cross",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { index = 8, name = "Skull",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
}

-- Helper: marker index → inline texture string for chat
function ns.MarkerChatIcon(index)
    if not index or index < 1 or index > 8 then return "" end
    return "|T" .. ns.MARKERS[index].icon .. ":14|t"
end

-- Helper: marker index → display name
function ns.MarkerName(index)
    if not index or index < 1 or index > 8 then return "None" end
    return ns.MARKERS[index].name
end

-- ============================================================
--  Database defaults
-- ============================================================
local defaults = {
    profile = {
        myMarker          = 0,        -- 0 = unset; 1-8 = marker index
        dungeonScope      = "mythic", -- "mythic" | "all"
        alertSound        = "tts",    -- "tts" | "bundled" | "wowui" | "custom"
        alertSoundCustom  = "",       -- path for custom sound
        alertVolume       = 1.0,
        castBarAllCasts   = false,    -- show bar for non-interruptible too
        castBarColor      = { r=0.9,  g=0.1, b=0.1, a=1.0 }, -- interruptible
        castBarColorSafe  = { r=0.5,  g=0.5, b=0.5, a=1.0 }, -- non-interruptible
        castBarWidth      = 220,
        castBarHeight     = 22,
        castBarPos        = { point="CENTER", x=0, y=-120 },
        showPanelInCombat = false,
        autoAnnounce      = true,
        testMode          = false,
    },
}

-- ============================================================
--  Shared runtime state (used across modules)
-- ============================================================
ns.partyData = {}
-- partyData[playerName] = {
--   marker   = 0-8,
--   mobName  = "string" or nil,
--   hasAddon = true,
-- }

-- ============================================================
--  Lifecycle
-- ============================================================
function TKT:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("TulloKickTrackerDB", defaults, true)
    ns.db = self.db.profile  -- convenient shorthand used by all modules

    -- Register slash commands
    self:RegisterChatCommand("kt",          "SlashHandler")
    self:RegisterChatCommand("kicktracker", "SlashHandler")

    -- Register AceConfig options + Blizzard settings panel
    local AceConfig       = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    AceConfig:RegisterOptionsTable("TulloKickTracker", function() return ns.BuildOptions() end)
    AceConfigDialog:AddToBlizOptions("TulloKickTracker", "TulloKickTracker")
end

function TKT:OnEnable()
    -- Seed the party table with yourself
    local me = UnitName("player")
    ns.partyData[me] = {
        marker   = ns.db.myMarker,
        mobName  = nil,
        hasAddon = true,
    }

    -- Initialise all modules in dependency order
    ns.FocusTracker:Initialize()
    ns.CastBar:Initialize()
    ns.PartySync:Initialize()
    ns.Panel:Initialize()

    self:Print("|cFF00CCFFTulloKickTracker|r v1.0 loaded. Type |cFFFFFF00/kt help|r for commands.")
end

-- ============================================================
--  Slash command router
-- ============================================================
local slashCommands = {}

slashCommands["help"] = function()
    local TKT = ns.TKT
    TKT:Print("|cFF00CCFFTulloKickTracker|r commands:")
    TKT:Print("  |cFFFFFF00/kt panel|r        — toggle the assignment panel")
    TKT:Print("  |cFFFFFF00/kt config|r       — open settings")
    TKT:Print("  |cFFFFFF00/kt announce|r     — announce your marker to party chat")
    TKT:Print("  |cFFFFFF00/kt test|r         — toggle dev test mode")
    TKT:Print("  |cFFFFFF00/kt testsound|r    — play alert sound now")
    TKT:Print("  |cFFFFFF00/kt testcast|r     — show a fake interruptible cast bar")
    TKT:Print("  |cFFFFFF00/kt testpanel|r    — force open panel (ignores location checks)")
    TKT:Print("  |cFFFFFF00/kt testconflict|r — show marker conflict warning in panel")
end

slashCommands["panel"] = function()
    ns.Panel:Toggle()
end

slashCommands["config"] = function()
    LibStub("AceConfigDialog-3.0"):Open("TulloKickTracker")
end

slashCommands["announce"] = function()
    ns.PartySync:AnnounceMarker()
end

slashCommands["test"] = function()
    ns.db.testMode = not ns.db.testMode
    local state = ns.db.testMode and "|cFF00FF00ON|r" or "|cFFFF4444OFF|r"
    ns.TKT:Print("Test mode: " .. state)
    if ns.db.testMode then
        ns.PartySync:InjectMockParty()
        ns.Panel:Open()
    else
        ns.PartySync:ClearMockParty()
        ns.Panel:Refresh()
    end
end

slashCommands["testsound"] = function()
    ns.CastBar:PlayAlert()
end

slashCommands["testcast"] = function()
    ns.CastBar:ShowWithMockData({
        spellName     = "Frost Bolt",
        duration      = 3.0,
        interruptible = true,
    })
end

slashCommands["testpanel"] = function()
    ns.Panel:Open(true) -- true = force open regardless of location
end

slashCommands["testconflict"] = function()
    if not ns.db.testMode then
        ns.TKT:Print("Enable test mode first with |cFFFFFF00/kt test|r")
        return
    end
    local me      = UnitName("player")
    local myMarker = ns.db.myMarker > 0 and ns.db.myMarker or 6
    for name, data in pairs(ns.partyData) do
        if name ~= me and data.hasAddon then
            data.marker = myMarker
            break
        end
    end
    ns.Panel:Refresh()
    ns.TKT:Print("Set a mock player to your marker (" .. ns.MarkerName(myMarker) .. ") to show conflict.")
end

function TKT:SlashHandler(input)
    local cmd = (input:match("^%s*(%S+)") or ""):lower()
    if slashCommands[cmd] then
        slashCommands[cmd]()
    else
        slashCommands["help"]()
    end
end

-- ============================================================
--  Utility: is the player in a valid dungeon for the addon?
-- ============================================================
function ns.IsInValidDungeon()
    if ns.db.testMode then return true end
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    if ns.db.dungeonScope == "all" then
        return instanceType == "party" or instanceType == "raid"
    else
        -- mythic+ only: check for active keystone
        return C_ChallengeMode.GetActiveChallengeMapID() ~= nil
    end
end

-- ============================================================
--  Utility: print with addon prefix
-- ============================================================
function ns.Print(msg)
    ns.TKT:Print(msg)
end
