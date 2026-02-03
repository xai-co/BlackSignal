-- Modules/MovementWarnings.lua
-- @module MovementWarnings
-- @alias MovementWarnings

local _, BS            = ...

local API              = BS.API
local Events           = BS.Events

local MovementWarnings = {
    name    = "BS_S",
    label   = "Movement Warnings",
    enabled = true,
    events  = {},
}

API:Register(MovementWarnings)

-------------------------------------------------
-- Spell (by class)
-- Each entry can contain multiple spellIds; we pick the first known.
-------------------------------------------------
local CLASS_SPELLS          = {
    MAGE = {
        { key = "blink", label = "Blink/Shimmer", spellIds = { 212653, 1953 } },
    },
    HUNTER = {
        { key = "disengage", label = "Disengage", spellIds = { 781 } },
    },
    ROGUE = {
        { key = "step", label = "Shadowstep", spellIds = { 36554 } },
    },
    WARLOCK = {
        { key = "circle", label = "Demonic Circle", spellIds = { 48020 } },
    },
    WARRIOR = {
        { key = "charge", label = "Charge", spellIds = { 100 } },
    },
    PALADIN = {
        { key = "steed", label = "Divine Steed", spellIds = { 190784 } },
    },
    MONK = {
        { key = "roll", label = "Roll/Chi Torpedo", spellIds = { 109132, 115008 } },
    },
    DRUID = {
        { key = "dash", label = "Dash", spellIds = { 1850 } },
    },
    SHAMAN = {
        { key = "gust_winds", label = "Gust of Winds", spellIds = { 192063 } },
    },
    PRIEST = {
        { key = "feather",   label = "Angelic Feather", sdapellIds = { 121536 } },
    },
    DEATHKNIGHT = {
        { key = "deaths_advance", label = "Death's Advance", spellIds = { 48265 } },
    },
    DEMONHUNTER = {
        { key = "felrush",  label = "Fel Rush",         spellIds = { 195072 } },
        { key = "infernal_strike", label = "Infernal Strike", spellIds = { 189110 } },
        { key = "shift", label = "Shift", spellIds = { 1234796 } },
    },
    EVOKER = {
        { key = "hover", label = "Hover", spellIds = { 358267 } },
    },
}

-------------------------------------------------
-- Defaults
-------------------------------------------------
local defaults            = {
    enabled     = true,
    x           = 0,
    y           = 18,

    font        = "Fonts\\FRIZQT__.TTF",
    fontSize    = 20,
    outline     = "OUTLINE",

    -- Selection
    autoSelect  = true, -- auto-pick first known from class CLASS_SPELLS
    selectedKey = nil, -- if set, try to use that key first (per-class list)
}

MovementWarnings.defaults = defaults

-------------------------------------------------
-- Locals / helpers
-------------------------------------------------
local IsSpellKnown             = C_SpellBook and C_SpellBook.IsSpellKnown
local GetSpellCooldown         = C_Spell.GetSpellCooldown
local GetSpellCooldownDuration = C_Spell.GetSpellCooldownDuration

local function GetPlayerClass()
    local _, class = UnitClass("player")
    return class
end

local function FirstKnownSpellId(spellIds)
    if type(spellIds) ~= "table" then return nil end
    for _, id in ipairs(spellIds) do
        if id and IsSpellKnown and IsSpellKnown(id) then
            return id
        end
    end
    return nil
end

-------------------------------------------------
-- UI
-------------------------------------------------
local function EnsureUI(self)
    if self.frame and self.text then return end

    local f = CreateFrame("Frame", "BS_MovementWarningsDisplay", UIParent)
    f:SetSize(400, 30)
    f:SetFrameStrata("LOW")
    f:Show()

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
    self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or 18)
end

local function ApplyFont(self)
    if not self.text or not self.db then return end
    local font = self.db.font or defaults.font
    local size = tonumber(self.db.fontSize) or defaults.fontSize
    local outline = self.db.outline or defaults.outline
    self.text:SetFont(font, size, outline)
end

