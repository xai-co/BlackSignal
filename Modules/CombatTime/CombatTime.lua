-- Modules/CombatTime.lua
-- @module CombatTime
-- @alias CombatTime
--
-- Tracks time spent in combat.
-- Shows a simple "mm:ss" timer ONLY while the player is in combat.
-- When leaving combat: hides and resets the timer to 00:00.
-- When entering combat: starts from 00:00.
-- Persists an all-time total (optional) into SavedVariables.

local _, BS      = ...;

local API        = BS.API
local Events     = BS.Events

local CombatTime = {
    name    = "BS_CT",
    label   = "Combat Timer",
    enabled = true,
    events  = {},
}

API:Register(CombatTime)

-------------------------------------------------
-- Defaults
-------------------------------------------------
local defaults = {
    enabled        = true,

    -- UI
    x              = 0,
    y              = -120,
    fontSize       = 20,
    font           = "Fonts\\FRIZQT__.TTF",

    -- Behavior
    updateInterval = 1,  -- ticker rate

    -- Persistence
    persistTotal   = true, -- store total combat time across sessions
    totalSeconds   = 0,    -- saved field (only meaningful if persistTotal = true)
}

CombatTime.defaults = defaults

-------------------------------------------------
-- State
-------------------------------------------------
CombatTime.inCombat     = false
CombatTime.combatStart  = nil
CombatTime.totalSeconds = 0

-------------------------------------------------
-- UI
-------------------------------------------------

local function CalculateHeight(self)
    if not self.textFS or not self.db then return 30 end
    local fontSize = tonumber(self.db.fontSize) or 20
    return fontSize + 10
end

local function CalculateWidth(self)
    if not self.textFS or not self.db then return 100 end
    local fontSize = tonumber(self.db.fontSize) or 20
    -- Approx width for "mm:ss" plus some padding
    return (fontSize * 4) + 20
end

local function EnsureUI(self)
    if self.frame and self.textFS then return end

    local displayFrame = CreateFrame("Frame", "BS_CombatTimeDisplay", UIParent)
    displayFrame:SetHeight(CalculateHeight(self))
    displayFrame:SetWidth(CalculateWidth(self))
    displayFrame:SetFrameStrata("LOW")
    displayFrame:Show()

    local statusText = displayFrame:CreateFontString(nil, "OVERLAY")
    statusText:SetPoint("CENTER")
    statusText:SetJustifyH("CENTER")
    statusText:SetTextColor(1, 1, 1, 1)

    self.frame  = displayFrame
    self.textFS = statusText
end

local function ApplyPosition(self)
    if not self.frame or not self.db then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or -120)
end

local function ApplyFont(self)
    if not self.textFS or not self.db then return end
    self.textFS:SetFont(self.db.font, tonumber(self.db.fontSize) or 20, "OUTLINE")
end

-------------------------------------------------
-- Formatting
-------------------------------------------------
local function FormatMMSS(seconds)
    seconds = tonumber(seconds) or 0
    if seconds < 0 then seconds = 0 end
    seconds = math.floor(seconds + 0.5)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%02d:%02d", m, s)
end

-------------------------------------------------
-- Update
-------------------------------------------------
--- Update the combat time display (only while in combat)
--- @return nil
-------------------------------------------------
function CombatTime:Update()
    if not self.db or self.db.enabled == false then return end
    if not self.frame or not self.textFS then return end

    if not self.inCombat or not self.combatStart then
        -- Out of combat: hide and show 00:00 next time
        self.textFS:SetText("00:00")
        self.frame:Hide()
        BS.Tickers:Stop(self)
        return
    end

    local now = GetTime()
    local seconds = now - self.combatStart
    if seconds < 0 then seconds = 0 end

    self.textFS:SetText(FormatMMSS(seconds))
    self.frame:Show()
end

-------------------------------------------------
-- Ticker
-------------------------------------------------
--- Start the update ticker
--- @return nil
-------------------------------------------------
function CombatTime:StartTicker()
    BS.Tickers:Stop(self)
    BS.Tickers:Register(self, tonumber(self.db.updateInterval) or defaults.updateInterval, function()
        self:Update()
    end)
end

