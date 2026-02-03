-- Modules/BuffTracker/BuffTracker.lua
-- @module BuffTracker
-- @alias BuffTracker

local _, BS  = ...
local API    = BS.API
local Events = BS.Events

local BuffTracker = {
    name    = "BS_BT",
    label   = "Buff Tracker",
    enabled = true,
    classes = nil,
    events  = {},
}

API:Register(BuffTracker)

-------------------------------------------------
-- Constants
-------------------------------------------------
local READY_CHECK_DURATION = 15          -- seconds (fixed)
local UPDATE_THROTTLE_SEC  = 0.20        -- UI refresh cap

-------------------------------------------------
-- Defaults
-------------------------------------------------
local defaults = {
    enabled                 = true,

    locked                  = true,
    scale                   = 1,
    iconSize                = 64,
    spacing                 = 8,
    perRow                  = 12,
    showText                = true,
    x                       = 0,
    y                       = 500,
    showOptions             = true,

    showOnlyInGroup         = false,
    showOnlyInInstance      = false,
    showOnlyPlayerClassBuff = false,
    showOnlyPlayerMissing   = false,
    showOnlyOnReadyCheck    = false,

    showExpirationGlow      = true,
    expirationThreshold     = 15, -- minutes

    categories              = {
        raid     = true,
        presence = true,
        personal = true,
        self     = true,
        -- custom buffs (self-only) -> se gestionan en Data/Engine/UI
    },
}

-------------------------------------------------
-- Internal helpers
-------------------------------------------------
local function EnsureDeps(self)
    self.Data   = BS.BuffTrackerData
    self.Engine = BS.BuffTrackerEngine
    self.UI     = BS.BuffTrackerUI
end

local function CancelReadyCheckTimer(self)
    if self._readyCheckTimer then
        self._readyCheckTimer:Cancel()
        self._readyCheckTimer = nil
    end
end

local function IsMythicPlusActive()
    return C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive()
end

local function UpdateChallengeState(self)
    self._inChallengeMode = IsMythicPlusActive() and true or false
end

local function ScheduleTalentRefresh(self)
    -- Talent swaps spam multiple events; coalesce them.
    if self._talentTimer then
        self._talentTimer:Cancel()
        self._talentTimer = nil
    end
    self._talentTimer = C_Timer.NewTimer(0.25, function()
        self._talentTimer = nil
        self:RequestUpdate(true)
    end)
end

-- IMPORTANT:
-- En tu UI.lua existe UI:HideAll() (y NO UI:Hide()).
-- Si aquí llamábamos a UI:Hide(), no se ocultaba nada en combate.
local function HideUI(self)
    if self and self.UI and self.UI.HideAll then
        self.UI:HideAll()
    end
end

-------------------------------------------------
-- Update
-------------------------------------------------
function BuffTracker:RequestUpdate(force)
    local now = GetTime()
    self._nextAllowed = self._nextAllowed or 0

    if not force and now < self._nextAllowed then
        return
    end

    self._nextAllowed = now + UPDATE_THROTTLE_SEC

    UpdateChallengeState(self)

    if self._inCombat or self._inChallengeMode then
        CancelReadyCheckTimer(self)
        HideUI(self)
        return
    end

    local vm = self.Engine:BuildViewModel(self, force)
    self.UI:Render(self, vm)
end

function BuffTracker:Update()
    if not self.db or self.db.enabled == false then
        HideUI(self)
        return
    end
    self:RequestUpdate(true)
end

-------------------------------------------------
-- Init
-------------------------------------------------
function BuffTracker:OnInit()
    self.db      = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = (self.db.enabled ~= false)

    EnsureDeps(self)
    self.UI:Ensure(self)

    local root = self.UI:GetRootFrame()
    if root then
        BS.Movers:Register(root, self.name, "Buff Tracker")
    end

    -- State
    self._inCombat        = InCombatLockdown()
    self._inChallengeMode = IsMythicPlusActive() and true or false
    self._inReadyCheck    = false
    self._readyCheckTimer = nil
    self._talentTimer     = nil

    -- Events
    Events:RegisterEvent("PLAYER_ENTERING_WORLD")
    Events:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    Events:RegisterEvent("CHALLENGE_MODE_START")
    Events:RegisterEvent("CHALLENGE_MODE_RESET")
    Events:RegisterEvent("CHALLENGE_MODE_COMPLETED")
    Events:RegisterEvent("GROUP_ROSTER_UPDATE")
    Events:RegisterEvent("UNIT_AURA")
    Events:RegisterEvent("PLAYER_REGEN_ENABLED")
    Events:RegisterEvent("PLAYER_REGEN_DISABLED")
    Events:RegisterEvent("READY_CHECK")
    Events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    Events:RegisterEvent("TRAIT_CONFIG_UPDATED")
    Events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

    self:Update()
