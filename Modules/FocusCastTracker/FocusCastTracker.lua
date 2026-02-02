-- Modules/FocusCastTracker.lua
-- @module FocusCastTracker
-- @alias FocusCastTracker

local _, BS            = ...

local API              = BS.API
local DB               = BS.DB
local Tickers          = BS.Tickers
local Events           = BS.Events

local FocusCastTracker = {
    name    = "BS_FCT",
    label   = "Focus Cast Tracker",
    enabled = true,
    events  = {},
}

API:Register(FocusCastTracker)

-------------------------------------------------
-- Constants / Defaults
-------------------------------------------------
local FONT = "Fonts\\FRIZQT__.TTF"

local defaults = {
    enabled                 = true,
    x                       = 0,
    y                       = 200,
    fontSize                = 16,
    font                    = FONT,

    text                    = "",

    updateInterval          = 0.05,

    onlyShowIfKickReady     = true,
}

FocusCastTracker.defaults = defaults

local GetSpellCooldown = C_Spell.GetSpellCooldown

local KICK_BY_CLASS = {
    WARRIOR     = 6552,   -- Pummel
    ROGUE       = 1766,   -- Kick
    MAGE        = 2139,   -- Counterspell
    HUNTER      = 147362, -- Counter Shot
    SHAMAN      = 57994,  -- Wind Shear
    DRUID       = 106839, -- Skull Bash
    PALADIN     = 96231,  -- Rebuke
    DEATHKNIGHT = 47528,  -- Mind Freeze
    DEMONHUNTER = 183752, -- Disrupt
    MONK        = 116705, -- Spear Hand Strike
    WARLOCK     = 19647,  -- Spell Lock
    EVOKER      = 351338, -- Quell
}

-------------------------------------------------
-- UI
-------------------------------------------------
local function EnsureUI(self)
    if self.frame and self.text then return end

    local f = CreateFrame("Frame", "BS_FocusCastTrackerDisplay", UIParent)
    f:SetSize(380, 30)
    f:SetFrameStrata("LOW")
    f:Hide()

    local t = f:CreateFontString(nil, "OVERLAY")
    t:SetPoint("CENTER")
    t:SetJustifyH("CENTER")
    t:SetTextColor(1, 1, 1, 1)

    self.frame = f
    self.text  = t
end

local function ApplyPosition(self)
    if not self.frame or not self.db then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or -120)
end

local function ApplyFont(self)
    if not self.text or not self.db then return end
    local fontPath = self.db.font or FONT
    self.text:SetFont(fontPath, tonumber(self.db.fontSize) or 16, "OUTLINE")
end

-------------------------------------------------
-- Helpers
-------------------------------------------------
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

local function ColorizeText(text, color)
    if not text or not color then return text end

    if color.colorStr then
        return "|c" .. color.colorStr .. text .. "|r"
    end

    local r = math.floor((color.r or 1) * 255 + 0.5)
    local g = math.floor((color.g or 1) * 255 + 0.5)
    local b = math.floor((color.b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, text)
end

local function GetUnitNameColoredByClass(unit)
    if not UnitExists(unit) then return nil end
    local name = UnitName(unit)
    if not name then return nil end

    local _, classTag = UnitClass(unit)
    if classTag and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classTag] then
        return ColorizeText(name, RAID_CLASS_COLORS[classTag])
    end

    return name
end

local function GetFocusTargetName()
    -- IMPORTANT: correct unit token is "focustarget"
    if UnitExists("focustarget") then
        return GetUnitNameColoredByClass("focustarget")
    end
    return nil
end

local function GetKickId()
    local _, class = UnitClass("player")
    return class and KICK_BY_CLASS[class] or nil
end

local function IsKickReady(spellID)
    local cdInfo = GetSpellCooldown(spellID)
    local isOnGCD = cdInfo and cdInfo.isOnGCD

    return isOnGCD
end

