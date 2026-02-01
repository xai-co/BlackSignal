-- Modules/FocusCastTracker.lua
-- @module FocusCastTracker
-- @alias FocusCastTracker

local _, BS     = ...;

local API       = BS.API
local DB        = BS.DB
local Tickers   = BS.Tickers
local Events    = BS.Events

local FocusCastTracker = {
    name = "FocusCastTracker",
    enabled = true,
    events = {},
}

API:Register(FocusCastTracker)

-------------------------------------------------
-- Constants / Defaults
-------------------------------------------------
local FONT = "Fonts\\FRIZQT__.TTF"

local defaults = {
    enabled = true,
    x = 0,
    y = -120,
    fontSize = 16,
    font = FONT,

    text = "",

    updateInterval = 0.05,

    debugAlwaysShow = false,
    onlyShowIfKickReady = true,

    kickSpellIdOverride = nil,

    alphaReady = 1.0,
    alphaNotReady = 0,
}

FocusCastTracker.defaults = defaults
function FocusCastTracker:BuildDefaults()
    return defaults
end

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

-- Base cooldowns
local KICK_BASE_CD = {
    [6552]   = 15, -- Pummel
    [1766]   = 15, -- Kick
    [2139]   = 25, -- Counterspell
    [147362] = 24, -- Counter Shot
    [57994]  = 12, -- Wind Shear
    [106839] = 15, -- Skull Bash
    [96231]  = 15, -- Rebuke
    [47528]  = 15, -- Mind Freeze
    [183752] = 15, -- Disrupt
    [116705] = 15, -- Spear Hand Strike
    [19647]  = 24, -- Spell Lock
    [351338] = 40, -- Quell
}