end

function BuffTracker:OnDisabled()
    -- Refresh DB and force disabled
    self.db = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = false
    if self.db then self.db.enabled = false end

    -- Cancel timers
    if self._readyCheckTimer then
        self._readyCheckTimer:Cancel()
        self._readyCheckTimer = nil
    end
    if self._talentTimer then
        self._talentTimer:Cancel()
        self._talentTimer = nil
    end

    -- Reset runtime state
    self._inCombat        = false
    self._inChallengeMode = false
    self._inReadyCheck    = false

    -- Unregister all events registered in OnInit
    if Events and Events.UnregisterEvent then
        Events:UnregisterEvent("PLAYER_ENTERING_WORLD")
        Events:UnregisterEvent("ZONE_CHANGED_NEW_AREA")
        Events:UnregisterEvent("CHALLENGE_MODE_START")
        Events:UnregisterEvent("CHALLENGE_MODE_RESET")
        Events:UnregisterEvent("CHALLENGE_MODE_COMPLETED")
        Events:UnregisterEvent("GROUP_ROSTER_UPDATE")
        Events:UnregisterEvent("UNIT_AURA")
        Events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Events:UnregisterEvent("PLAYER_REGEN_DISABLED")
        Events:UnregisterEvent("READY_CHECK")
        Events:UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        Events:UnregisterEvent("TRAIT_CONFIG_UPDATED")
        Events:UnregisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
    elseif Events and Events.UnregisterAllEventsFor then
        -- Preferred if your Events wrapper is module-scoped
        Events:UnregisterAllEventsFor(self)
    end

    -- Hide UI
    if self.UI and self.UI.GetRootFrame then
        local root = self.UI:GetRootFrame()
        if root then
            root:Hide()

            -- Optional mover cleanup (only if expected on disable)
            if BS and BS.Movers and BS.Movers.Unregister then
                BS.Movers:Unregister(root, self.name)
            end
        end
    end
end

-------------------------------------------------
-- Events
-------------------------------------------------
BuffTracker.events.PLAYER_ENTERING_WORLD = function(self)
    self._inCombat = InCombatLockdown()
    self:RequestUpdate(true)
end

BuffTracker.events.ZONE_CHANGED_NEW_AREA = function(self)
    UpdateChallengeState(self)
    self:RequestUpdate(true)
end

BuffTracker.events.CHALLENGE_MODE_START = function(self)
    UpdateChallengeState(self)
    CancelReadyCheckTimer(self)
    HideUI(self)
end

BuffTracker.events.CHALLENGE_MODE_RESET = function(self)
    UpdateChallengeState(self)
    self:RequestUpdate(true)
end

BuffTracker.events.CHALLENGE_MODE_COMPLETED = function(self)
    UpdateChallengeState(self)
    self:RequestUpdate(true)
end

BuffTracker.events.GROUP_ROSTER_UPDATE = function(self)
    self:RequestUpdate(true)
end

BuffTracker.events.UNIT_AURA = function(self, unit)
    if unit ~= "player" then return end
    self:RequestUpdate(false)
end

BuffTracker.events.PLAYER_REGEN_DISABLED = function(self)
    self._inCombat = true
    CancelReadyCheckTimer(self)
    HideUI(self)
end

BuffTracker.events.PLAYER_REGEN_ENABLED = function(self)
    self._inCombat = false
    self:RequestUpdate(true)
end

BuffTracker.events.READY_CHECK = function(self)
    CancelReadyCheckTimer(self)

    self._inReadyCheck = true
    self:RequestUpdate(true)

    self._readyCheckTimer = C_Timer.NewTimer(READY_CHECK_DURATION, function()
        self._inReadyCheck = false
        self._readyCheckTimer = nil
        self:RequestUpdate(true)
    end)
end

BuffTracker.events.PLAYER_SPECIALIZATION_CHANGED = ScheduleTalentRefresh
BuffTracker.events.TRAIT_CONFIG_UPDATED          = ScheduleTalentRefresh
BuffTracker.events.ACTIVE_TALENT_GROUP_CHANGED   = ScheduleTalentRefresh
