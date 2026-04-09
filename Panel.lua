-- TulloKickTracker
-- Panel.lua — Pre-key assignment panel with live roster, marker dropdowns, conflict warnings

local addonName, ns = ...
local Panel = {}
ns.Panel = Panel

-- ============================================================
--  Layout constants
-- ============================================================
local PANEL_WIDTH   = 320
local ROW_HEIGHT    = 28
local HEADER_HEIGHT = 36
local FOOTER_HEIGHT = 40
local PAD           = 8
local MAX_ROWS      = 5

-- ============================================================
--  Marker dropdown text entries (with inline icons)
-- ============================================================
local MARKER_DROPDOWN_VALUES = {
    { value = 0, text = "— Not Set —" },
    { value = 1, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_1:14|t  Star"     },
    { value = 2, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_2:14|t  Circle"   },
    { value = 3, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_3:14|t  Diamond"  },
    { value = 4, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_4:14|t  Triangle" },
    { value = 5, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_5:14|t  Moon"     },
    { value = 6, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_6:14|t  Square"   },
    { value = 7, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_7:14|t  Cross"    },
    { value = 8, text = "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_8:14|t  Skull"    },
}

-- ============================================================
--  Helpers
-- ============================================================
local function MarkerIconString(index, size)
    size = size or 16
    if not index or index < 1 or index > 8 then return "" end
    return string.format("|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%d:%d|t", index, size)
end

local function HasMarkerConflict(playerName, markerIndex)
    if markerIndex == 0 then return false end
    for name, data in pairs(ns.partyData) do
        if name ~= playerName and data.hasAddon and data.marker == markerIndex then
            return true
        end
    end
    return false
end

local function GetSortedPlayers()
    local me   = UnitName("player")
    local list = {}

    -- Self always first
    if ns.partyData[me] then
        table.insert(list, { name = me, data = ns.partyData[me], isSelf = true })
    end

    -- Other addon users
    for name, data in pairs(ns.partyData) do
        if name ~= me then
            table.insert(list, { name = name, data = data, isSelf = false })
        end
    end

    -- Party members who don't have the addon
    for i = 1, 4 do
        local unit     = "party" .. i
        local unitName = UnitExists(unit) and UnitName(unit)
        if unitName and not ns.partyData[unitName] then
            table.insert(list, { name = unitName, data = nil, isSelf = false })
        end
    end

    return list
end

-- ============================================================
--  Marker dropdown (one per row, only for the local player)
-- ============================================================
local function CreateMarkerDropdown(parent, isSelf)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    UIDropDownMenu_SetWidth(dd, 130)

    local function UpdateDD()
        local current = ns.db.myMarker
        UIDropDownMenu_SetSelectedValue(dd, current)
        if current > 0 then
            UIDropDownMenu_SetText(dd, MarkerIconString(current, 14) .. " " .. ns.MarkerName(current))
        else
            UIDropDownMenu_SetText(dd, "— Not Set —")
        end
    end

    UIDropDownMenu_Initialize(dd, function(self)
        for _, entry in ipairs(MARKER_DROPDOWN_VALUES) do
            local info    = UIDropDownMenu_CreateInfo()
            info.text     = entry.text
            info.value    = entry.value
            info.checked  = (UIDropDownMenu_GetSelectedValue(self) == entry.value)
            info.func     = function()
                UIDropDownMenu_SetSelectedValue(dd, entry.value)
                ns.db.myMarker = entry.value
                local me = UnitName("player")
                if ns.partyData[me] then
                    ns.partyData[me].marker = entry.value
                end
                ns.FocusTracker:OnMarkerChanged()
                Panel:Refresh()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    UpdateDD()
    dd._Update = UpdateDD
    return dd
end

-- ============================================================
--  Build the main panel frame
-- ============================================================
local function BuildPanel()
    local totalHeight = HEADER_HEIGHT + (MAX_ROWS * ROW_HEIGHT) + FOOTER_HEIGHT + PAD * 2

    local frame = CreateFrame("Frame", "TKTPanelFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(PANEL_WIDTH, totalHeight)
    frame:SetPoint("CENTER", UIParent, "CENTER", 200, 100)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame.TitleText:SetText("|cFF00CCFFTulloKickTracker|r  —  Kick Assignments")

    -- Test mode badge
    local testBadge = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    testBadge:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -4)
    testBadge:SetText("|cFFFF4444[TEST MODE]|r")
    testBadge:Hide()
    frame.testBadge = testBadge

    -- Column headers
    local colName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colName:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + 2, -HEADER_HEIGHT + 4)
    colName:SetText("|cFFAAAAAA  Player|r")

    local colMarker = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colMarker:SetPoint("TOPLEFT", frame, "TOPLEFT", 110, -HEADER_HEIGHT + 4)
    colMarker:SetText("|cFFAAAAAA  Marker|r")

    local colMob = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colMob:SetPoint("TOPLEFT", frame, "TOPLEFT", 250, -HEADER_HEIGHT + 4)
    colMob:SetText("|cFFAAAAAA  Target|r")

    -- Separator
    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PAD, -HEADER_HEIGHT + 2)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -HEADER_HEIGHT + 2)
    sep:SetHeight(1)
    sep:SetColorTexture(0.4, 0.4, 0.4, 0.8)

    -- Row pool
    frame.rows = {}
    for i = 1, MAX_ROWS do
        local yOff = -(HEADER_HEIGHT + (i - 1) * ROW_HEIGHT) - 4

        local row = CreateFrame("Frame", nil, frame)
        row:SetPoint("TOPLEFT",  frame, "TOPLEFT",  PAD,  yOff)
        row:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, yOff)
        row:SetHeight(ROW_HEIGHT)

        -- Conflict highlight
        local highlight = row:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetColorTexture(0.8, 0.1, 0.1, 0.25)
        highlight:Hide()
        row.highlight = highlight

        -- Player name
        local nameText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameText:SetPoint("LEFT", row, "LEFT", 2, 0)
        nameText:SetWidth(95)
        nameText:SetJustifyH("LEFT")
        row.nameText = nameText

        -- Mob name
        local mobText = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        mobText:SetPoint("LEFT", row, "LEFT", 250 - PAD, 0)
        mobText:SetWidth(60)
        mobText:SetJustifyH("LEFT")
        row.mobText = mobText

        -- Conflict warning icon
        local warnText = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        warnText:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        warnText:SetText("|cFFFF4444⚠|r")
        warnText:Hide()
        row.warnText = warnText

        row:Hide()
        frame.rows[i] = row
    end

    -- Footer: announce button
    local announceBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    announceBtn:SetSize(180, 24)
    announceBtn:SetPoint("BOTTOM", frame, "BOTTOM", 0, PAD + 4)
    announceBtn:SetText("Announce My Marker")
    announceBtn:SetScript("OnClick", function()
        ns.PartySync:AnnounceMarker()
    end)
    frame.announceBtn = announceBtn

    frame:Hide()
    Panel.frame = frame
end

-- ============================================================
--  Refresh rows with current partyData
-- ============================================================
function Panel:Refresh()
    if not self.frame or not self.frame:IsShown() then return end

    local me      = UnitName("player")
    local players = GetSortedPlayers()

    self.frame.testBadge[ns.db.testMode and "Show" or "Hide"](self.frame.testBadge)

    for i = 1, MAX_ROWS do
        local row   = self.frame.rows[i]
        local entry = players[i]

        if not entry then
            row:Hide()
        else
            row:Show()
            local data   = entry.data
            local name   = entry.name
            local isSelf = entry.isSelf

            -- Player name colour
            if isSelf then
                row.nameText:SetText("|cFFFFD700" .. name .. "|r")
            elseif data and data.hasAddon then
                row.nameText:SetText("|cFFFFFFFF" .. name .. "|r")
            else
                row.nameText:SetText("|cFF888888" .. name .. " (no addon)|r")
            end

            -- Marker: dropdown for self, icon+name for others
            if isSelf then
                if not row.dd then
                    row.dd = CreateMarkerDropdown(row, true)
                    row.dd:SetPoint("LEFT", row, "LEFT", 90, 0)
                end
                row.dd._Update()
                row.dd:Show()
            else
                if row.dd then row.dd:Hide() end
                if data and data.hasAddon and data.marker and data.marker > 0 then
                    local icon = MarkerIconString(data.marker, 14)
                    row.nameText:SetText("|cFFFFFFFF" .. name .. "|r  " .. icon)
                end
            end

            -- Mob assignment
            if data and data.mobName then
                row.mobText:SetText("|cFF88FF88" .. data.mobName .. "|r")
            else
                row.mobText:SetText("|cFF666666—|r")
            end

            -- Conflict check
            local markerIdx = data and data.marker or 0
            if data and data.hasAddon and HasMarkerConflict(name, markerIdx) then
                row.highlight:Show()
                row.warnText:Show()
            else
                row.highlight:Hide()
                row.warnText:Hide()
            end
        end
    end
end

-- ============================================================
--  Open / Close / Toggle
-- ============================================================
function Panel:Open(force)
    if not self.frame then BuildPanel() end
    if not force and not ns.IsInValidDungeon() then return end
    self.frame:Show()
    self:Refresh()
end

function Panel:Close()
    if self.frame then self.frame:Hide() end
end

function Panel:Toggle()
    if not self.frame then BuildPanel() end
    if self.frame:IsShown() then
        self:Close()
    else
        self:Open(true)
    end
end

-- ============================================================
--  Event-driven auto-open / auto-close
-- ============================================================
function Panel:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("PLAYER_ENTERING_WORLD")
    frame:RegisterEvent("CHALLENGE_MODE_START")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("PLAYER_REGEN_ENABLED")

    frame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_ENTERING_WORLD" then
            C_Timer.After(1.5, function()
                if ns.IsInValidDungeon() then Panel:Open() end
            end)

        elseif event == "CHALLENGE_MODE_START" then
            Panel:Close()

        elseif event == "GROUP_ROSTER_UPDATE" then
            Panel:Refresh()

        elseif event == "PLAYER_REGEN_DISABLED" then
            if not ns.db.showPanelInCombat and Panel.frame and Panel.frame:IsShown() then
                Panel:Close()
            end

        elseif event == "PLAYER_REGEN_ENABLED" then
            if not ns.db.showPanelInCombat and ns.IsInValidDungeon() then
                Panel:Open()
            end
        end
    end)
end

-- (Initialized by Core.lua:OnEnable → ns.Panel:Initialize())
