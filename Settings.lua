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
        name    = "Mythic Kick Tracker",
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
                    tts    = "Text-to-Speech",
                    lsm    = "Sound Library (LibSharedMedia)",
                    wowui  = "WoW UI Sound (Raid Warning)",
                    custom = "Custom Sound Path",
                },
                get = function() return ns.db.alertSound end,
                set = function(_, val) ns.db.alertSound = val end,
            },
            alertSoundTTSNote = {
                type   = "description",
                name   = "|cFFAAAAAATTS requires 'Enable Text-to-Speech' to be on in\nInterface → Accessibility → Accessibility.|r",
                order  = 11.5,
                hidden = function() return ns.db.alertSound ~= "tts" end,
            },
            alertSoundLSM = {
                type          = "select",
                name          = "Library Sound",
                desc          = "Sound registered by any installed addon via LibSharedMedia (e.g. BigWigs, DBM, WeakAuras).",
                order         = 12,
                hidden        = function() return ns.db.alertSound ~= "lsm" end,
                values        = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    return LSM and LSM:HashTable("sound") or {}
                end,
                dialogControl = "LSM30_Sound",
                get           = function() return ns.db.alertSoundLSM end,
                set           = function(_, val) ns.db.alertSoundLSM = val end,
            },
            alertSoundCustom = {
                type   = "input",
                name   = "Custom Sound Path",
                desc   = "Full path to a .ogg file, e.g. Interface\\AddOns\\MyAddon\\sound.ogg",
                order  = 13,
                width  = "full",
                hidden = function() return ns.db.alertSound ~= "custom" end,
                get    = function() return ns.db.alertSoundCustom end,
                set    = function(_, val) ns.db.alertSoundCustom = val end,
            },
            alertVolume = {
                type  = "range",
                name  = "Alert Volume",
                order = 14,
                min   = 0.0, max = 1.0, step = 0.05,
                get   = function() return ns.db.alertVolume end,
                set   = function(_, val) ns.db.alertVolume = val end,
            },
            testSoundBtn = {
                type  = "execute",
                name  = "Test Alert Sound",
                desc  = "Play your selected alert sound right now.",
                order = 15,
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
            castBarTexture = {
                type          = "select",
                name          = "Bar Texture",
                desc          = "Visual texture for the cast bar. Picks up textures from any installed addon that uses LibSharedMedia.",
                order         = 22,
                values        = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    return LSM and LSM:HashTable("statusbar") or {}
                end,
                dialogControl = "LSM30_Statusbar",
                get           = function() return ns.db.castBarTexture end,
                set           = function(_, val)
                    ns.db.castBarTexture = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castBarWidth = {
                type  = "range",
                name  = "Bar Width",
                order = 23,
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
                order = 24,
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
                order    = 25,
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
                order    = 26,
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
            showInterruptCD = {
                type  = "toggle",
                name  = "Show Interrupt Cooldown",
                desc  = "Show a gold tick on the bar when your interrupt comes off cooldown mid-cast. Bar turns grey if your interrupt won't be ready before the cast ends.",
                order = 27,
                width = "full",
                get   = function() return ns.db.showInterruptCD end,
                set   = function(_, val) ns.db.showInterruptCD = val end,
            },

            -- ── Text Settings ─────────────────────────────────
            textSettingsHeader = {
                type = "header", name = "Text Settings", order = 30,
            },

            -- Alert Label
            alertLabelSubHeader = {
                type = "header", name = "Alert Label", order = 31,
            },
            alertTextMode = {
                type   = "select",
                name   = "Label Content",
                desc   = "What text to display on the bar during an interruptible cast.",
                order  = 32,
                values = {
                    spellname = "Spell Name (default)",
                    custom    = "Custom Label",
                },
                get = function() return ns.db.alertTextMode end,
                set = function(_, val)
                    ns.db.alertTextMode = val
                    ns.CastBar:ApplySettings()
                end,
            },
            alertText = {
                type   = "input",
                name   = "Custom Label",
                desc   = "Text shown on the bar when an interruptible cast begins.",
                order  = 33,
                width  = "full",
                hidden = function() return ns.db.alertTextMode ~= "custom" end,
                get    = function() return ns.db.alertText end,
                set    = function(_, val)
                    ns.db.alertText = val
                    ns.CastBar:ApplySettings()
                end,
            },
            alertTextFont = {
                type          = "select",
                name          = "Font",
                order         = 34,
                values        = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    return LSM and LSM:HashTable("font") or {}
                end,
                dialogControl = "LSM30_Font",
                get           = function() return ns.db.alertTextFont end,
                set           = function(_, val)
                    ns.db.alertTextFont = val
                    ns.CastBar:ApplySettings()
                end,
            },
            alertTextSize = {
                type  = "range",
                name  = "Font Size",
                order = 35,
                min   = 8, max = 48, step = 1,
                get   = function() return ns.db.alertTextSize end,
                set   = function(_, val)
                    ns.db.alertTextSize = val
                    ns.CastBar:ApplySettings()
                end,
            },
            alertTextColor = {
                type     = "color",
                name     = "Text Colour",
                order    = 36,
                hasAlpha = true,
                get      = function()
                    local c = ns.db.alertTextColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    local c = ns.db.alertTextColor
                    c.r, c.g, c.b, c.a = r, g, b, a
                    ns.CastBar:ApplySettings()
                end,
            },
            alertTextAnchor = {
                type   = "select",
                name   = "Position",
                desc   = "Where on the bar the alert label appears.",
                order  = 37,
                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                get    = function() return ns.db.alertTextAnchor end,
                set    = function(_, val)
                    ns.db.alertTextAnchor = val
                    ns.CastBar:ApplySettings()
                end,
            },

            -- Duration Text
            durationTextSubHeader = {
                type = "header", name = "Duration Text", order = 40,
            },
            castDurationShow = {
                type  = "toggle",
                name  = "Show Duration Countdown",
                desc  = "Display a countdown timer on the bar showing seconds remaining.",
                order = 41,
                width = "full",
                get   = function() return ns.db.castDurationShow end,
                set   = function(_, val)
                    ns.db.castDurationShow = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castDurationFont = {
                type          = "select",
                name          = "Font",
                order         = 42,
                hidden        = function() return not ns.db.castDurationShow end,
                values        = function()
                    local LSM = LibStub("LibSharedMedia-3.0", true)
                    return LSM and LSM:HashTable("font") or {}
                end,
                dialogControl = "LSM30_Font",
                get           = function() return ns.db.castDurationFont end,
                set           = function(_, val)
                    ns.db.castDurationFont = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castDurationSize = {
                type   = "range",
                name   = "Font Size",
                order  = 43,
                hidden = function() return not ns.db.castDurationShow end,
                min    = 8, max = 48, step = 1,
                get    = function() return ns.db.castDurationSize end,
                set    = function(_, val)
                    ns.db.castDurationSize = val
                    ns.CastBar:ApplySettings()
                end,
            },
            castDurationColor = {
                type     = "color",
                name     = "Text Colour",
                order    = 44,
                hidden   = function() return not ns.db.castDurationShow end,
                hasAlpha = true,
                get      = function()
                    local c = ns.db.castDurationColor
                    return c.r, c.g, c.b, c.a
                end,
                set = function(_, r, g, b, a)
                    local c = ns.db.castDurationColor
                    c.r, c.g, c.b, c.a = r, g, b, a
                    ns.CastBar:ApplySettings()
                end,
            },
            castDurationAnchor = {
                type   = "select",
                name   = "Position",
                order  = 45,
                hidden = function() return not ns.db.castDurationShow end,
                values = { LEFT = "Left", CENTER = "Center", RIGHT = "Right" },
                get    = function() return ns.db.castDurationAnchor end,
                set    = function(_, val)
                    ns.db.castDurationAnchor = val
                    ns.CastBar:ApplySettings()
                end,
            },

            testCastBtn = {
                type  = "execute",
                name  = "Test Cast Bar",
                desc  = "Show a fake 3-second interruptible cast bar.",
                order = 50,
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