local KICK_TALENT_MODIFIERS = {
    -- MAGE: Counterspell
    [2139] = {
        { talentSpellId = 382297, delta = -5 },
    },
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
    self.text = t
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
-- Target class color helpers
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
    if UnitExists("focus-target") then
        return GetUnitNameColoredByClass("focus-target")
    end
    return nil
end

-------------------------------------------------
-- Kick cooldown computation (base + talent constants)
-------------------------------------------------
function FocusCastTracker:GetKickSpellId()
    if self.db and self.db.kickSpellIdOverride then
        return self.db.kickSpellIdOverride
    end

    local _, class = UnitClass("player")
    return class and KICK_BY_CLASS[class] or nil
end

function FocusCastTracker:GetKickTalentModifier(spellId)
    local mods = KICK_TALENT_MODIFIERS[spellId]
    if not mods then return 0 end

    local total = 0
    for _, m in ipairs(mods) do
        -- IsPlayerSpell suele ser seguro y NO devuelve secret; aun así, lo uso directo
        if m and m.talentSpellId and IsPlayerSpell(m.talentSpellId) then
            total = total + (m.delta or 0)
        end
    end
    return total
end

function FocusCastTracker:RecomputeKickCooldown()
    local spellId = self:GetKickSpellId()
    if not spellId then
        self.kickCooldownSeconds = nil
        return
    end

    local base = KICK_BASE_CD[spellId]
    if not base then
        self.kickCooldownSeconds = nil
        return
    end

    local mod = self:GetKickTalentModifier(spellId)
    local cd = base + mod
    if cd < 0 then cd = 0 end
    self.kickCooldownSeconds = cd
end

-------------------------------------------------
-- Cast state
-------------------------------------------------
function FocusCastTracker:ClearCast()
    self.castInfo = nil
    if self.frame then
        self.frame:SetAlpha(1.0)
        self.frame:Hide()
    end
    Tickers:Stop(self)
end

function FocusCastTracker:ReadFocusCast()
    if not UnitExists("focus") then
        return nil
    end

    local name, _, _, _, _, _, _, _, spellId = UnitCastingInfo("focus")

    if not name then
        return nil
    end

    return {
        name = name,
        spellId = spellId,
        targetName = GetFocusTargetName(),
    }
end

function FocusCastTracker:ShouldShowForCurrentState()
    if not self.db or self.db.enabled == false then return false end
    if not self.castInfo then return false end
    return true
end

-------------------------------------------------
-- Kick ready logic
-------------------------------------------------
function FocusCastTracker:IsKickReadySoft()
    if not (self.db and self.db.onlyShowIfKickReady) then
        return true
    end

    local cd = self.kickCooldownSeconds
    if not cd then
        return false
    end

    if not self.lastKickAt then
        return true
    end

    return (GetTime() - self.lastKickAt) >= cd
end

-------------------------------------------------
-- Update
-------------------------------------------------
function FocusCastTracker:Update()
    if not self.db or self.db.enabled == false then return end
    if not self.frame or not self.text then return end

    if self.db.debugAlwaysShow and not UnitExists("focus") then
        self.frame:SetAlpha(1.0)
        self.frame:Show()
        self.text:SetText("Focus: no existe")
        return
    end

    if not self.castInfo then
        if self.db.debugAlwaysShow and UnitExists("focus") then
            self.frame:SetAlpha(1.0)
            self.frame:Show()
            self.text:SetText("Focus: sin casteo")
        else
            self.frame:Hide()
        end
        return
    end

    if self:ShouldShowForCurrentState() ~= true then
        if self.db.debugAlwaysShow and UnitExists("focus") then
            self.frame:SetAlpha(1.0)
            self.frame:Show()
            self.text:SetText("Focus: casteando (estado inválido)")
        else
            self.frame:Hide()
        end
        return
    end

    if self.db.onlyShowIfKickReady then
        local ready = self:IsKickReadySoft()
        local aReady = tonumber(self.db.alphaReady) or 1.0
        local aNot = tonumber(self.db.alphaNotReady) or 0
        self.frame:SetAlpha(ready and aReady or aNot)
    else
        self.frame:SetAlpha(1.0)
    end

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
    self.frame:Show()
end

-------------------------------------------------
-- Ticker (BS)
-------------------------------------------------
function FocusCastTracker:StartTicker()
    Tickers:Stop(self)
    local interval = tonumber(self.db and self.db.updateInterval) or defaults.updateInterval
    if interval < 0.02 then interval = 0.02 end

    Tickers:Register(self, interval, function()
        if self.castInfo then
            local refreshed = self:ReadFocusCast()
            if not refreshed then
                self:ClearCast()
                return
            end
            self.castInfo = refreshed
        end
        self:Update()
    end)
end

-------------------------------------------------
-- Public hooks for Config UI
-------------------------------------------------
function FocusCastTracker:ApplyOptions()
    EnsureUI(self)
    ApplyPosition(self)
    ApplyFont(self)

    if not InCombatLockdown() then
        self:RecomputeKickCooldown()
    end

    if self.enabled then
        if self.castInfo then
            self:StartTicker()
        end
        self:Update()
    else
        self:ClearCast()
    end
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
    BS.Movers:Register(self.frame, self.name, "Focus Cast Tracker")

    self.lastKickAt = nil
    self.kickCooldownSeconds = nil

    if not InCombatLockdown() then
        self:RecomputeKickCooldown()
    end

    self.frame:SetShown(self.enabled)

    if self.enabled then
        self.castInfo = self:ReadFocusCast()
        if self.castInfo then
            self:StartTicker()
        else
            Tickers:Stop(self)
        end
        self:Update()
    else
        self:ClearCast()
    end

    local f = Events.Create()

    f:RegisterEvent("PLAYER_FOCUS_CHANGED")
    f:RegisterEvent("UNIT_SPELLCAST_START")
    f:RegisterEvent("UNIT_SPELLCAST_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_FAILED")
    f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    f:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    f:RegisterEvent("UNIT_SPELLCAST_DELAYED")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
    f:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
    f:RegisterEvent("PLAYER_TALENT_UPDATE")
    f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-------------------------------------------------
-- Events (BS dispatcher)
-------------------------------------------------
FocusCastTracker.events.PLAYER_FOCUS_CHANGED = function(self)
    if not self.enabled then return end
    self.castInfo = self:ReadFocusCast()

    if self.castInfo then
        self:StartTicker()
    else
        Tickers:Stop(self)
    end
    self:Update()
end

local function HandleFocusCastEvent(self, unit)
    if unit ~= "focus" then return end
    if not self.enabled then return end

    self.castInfo = self:ReadFocusCast()
    if self.castInfo then
        self:StartTicker()
    else
        Tickers:Stop(self)
    end
    self:Update()
end

FocusCastTracker.events.UNIT_SPELLCAST_START = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_STOP = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_FAILED = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_INTERRUPTED = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_DELAYED = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_START = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_STOP = HandleFocusCastEvent
FocusCastTracker.events.UNIT_SPELLCAST_CHANNEL_UPDATE = HandleFocusCastEvent

FocusCastTracker.events.UNIT_SPELLCAST_SUCCEEDED = function(self, unit, castGUID, spellId)
    if unit == "focus" then
        HandleFocusCastEvent(self, unit)
        return
    end

    if unit ~= "player" then return end
    if not self.enabled then return end
    if not self.db.onlyShowIfKickReady then return end

    local kickId = self:GetKickSpellId()
    if kickId and spellId == kickId then
        self.lastKickAt = GetTime()
        self:Update()
    end
end

FocusCastTracker.events.PLAYER_TALENT_UPDATE = function(self)
    if not self.enabled then return end
    if InCombatLockdown() then return end
    self:RecomputeKickCooldown()
    if self.castInfo then
        self:Update()
    end
end

FocusCastTracker.events.PLAYER_SPECIALIZATION_CHANGED = function(self)
    if not self.enabled then return end
    if InCombatLockdown() then return end
    self:RecomputeKickCooldown()
    if self.castInfo then
        self:Update()
    end
end

FocusCastTracker.events.PLAYER_REGEN_ENABLED = function(self)
    if not self.enabled then return end
    self:RecomputeKickCooldown()
    if self.castInfo then
        self:Update()
    end
end