-- TulloKickTracker
-- FocusTracker.lua — Watches focus changes, applies raid markers, updates party data

local addonName, ns = ...
local FocusTracker = {}
ns.FocusTracker = FocusTracker

-- ============================================================
--  Macro management
-- ============================================================
local MACRO_NAME = "MKT Focus"

local function BuildMacroBody()
    if ns.db.myMarker <= 0 then
        -- No marker set yet — just focus, no mark or announce
        return "#showtooltip\n/focus [@mouseover,harm,nodead][@target,harm,nodead]"
    end
    return string.format(
        "#showtooltip\n/tm [@mouseover,exists][] %d\n/focus [@mouseover,harm,nodead][@target,harm,nodead]",
        ns.db.myMarker
    )
end

local function GetMacroIcon()
    if ns.db.myMarker <= 0 then return "ability_kick" end
    local path   = ns.MARKERS[ns.db.myMarker].icon
    local fileID = GetFileIDFromPath and GetFileIDFromPath(path)
    return (fileID and fileID > 0) and fileID or "ability_kick"
end

function FocusTracker:CreateOrUpdateMacro()
    if InCombatLockdown() then return end
    local icon = GetMacroIcon()
    local body = BuildMacroBody()
    local idx  = GetMacroIndexByName(MACRO_NAME)
    if idx > 0 then
        EditMacro(idx, MACRO_NAME, icon, body)
    else
        local ok = CreateMacro(MACRO_NAME, icon, body, false)
        if not ok then
            ns.Print("Could not create macro — you may be at the macro limit (120). Free a slot and run /kt macro.")
        end
    end
end

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

    self:CreateOrUpdateMacro()
end

-- ============================================================
--  Focus changed handler
-- ============================================================
function FocusTracker:OnFocusChanged()
    local me        = UnitName("player")
    -- Snapshot all focus state immediately — the game can clear focus
    -- between successive API calls, causing false "no focus" reads
    local focusName = UnitName("focus")
    local isPlayer  = focusName and UnitIsPlayer("focus")

    if ns.partyData[me] then
        ns.partyData[me].mobName = (focusName and not isPlayer) and focusName or nil
    end

    -- If the new focus target is already mid-cast, show the bar immediately.
    -- UNIT_SPELLCAST_START only fires for casts that begin AFTER focus is set,
    -- so without this check the bar never appears for in-progress casts.
    if focusName and not isPlayer then
        if UnitCastingInfo("focus") then
            ns.CastBar:OnCastStart(false)
        elseif UnitChannelInfo("focus") then
            ns.CastBar:OnCastStart(true)
        else
            ns.CastBar:Hide()
        end
    else
        ns.CastBar:Hide()
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

    self:CreateOrUpdateMacro()
    ns.PartySync:BroadcastMarker()
    ns.Panel:Refresh()
end

-- (Initialized by Core.lua:OnEnable → ns.FocusTracker:Initialize())