-------------------------------------------------
-- Combat transitions
-------------------------------------------------
--- Handle entering combat (reset and start from 0)
--- @return nil
-------------------------------------------------
function CombatTime:EnterCombat()
    if self.inCombat then return end
    if not self.db or self.db.enabled == false then return end

    self.inCombat = true
    self.combatStart = GetTime()

    if self.frame then self.frame:Show() end
    self:StartTicker()
    self:Update()
end

--- Handle leaving combat (persist, reset, hide)
--- @return nil
-------------------------------------------------
function CombatTime:LeaveCombat()
    if not self.inCombat then return end

    local now = GetTime()
    local duration = 0
    if self.combatStart then
        duration = now - self.combatStart
        if duration < 0 then duration = 0 end
    end

    -- Persist total (optional)
    if self.db and self.db.persistTotal then
        self.totalSeconds = (self.totalSeconds or 0) + duration
        self.db.totalSeconds = self.totalSeconds
    end

    -- Reset combat state
    self.inCombat = false
    self.combatStart = nil

    -- Reset UI to 00:00 and hide
    if self.textFS then
        self.textFS:SetText("00:00")
    end

    BS.Tickers:Stop(self)
    if self.frame then self.frame:Hide() end
end

-------------------------------------------------
-- Init
-------------------------------------------------
function CombatTime:OnInit()
    self.db = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = (self.db.enabled ~= false)

    -- Load persistent total
    self.db.totalSeconds = tonumber(self.db.totalSeconds) or 0
    self.totalSeconds = self.db.totalSeconds

    EnsureUI(self)
    ApplyPosition(self)
    ApplyFont(self)
    BS.Movers:Register(self.frame, self.name, "Combat Time")

    if not self.enabled then
        BS.Tickers:Stop(self)
        self.frame:Hide()
        return
    end

    -- Sync state on load/reload
    if UnitAffectingCombat("player") then
        self.inCombat = true
        self.combatStart = GetTime()
        self.frame:Show()
        self:StartTicker()
        self:Update()
    else
        self.inCombat = false
        self.combatStart = nil
        self.textFS:SetText("00:00")
        self.frame:Hide()
        BS.Tickers:Stop(self)
    end

    -- We rely on regen events for accurate transitions
    Events:RegisterEvent("PLAYER_REGEN_DISABLED")
    Events:RegisterEvent("PLAYER_REGEN_ENABLED")
    Events:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function CombatTime:OnDisabled()
    -- Refresh db, force disable, persist state
    self.db = BS.DB:EnsureDB(self.name, defaults)
    self.enabled = false
    if self.db then self.db.enabled = false end

    -- Reset runtime combat state
    self.inCombat = false
    self.combatStart = nil

    -- Stop ticker / updates
    if BS.Tickers and BS.Tickers.Stop then
        BS.Tickers:Stop(self)
    elseif self.StopTicker then
        self:StopTicker()
    end

    -- Unregister events registered in OnInit
    if Events and Events.UnregisterEvent then
        Events:UnregisterEvent("PLAYER_REGEN_DISABLED")
        Events:UnregisterEvent("PLAYER_REGEN_ENABLED")
        Events:UnregisterEvent("PLAYER_ENTERING_WORLD")
    elseif Events and Events.UnregisterAllEventsFor then
        Events:UnregisterAllEventsFor(self)
    end

    -- Hide UI
    if self.textFS then
        self.textFS:SetText("00:00")
    end
    if self.frame then
        self.frame:Hide()
    end

    -- Optional mover cleanup (keep if your movers system expects it)
    if BS.Movers and BS.Movers.Unregister and self.frame then
        BS.Movers:Unregister(self.frame, self.name)
    end
end


-------------------------------------------------
-- Events
-------------------------------------------------
CombatTime.events.PLAYER_REGEN_DISABLED = function(self)
    if not self.db or self.db.enabled == false then return end
    self:EnterCombat()
end

CombatTime.events.PLAYER_REGEN_ENABLED = function(self)
    if not self.db or self.db.enabled == false then return end
    self:LeaveCombat()
end

CombatTime.events.PLAYER_ENTERING_WORLD = function(self)
    if not self.db or self.db.enabled == false then return end

    -- Safety sync on zoning/reload
    if UnitAffectingCombat("player") then
        if not self.inCombat then
            self:EnterCombat()
            return
        end
    else
        if self.inCombat then
            self:LeaveCombat()
            return
        end
    end

    self:Update()
end
