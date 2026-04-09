-- TulloKickTracker
-- Settings.lua — AceConfig options table

local addonName, ns = ...

-- ============================================================
--  Marker dropdown values for AceConfig
-- ============================================================
local function MarkerValues()
    local t = { [0] = "— Not Set —" }
    for _, m in ipairs(ns.MARKERS) do
        t[m.index] = "|T" .. m.icon .. ":14|t  " .. m.name
    end
    return t
end

-- ============================================================
--  Options table (exported via ns.BuildOptions)
-- ============================================================
local function BuildOptions()
    return {
        name    = "TulloKickTracker",
        handler = ns.TKT,
        type    = "group",
        args    = {

            -- ── General ───────────────────────────────────────
            generalHeader = {
                type = "header", name = "General", order = 1,
            },
            myMarker = {
                type   = "select",
                name   = "My Kick Marker",
                desc   = "The raid marker that identifies YOUR kick targets. Mobs you focus will be stamped with this icon.",
                order  = 2,
                values = MarkerValues(),
                get    = function() return ns.db.myMarker end,
                set    = function(_, val)
                    ns.db.myMarker = val
                    local me = UnitName("player")
                    if ns.partyData[me] then ns.partyData[me].marker = val end
                    ns.FocusTracker:OnMarkerChanged()
                end,
            },
            dungeonScope = {
                type   = "select",
                name   = "Active In",
                desc   = "Which dungeons should TulloKickTracker be active in?",
                order  = 3,
                values = { mythic = "Mythic+ Only", all = "All Dungeons" },
                get    = function() return ns.db.dungeonScope end,
                set    = function(_, val) ns.db.dungeonScope = val end,
            },
            autoAnnounce = {
                type  = "toggle",
                name  = "Auto-Announce Marker on Select",
                desc  = "Automatically send your marker choice to party chat when you pick or change it (only while in a dungeon).",
                order = 4,
                width = "full",
                get   = function() return ns.db.autoAnnounce end,
                set   = function(_, val) ns.db.autoAnnounce = val end,
            },
            showPanelInCombat = {
                type  = "toggle",
                name  = "Keep Panel Visible During Combat",
                desc  = "By default the assignment panel hides when combat starts.",
                order = 5,
                width = "full",
                get   = function() return ns.db.showPanelInCombat end,
                set   = function(_, val) ns.db.showPanelInCombat = val end,
            },

            -- ── Sound ─────────────────────────────────────────
            soundHeader = {
                type = "header", name = "Alert Sound", order = 10,
            },
            alertSound = {
                type   = "select",
                name   = "Sound Type",
                desc   = "Sound to play when your focus target begins an interruptible cast.",
                order  = 11,
                values = {
                    tts     = "Text-to-Speech: \"Kick\"",
                    bundled = "Bundled Sound File",
                    wowui   = "WoW UI Sound (Raid Warning)",
                    custom  = "Custom Sound Path",
                },
                get = function() return ns.db.alertSound end,
                set = function(_, val) ns.db.alertSound = val end,
            },
            alertSoundCustom = {
                type   = "input",
                name   = "Custom Sound Path",
                desc   = "Full path to a .ogg file, e.g. Interface\\AddOns\\MyAddon\\sound.ogg",
                order  = 12,
                width  = "full",
                hidden = function() return ns.db.alertSound ~= "custom" end,
                get    = function() return ns.db.alertSoundCustom end,
                set    = function(_, val) ns.db.alertSoundCustom = val end,
            },
            alertVolume = {
                type  = "range",
                name  = "Alert Volume",
                order = 13,
                min   = 0.0, max = 1.0, step = 0.05,
                get   = function() return ns.db.alertVolume end,
                set   = function(_, val) ns.db.alertVolume = val end,
            },
            testSoundBtn = {
                type  = "execute",
                name  = "Test Alert Sound",
                desc  = "Play your selected alert sound right now.",
                order = 14,
                func  = function() ns.CastBar:PlayAlert() end,
            },

            -- ── Cast Bar ──────────────────────────────────────
            castBarHeader = {
                type = "header", name = "Cast Bar", order = 20,
            },
            castBarAllCasts = {
                type  = "toggle",
                name  = "Show Bar for All Casts (including non-interruptible)",
                desc  = "When OFF (default) the cast bar only appears for spells you can interrupt.",
                order = 21,
                width = "full",
                get   = function() return ns.db.castBarAllCasts end,
                set   = function(_, val) ns.db.castBarAllCasts = val end,
            },
            castBarWidth = {
                type  = "range",
                name  = "Bar Width",
                order = 22,
                min   = 80, max = 500, step = 10,
                get   = function() return ns.db.castBarWidth end,
                set   = function(_, val)
                    ns.db.castBarWidth = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castBarHeight = {
                type  = "range",
                name  = "Bar Height",
                order = 23,
                min   = 10, max = 60, step = 2,
                get   = function() return ns.db.castBarHeight end,
                set   = function(_, val)
                    ns.db.castBarHeight = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castBarColor = {
                type     = "color",
                name     = "Interruptible Cast Colour",
                desc     = "Colour of the bar when the cast CAN be interrupted.",
                order    = 24,
                hasAlpha = true,
                get      = function()
                    local c = ns.db.castBarColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    local c = ns.db.castBarColor
                    c.r, c.g, c.b, c.a = r, g, b, a
                    ns.CastBar:ApplySettings()
                end,
            },
            castBarColorSafe = {
                type     = "color",
                name     = "Non-Interruptible Cast Colour",
                desc     = "Colour when the cast CANNOT be interrupted (only shown if All Casts is enabled).",
                order    = 25,
                hasAlpha = true,
                hidden   = function() return not ns.db.castBarAllCasts end,
                get      = function()
                    local c = ns.db.castBarColorSafe
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    local c = ns.db.castBarColorSafe
                    c.r, c.g, c.b, c.a = r, g, b, a
                    ns.CastBar:ApplySettings()
                end,
            },
            testCastBtn = {
                type  = "execute",
                name  = "Test Cast Bar",
                desc  = "Show a fake 3-second interruptible cast bar.",
                order = 26,
                func  = function()
                    ns.CastBar:ShowWithMockData({ spellName = "Frost Bolt", duration = 3.0, interruptible = true })
                end,
            },

            -- ── Reset ─────────────────────────────────────────
            resetHeader = {
                type = "header", name = "Reset", order = 99,
            },
            resetProfile = {
                type  = "execute",
                name  = "Reset All Settings to Defaults",
                desc  = "Wipe your saved settings and restore everything to the original defaults.",
                order = 100,
                func  = function()
                    ns.TKT.db:ResetProfile()
                    ns.db = ns.TKT.db.profile
                    ns.Print("Settings reset to defaults.")
                end,
            },
        },
    }
end

-- Export so Core.lua:OnInitialize can register it with AceConfig
ns.BuildOptions = BuildOptions