-------------------------------------------------
-- Spell resolution
-------------------------------------------------
function MovementWarnings:ResolveSpell()
    self.spellKey = nil
    self.spellID  = nil

    local class   = GetPlayerClass()
    if not class then return end

    local list = CLASS_SPELLS[class]
    if type(list) ~= "table" then return end

    local wanted = self.db and self.db.selectedKey
    if wanted then
        for _, entry in ipairs(list) do
            if entry and entry.key == wanted then
                local id = FirstKnownSpellId(entry.spellIds)
                if id then
                    self.spellKey   = entry.key
                    self.spellID    = id
                    self.spellLabel = entry.label
                    return
                end
            end
        end
    end

    if self.db and self.db.autoSelect == false then return end

    for _, entry in ipairs(list) do
        local id = entry and FirstKnownSpellId(entry.spellIds)
        if id then
            self.spellKey   = entry.key
            self.spellID    = id
            self.spellLabel = entry.label
            return
        end
    end
end

-------------------------------------------------
-- Update
-------------------------------------------------
function MovementWarnings:Update()
    if not self.db or self.db.enabled == false then return end
    if not self.spellID or not self.frame or not self.text then return end

    local durationObject = GetSpellCooldownDuration(self.spellID)
    ---@diagnostic disable-next-line: undefined-field
    if not durationObject or not durationObject.GetRemainingDuration then return end

    ---@diagnostic disable-next-line: undefined-field
    local actualCooldown = durationObject:GetRemainingDuration(1)

    local cdInfo         = GetSpellCooldown(self.spellID)
    local isOnGCD        = cdInfo and cdInfo.isOnGCD

    if self.frame.SetAlphaFromBoolean then
        self.frame:SetAlphaFromBoolean(isOnGCD ~= false, 0, 1)
    else
        self.frame:SetAlpha((isOnGCD ~= false) and 1 or 0)
    end

    local spell = C_Spell.GetSpellInfo(self.spellID)
    local spellName = (spell and spell.name) or "Movement"

    self.text:SetText(string.format("No %s: %.1f", spellName, actualCooldown))
end

-------------------------------------------------
-- Ticker
-------------------------------------------------
function MovementWarnings:StartTicker()
    BS.Tickers:Stop(self)
    BS.Tickers:Register(self, 0.1, function()
        self:Update()
    end)
end

-------------------------------------------------
-- Talent/spec changes
-------------------------------------------------
local function TalentUpdate(self)
    C_Timer.After(0.35, function()
        self:ResolveSpell()
    end)
    C_Timer.After(0.45, function()
        if self.enabled then
            self:Update()
        end
    end)
end

-------------------------------------------------
-- Init / Enable / Disable
-------------------------------------------------
function MovementWarnings:OnInit()
    self.db = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = (self.db.enabled ~= false)

    EnsureUI(self)
    ApplyPosition(self)
    ApplyFont(self)

    BS.Movers:Register(self.frame, self.name, "Movement Warnings")

    self:ResolveSpell()
    self.frame:SetShown(self.enabled)

    if self.enabled then
        self:StartTicker()
        self:Update()
    else
        BS.Tickers:Stop(self)
    end

    Events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    Events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    Events:RegisterEvent("TRAIT_CONFIG_UPDATED")
    Events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
end

function MovementWarnings:OnDisabled()
    self.db = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = false
    if self.db then self.db.enabled = false end

    if BS.Tickers and BS.Tickers.Stop then
        BS.Tickers:Stop(self)
    end

    if Events and Events.UnregisterAllEventsFor then
        Events:UnregisterAllEventsFor(self)
    else
        if Events and Events.UnregisterEvent then
            Events:UnregisterEvent("SPELL_UPDATE_COOLDOWN")
            Events:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
            Events:UnregisterEvent("TRAIT_CONFIG_UPDATED")
            Events:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
        end
    end

    if self.frame then
        self.frame:Hide()
    end

    if BS.Movers and BS.Movers.Unregister and self.frame then
        BS.Movers:Unregister(self.frame, self.name)
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
MovementWarnings.events.SPELL_UPDATE_COOLDOWN         = function(self) self:Update() end
MovementWarnings.events.PLAYER_SPECIALIZATION_CHANGED = TalentUpdate
MovementWarnings.events.TRAIT_CONFIG_UPDATED          = TalentUpdate
MovementWarnings.events.ACTIVE_TALENT_GROUP_CHANGED   = TalentUpdate
