-- TulloKickTracker
-- CastBar.lua — Custom interruptible cast bar for the focus target

local addonName, ns = ...
local CastBar = {}
ns.CastBar = CastBar

-- Localise hot-path globals
local GetTime         = GetTime
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo
local LSM = LibStub("LibSharedMedia-3.0", true)

-- ============================================================
--  Interrupt spell IDs per class (first known spell wins)
-- ============================================================
local INTERRUPT_SPELLS = {
    WARRIOR     = { 6552   },           -- Pummel
    PALADIN     = { 96231  },           -- Rebuke
    HUNTER      = { 187707, 147362 },   -- Muzzle (BM), Counter Shot (MM/SV)
    ROGUE       = { 1766   },           -- Kick
    PRIEST      = { 15487  },           -- Silence (Shadow)
    DEATHKNIGHT = { 47528  },           -- Mind Freeze
    SHAMAN      = { 57994  },           -- Wind Shear
    MAGE        = { 2139   },           -- Counterspell
    WARLOCK     = { 19647  },           -- Spell Lock (pet)
    MONK        = { 116705 },           -- Spear Hand Strike
    DRUID       = { 106839 },           -- Skull Bash
    DEMONHUNTER = { 183752 },           -- Disrupt
    EVOKER      = { 351338 },           -- Quell
}

-- Returns seconds until the player's interrupt is off CD, 0 if ready, nil if none exists
local function GetInterruptRemaining()
    local class = select(2, UnitClass("player"))
    local spells = INTERRUPT_SPELLS[class]
    if not spells then return nil end

    local now = GetTime()
    local best = nil

    for _, spellID in ipairs(spells) do
        -- C_Spell.GetSpellCooldown replaced GetSpellCooldown in TWW (11.x)
        local info = C_Spell.GetSpellCooldown(spellID)
        if info then
            local remaining = (info.startTime == 0 or info.duration <= 1.5)
                              and 0
                              or math.max(0, (info.startTime + info.duration) - now)
            if best == nil or remaining < best then best = remaining end
        end
    end

    return best
end

-- ============================================================
--  WoW built-in sound presets
-- ============================================================
ns.SOUND_PRESETS = {
    { id = "RAID_WARNING", label = "Raid Warning", soundKitID = 8959 },
    { id = "PVP_FLAG",     label = "PvP Flag Alert", soundKitID = 8174 },
    { id = "READY_CHECK",  label = "Ready Check",  soundKitID = 1686 },
    { id = "ALARM_CLOCK",  label = "Alarm Clock",  soundKitID = 5274 },
}

-- ============================================================
--  Internal cast state
-- ============================================================
local castData = {
    active        = false,
    spellName     = "",
    startTime     = 0,
    endTime       = 0,
    interruptible = false,
    isMock        = false,
}