-------------------------------------------------
-- Spell selection
-------------------------------------------------
function FocusCastTracker:ResolveSpell()
    local kickId = GetKickId()
    if not kickId then
        self.spellID = nil
        return
    end

    -- C_SpellBook.IsSpellKnown can be nil in some edge environments; guard it.
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        if C_SpellBook.IsSpellKnown(kickId) then
            self.spellID = kickId
        else
            self.spellID = nil
        end
    else
        -- fallback: assume available if we have an id (worst case it'll just be "not ready")
        self.spellID = kickId
    end
end

-------------------------------------------------
-- Cast state
-------------------------------------------------
function FocusCastTracker:ReadFocusCast()
    if not UnitExists("focus") then
        self.castInfo = nil
        return nil
    end

    local name, _, _, _, _, _, _, _, spellId = UnitCastingInfo("focus")

    if not name then
        -- also consider channels
        name, _, _, _, _, _, _, _, _, spellId = UnitChannelInfo("focus")
    end

    if not name then
        self.castInfo = nil
        return nil
    end

    local info = {
        name             = name,
        spellId          = spellId,
        targetName       = GetFocusTargetName(),
    }

    self.castInfo = info
    return info
end

function FocusCastTracker:ClearCast()
    self.castInfo = nil
    if self.text then
        self.text:SetText("")
    end
end

-------------------------------------------------
-- Ticker (BS)
-------------------------------------------------
function FocusCastTracker:StartTicker()
    BS.Tickers:Stop(self)
    BS.Tickers:Register(self, tonumber(self.db.updateInterval) or 0.05, function()
        -- Keep cast info fresh while ticker runs
        self:ReadFocusCast()
        self:Update()
    end)
end

-------------------------------------------------
-- Update
-------------------------------------------------
function FocusCastTracker:Update()
    if not self.db or self.db.enabled == false then return end
    if not self.frame or not self.text then return end

    -- Nothing to show if no focus cast
    if not self.castInfo or not self.castInfo.name then
        self.frame:SetAlpha(0)
        return
    end

    local kickReady = IsKickReady(self.spellID)

    if self.db.onlyShowIfKickReady then
        self.frame:SetAlphaFromBoolean(kickReady ~= false, 1, 0)
    else
        self.frame:SetAlpha(1)
    end

    -- Build message
    local msg
    if self.db.text and self.db.text ~= "" then
        msg = self.db.text
    else
        msg = self.castInfo.name
        if self.castInfo.targetName then
            msg = msg .. " >> " .. self.castInfo.targetName
        end
    end

    self.text:SetText(msg)
end

-------------------------------------------------
-- Public hooks for Config UI
-------------------------------------------------
function FocusCastTracker:ApplyOptions()
    EnsureUI(self)
    ApplyPosition(self)
    ApplyFont(self)

    self.enabled = (self.db and self.db.enabled ~= false)

    self.frame:SetShown(self.enabled)

    if not self.enabled then
        BS.Tickers:Stop(self)
        self:ClearCast()
        return
    end

    self:ResolveSpell()
    self:ReadFocusCast()

    if self.castInfo then
        self:StartTicker()
    else
        BS.Tickers:Stop(self)
    end

    self:Update()
end

-------------------------------------------------
-- Init
-------------------------------------------------
function FocusCastTracker:OnInit()
    self.db = DB:EnsureDB(self.name, defaults)
    self.enabled = (self.db.enabled ~= false)

    EnsureUI(self)
    ApplyPosition(self)
    ApplyFont(self)

    if BS.Movers then
        BS.Movers:Register(self.frame, self.name, "Focus Cast Tracker")
    end

    self:ResolveSpell()
    self:ReadFocusCast()

    self.frame:SetShown(self.enabled)

    if self.enabled and self.castInfo then
        self:StartTicker()
    else
        BS.Tickers:Stop(self)
    end

    self:Update()

    Events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    Events:RegisterEvent("PLAYER_FOCUS_CHANGED")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_START", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "focus")
    Events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "focus")
end

-------------------------------------------------
-- Events (BS dispatcher)
-------------------------------------------------
FocusCastTracker.events.SPELL_UPDATE_COOLDOWN = function(self)
    self:Update()
end

local function HandleFocusCastEvent(self, unit)
    if unit ~= "focus" then return end
    if not self.enabled then return end

    local info = self:ReadFocusCast()
    if info then
        self:StartTicker()
    else
        Tickers:Stop(self)
        self:ClearCast()
    end

    self:Update()
end

local function TalentUpdate(self)
    C_Timer.After(0.5, function()
        self:ResolveSpell()
    end)
    C_Timer.After(0.6, function()
        if self.enabled then
            -- if there's an active cast keep ticker, otherwise stop it
            self:ReadFocusCast()
            if self.castInfo then
                self:StartTicker()
            else
                Tickers:Stop(self)
            end
            self:Update()
        end
    end)
end

FocusCastTracker.events.PLAYER_FOCUS_CHANGED          = HandleFocusCastEvent
FocusCastTracker.events.PLAYER_SPECIALIZATION_CHANGED = TalentUpdate
FocusCastTracker.events.TRAIT_CONFIG_UPDATED          = TalentUpdate
FocusCastTracker.events.ACTIVE_TALENT_GROUP_CHANGED   = TalentUpdate
FocusCastTracker.events.UNIT_SPELLCAST_START          = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_STOP           = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_FAILED         = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_INTERRUPTED    = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_DELAYED        = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_START  = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_STOP   = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_UPDATE = HandleFocusCastEvent
