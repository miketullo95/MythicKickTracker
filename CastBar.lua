-- TulloKickTracker
-- CastBar.lua — Custom interruptible cast bar for the focus target

local addonName, ns = ...
local CastBar = {}
ns.CastBar = CastBar

-- Localise hot-path globals
local GetTime         = GetTime
local UnitCastingInfo = UnitCastingInfo
local UnitChannelInfo = UnitChannelInfo

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
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    frame.bar = bar

    -- "INTERRUPT!" flash text
    local kickText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    kickText:SetPoint("CENTER", frame, "CENTER", 0, 0)
    kickText:SetText("|cFFFF2222INTERRUPT!|r")
    kickText:Hide()
    frame.kickText = kickText

    CastBar.frame = frame

    -- OnUpdate: animate the fill
    frame:SetScript("OnUpdate", function()
        if not castData.active then return end
        local now      = GetTime()
        local total    = castData.endTime - castData.startTime
        local elapsed  = now - castData.startTime
        if elapsed >= total then
            CastBar:Hide()
            return
        end
        bar:SetValue(elapsed / total)
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
        self.frame.kickText:Show()
        C_Timer.After(0.8, function()
            if self.frame then self.frame.kickText:Hide() end
        end)
        self:PlayAlert()
    else
        self.frame.kickText:Hide()
    end

    self.frame:Show()
end

function CastBar:Hide()
    castData.active = false
    if self.frame then
        self.frame.bar:SetValue(0)
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
        if TextToSpeech_Speak then
            TextToSpeech_Speak("Kick", 0)
        else
            self:_PlayBundled()
        end
    elseif db.alertSound == "bundled" then
        self:_PlayBundled()
    elseif db.alertSound == "wowui" then
        PlaySound(8959, "SFX", false) -- Raid Warning
    elseif db.alertSound == "custom" and db.alertSoundCustom ~= "" then
        PlaySoundFile(db.alertSoundCustom, "SFX")
    end
end

function CastBar:_PlayBundled()
    local path = "Interface\\AddOns\\TulloKickTracker\\Media\\sounds\\kick.ogg"
    PlaySoundFile(path, "SFX")
end

-- ============================================================
--  Public: Apply setting changes (called from Settings on change)
-- ============================================================
function CastBar:ApplySettings()
    if not self.frame then return end
    local db = ns.db
    self.frame:SetSize(db.castBarWidth, db.castBarHeight + 18)
    ApplyBarColor(castData.interruptible)
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
    local name, startTime, endTime, notInterruptible

    if isChannel then
        name, _, _, startTime, endTime, _, notInterruptible = UnitChannelInfo("focus")
    else
        name, _, _, startTime, endTime, _, _, notInterruptible = UnitCastingInfo("focus")
    end

    if not name then return end

    local interruptible = not notInterruptible

    -- Respect the "show only interruptible" setting
    if not interruptible and not ns.db.castBarAllCasts then return end

    CastBar:Show(name, startTime / 1000, endTime / 1000, interruptible)
end

-- (Initialized by Core.lua:OnEnable → ns.CastBar:Initialize())