-- ============================================================
--  Build the cast bar frame
-- ============================================================
local function BuildCastBar()
    local db = ns.db

    local frame = CreateFrame("Frame", "TKTCastBarFrame", UIParent)
    frame:SetSize(db.castBarWidth, db.castBarHeight + 18)
    frame:SetPoint(db.castBarPos.point, UIParent, db.castBarPos.point,
                   db.castBarPos.x, db.castBarPos.y)
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)

    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint()
        db.castBarPos.point = point
        db.castBarPos.x     = x
        db.castBarPos.y     = y
    end)

    -- Dark background
    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.7)

    -- Spell name above the bar
    local spellText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    spellText:SetPoint("BOTTOMLEFT",  frame, "TOPLEFT",  2, 2)
    spellText:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", -2, 2)
    spellText:SetJustifyH("CENTER")
    frame.spellText = spellText

    -- Progress bar
    local bar = CreateFrame("StatusBar", nil, frame)
    bar:SetPoint("TOPLEFT",     frame, "TOPLEFT",     1, -1)
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1,  1)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarTexture(LSM and LSM:Fetch("statusbar", ns.db.castBarTexture) or "Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar = bar

    -- Alert flash text — child of bar so it renders above the bar fill
    local kickText = bar:CreateFontString(nil, "OVERLAY")
    kickText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    kickText:Hide()
    frame.kickText = kickText

    -- Duration countdown text (e.g. "2.3")
    local durationText = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    durationText:SetPoint("RIGHT", bar, "RIGHT", -4, 0)
    durationText:Hide()
    frame.durationText = durationText

    -- Interrupt CD tick — vertical line at the moment the interrupt comes off CD
    local interruptTick = bar:CreateTexture(nil, "OVERLAY")
    interruptTick:SetSize(2, db.castBarHeight)
    interruptTick:SetColorTexture(1, 0.85, 0, 1.0)
    interruptTick:Hide()
    frame.interruptTick = interruptTick

    CastBar.frame = frame

    -- OnUpdate: animate fill, duration text, interrupt tick
    frame:SetScript("OnUpdate", function()
        if not castData.active then return end
        local now     = GetTime()
        local total   = castData.endTime - castData.startTime
        local elapsed = now - castData.startTime
        if elapsed >= total then
            CastBar:Hide()
            return
        end
        bar:SetValue(elapsed / total)

        -- Duration countdown
        if ns.db.castDurationShow then
            frame.durationText:SetText(string.format("%.1f", castData.endTime - now))
            frame.durationText:Show()
        else
            frame.durationText:Hide()
        end

        -- Interrupt CD indicator (only for interruptible casts)
        if ns.db.showInterruptCD and castData.interruptible then
            local intRemaining  = GetInterruptRemaining()
            local castRemaining = castData.endTime - now

            if intRemaining == nil then
                -- Class has no interrupt — leave bar colour alone
                frame.interruptTick:Hide()

            elseif intRemaining <= 0 then
                -- Interrupt is ready right now
                ApplyBarColor(true)
                frame.interruptTick:Hide()

            elseif intRemaining >= castRemaining then
                -- CD outlasts the cast — gray bar, no tick
                bar:SetStatusBarColor(0.55, 0.55, 0.55, 1.0)
                frame.interruptTick:Hide()

            else
                -- Interrupt comes off CD mid-cast — normal colour + tick
                ApplyBarColor(true)
                local tickFraction = (elapsed + intRemaining) / total
                local barWidth     = bar:GetWidth()
                if barWidth > 0 then
                    frame.interruptTick:ClearAllPoints()
                    frame.interruptTick:SetPoint("LEFT", bar, "LEFT",
                                                 tickFraction * barWidth - 1, 0)
                    frame.interruptTick:Show()
                end
            end
        else
            frame.interruptTick:Hide()
        end
    end)

    frame:Hide()
    return frame
end

-- ============================================================
--  Colour helpers
-- ============================================================
local function ApplyBarColor(interruptible)
    local c = interruptible and ns.db.castBarColor or ns.db.castBarColorSafe
    CastBar.frame.bar:SetStatusBarColor(c.r, c.g, c.b, c.a)
end

local function ApplyAlertTextStyle()
    local db       = ns.db
    local bar      = CastBar.frame.bar
    local kickText = CastBar.frame.kickText
    local fontPath = (LSM and LSM:Fetch("font", db.alertTextFont))
                     or "Fonts\\FRIZQT__.TTF"
    kickText:SetFont(fontPath, db.alertTextSize, "OUTLINE")
    local c = db.alertTextColor
    kickText:SetTextColor(c.r, c.g, c.b, c.a)

    if db.alertTextMode == "spellname" then
        local label = (castData.spellName ~= "" and castData.spellName) or "Spell Name"
        kickText:SetText(label)
    else
        kickText:SetText(db.alertText ~= "" and db.alertText or "KICK")
    end

    kickText:SetJustifyH(db.alertTextAnchor == "LEFT" and "LEFT"
                      or db.alertTextAnchor == "RIGHT" and "RIGHT"
                      or "CENTER")
    kickText:ClearAllPoints()
    kickText:SetPoint(db.alertTextAnchor, bar, db.alertTextAnchor, 0, 0)
end

local function ApplyDurationTextStyle()
    local db           = ns.db
    local bar          = CastBar.frame.bar
    local durationText = CastBar.frame.durationText
    local fontPath     = (LSM and LSM:Fetch("font", db.castDurationFont))
                         or "Fonts\\FRIZQT__.TTF"
    durationText:SetFont(fontPath, db.castDurationSize, "OUTLINE")
    local c = db.castDurationColor
    durationText:SetTextColor(c.r, c.g, c.b, c.a)
    durationText:ClearAllPoints()
    local anchor = db.castDurationAnchor
    local xOff   = anchor == "LEFT" and 4 or anchor == "RIGHT" and -4 or 0
    durationText:SetPoint(anchor, bar, anchor, xOff, 0)
end

-- ============================================================
--  Public: Show / Hide
-- ============================================================
function CastBar:Show(spellName, startTime, endTime, interruptible)
    if not self.frame then BuildCastBar() end

    castData.active        = true
    castData.spellName     = spellName
    castData.startTime     = startTime
    castData.endTime       = endTime
    castData.interruptible = interruptible
    castData.isMock        = false

    self.frame.spellText:SetText(spellName or "")
    ApplyBarColor(interruptible)
    self.frame.bar:SetValue(0)

    if interruptible then
        ApplyAlertTextStyle()
        self.frame.kickText:Show()
        self:PlayAlert()
    else
        self.frame.kickText:Hide()
    end

    if ns.db.castDurationShow then
        ApplyDurationTextStyle()
        self.frame.durationText:Show()
    end

    self.frame:Show()
end

function CastBar:Hide()
    castData.active = false
    if self.frame then
        self.frame.bar:SetValue(0)
        self.frame.durationText:Hide()
        self.frame.interruptTick:Hide()
        self.frame:Hide()
    end
end

-- ============================================================
--  Public: Test mock cast (/kt testcast)
-- ============================================================
function CastBar:ShowWithMockData(data)
    if not self.frame then BuildCastBar() end
    local now = GetTime()
    self:Show(
        data.spellName    or "Frost Bolt",
        now,
        now + (data.duration or 3.0),
        data.interruptible ~= false
    )
    castData.isMock = true
end

-- ============================================================
--  Public: Sound (/kt testsound + on cast start)
-- ============================================================
function CastBar:PlayAlert()
    local db = ns.db

    if db.alertSound == "tts" then
        -- Use the alert label text (or "Kick" as fallback) as the spoken word
        local text = (db.alertTextMode == "custom" and db.alertText ~= "")
                     and db.alertText or "Kick"
        -- Modern TTS API (9.0+)
        if C_VoiceChat and C_VoiceChat.SpeakText then
            local dest = (Enum.VoiceTtsDestination
                          and Enum.VoiceTtsDestination.LocalPlayback) or 0
            C_VoiceChat.SpeakText(1, text, dest, 100, 0)
        elseif TextToSpeech_Speak then
            -- Legacy fallback
            TextToSpeech_Speak(text, 0)
        end

    elseif db.alertSound == "lsm" then
        if LSM and db.alertSoundLSM and db.alertSoundLSM ~= "" then
            local path = LSM:Fetch("sound", db.alertSoundLSM)
            if path then PlaySoundFile(path, "SFX") end
        end

    elseif db.alertSound == "wowui" then
        PlaySound(8959, "SFX", false) -- Raid Warning

    elseif db.alertSound == "custom" and db.alertSoundCustom ~= "" then
        PlaySoundFile(db.alertSoundCustom, "SFX")
    end
end

-- ============================================================
--  Public: Apply setting changes (called from Settings on change)
-- ============================================================
function CastBar:ApplySettings()
    if not self.frame then return end
    local db  = ns.db
    local bar = self.frame.bar
    self.frame:SetSize(db.castBarWidth, db.castBarHeight + 18)
    ApplyBarColor(castData.interruptible)
    if LSM then
        bar:SetStatusBarTexture(LSM:Fetch("statusbar", db.castBarTexture))
    end
    ApplyAlertTextStyle()
    ApplyDurationTextStyle()

    -- Interrupt tick height tracks bar height
    self.frame.interruptTick:SetHeight(db.castBarHeight)
end

-- ============================================================
--  Register cast events
-- ============================================================
function CastBar:Initialize()
    local frame = CreateFrame("Frame")
    frame:RegisterEvent("UNIT_SPELLCAST_START")
    frame:RegisterEvent("UNIT_SPELLCAST_STOP")
    frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
    frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

    frame:SetScript("OnEvent", function(_, event, unitTarget)
        if unitTarget ~= "focus" then return end

        if event == "UNIT_SPELLCAST_START" then
            CastBar:OnCastStart(false)
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
            CastBar:OnCastStart(true)
        elseif event == "UNIT_SPELLCAST_STOP"
            or event == "UNIT_SPELLCAST_INTERRUPTED"
            or event == "UNIT_SPELLCAST_FAILED"
            or event == "UNIT_SPELLCAST_SUCCEEDED"
            or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            CastBar:Hide()
        end
    end)

    -- Build frame on init so saved position restores immediately
    BuildCastBar()
end

function CastBar:OnCastStart(isChannel)
    local name, startTimeMS, endTimeMS, notInterruptible

    if isChannel then
        -- UnitChannelInfo: name, text, texture, startMS, endMS, isTradeSkill, notInterruptible, ...
        name, _, _, startTimeMS, endTimeMS, _, notInterruptible = UnitChannelInfo("focus")
    else
        -- UnitCastingInfo (TWW): name, text, texture, startMS, endMS, isTradeSkill, notInterruptible, ...
        -- castID was removed in 11.x — notInterruptible is now position 7, not 8
        name, _, _, startTimeMS, endTimeMS, _, notInterruptible = UnitCastingInfo("focus")
    end

    if not name then return end

    -- TWW marks notInterruptible as a "secret boolean" — avoid the `not` operator on it directly
    local interruptible
    if notInterruptible then
        interruptible = false
    else
        interruptible = true
    end

    -- Respect the "show only interruptible" setting
    if not interruptible and not ns.db.castBarAllCasts then return end

    CastBar:Show(name, startTimeMS / 1000, endTimeMS / 1000, interruptible)
end

-- (Initialized by Core.lua:OnEnable → ns.CastBar:Initialize())
