-- Modules/EnemyCastList.lua
-- Lista simple de casteos de enemigos visibles (nameplates), sin Combat Log.
-- Muestra: "Spell >> Target (Caster)"
-- Sin tiempos. Se mantiene mientras UnitCastingInfo/UnitChannelInfo devuelvan cast.

local BS = _G.BS
if not BS then return end

local EnemyCastList = {
    name = "EnemyCastList",
    enabled = true,
    events = {},
}

BS:RegisterModule(EnemyCastList)

-------------------------------------------------
-- Constants / Defaults
-------------------------------------------------
local FONT = "Fonts\\FRIZQT__.TTF"

local defaults = {
    enabled = true,

    x = 0,
    y = -40,

    width = 460,
    maxLines = 10,

    fontSize = 14,
    font = FONT,

    updateInterval = 0.05,

    channelHoldSeconds = 0.20,
    onlyTargetingMe = true,
    alphaTargetingMe = 1.0,
    alphaNotTargetingMe = 0.0,
    onlyWhilePlayerInCombat = true,
    onlyHostile = true,

    showChannels = true,

    debugAlwaysShow = false,
    noTargetText = "(sin target)",
}

EnemyCastList.defaults = defaults
function EnemyCastList:BuildDefaults()
    return defaults
end

-------------------------------------------------
-- DB
-------------------------------------------------
local function EnsureDB()
    _G.BlackSignal = _G.BlackSignal or {}
    local db = _G.BlackSignal

    db.profile = db.profile or {}
    db.profile.modules = db.profile.modules or {}
    db.profile.modules.EnemyCastList = db.profile.modules.EnemyCastList or {}

    local mdb = db.profile.modules.EnemyCastList
    for k, v in pairs(defaults) do
        if mdb[k] == nil then mdb[k] = v end
    end
    return mdb
end

-------------------------------------------------
-- Local event frame (avoid Core taint)
-------------------------------------------------
function EnemyCastList:EnsureEventFrame()
    if self.eventFrame then return end

    local ef = CreateFrame("Frame", "BS_EnemyCastList_EventFrame")
    ef:SetScript("OnEvent", function(_, event, ...)
        local fn = self.events and self.events[event]
        if fn then fn(self, ...) end
    end)

    self.eventFrame = ef
end

function EnemyCastList:RegisterLocalEvent(eventName)
    if not self.eventFrame then return end
    pcall(function() self.eventFrame:RegisterEvent(eventName) end)
end

function EnemyCastList:UnregisterAllLocalEvents()
    if not self.eventFrame then return end
    pcall(function() self.eventFrame:UnregisterAllEvents() end)
end

-------------------------------------------------
-- UI
-------------------------------------------------
local function EnsureUI(self)
    if self.frame and self.lines then return end

    local f = CreateFrame("Frame", "BS_EnemyCastList", UIParent)
    f:SetFrameStrata("LOW")
    f:Hide()

    self.frame = f
    self.lines = {}
    for i = 1, (defaults.maxLines or 6) do
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetJustifyH("LEFT")
        t:SetTextColor(1, 1, 1, 1)
        t:Hide()
        self.lines[i] = t
    end
end

local function ApplyPosition(self)
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or -40)
end

local function ApplySizeAndLayout(self)
    local w = tonumber(self.db.width) or defaults.width
    local maxLines = tonumber(self.db.maxLines) or defaults.maxLines
    if maxLines < 1 then maxLines = 1 end
    if maxLines > 20 then maxLines = 20 end

    local fs = tonumber(self.db.fontSize) or defaults.fontSize
    local lineH = fs + 2

    self.frame:SetSize(w, maxLines * lineH)

    -- asegura líneas suficientes
    for i = 1, maxLines do
        if not self.lines[i] then
            local t = self.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            t:SetJustifyH("LEFT")
            t:SetTextColor(1, 1, 1, 1)
            t:Hide()
            self.lines[i] = t
        end
    end

    for i = 1, #self.lines do
        local t = self.lines[i]
        if t then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((i - 1) * lineH))
        end
    end
end

local function ApplyFont(self)
    local fontPath = self.db.font or FONT
    local fs = tonumber(self.db.fontSize) or defaults.fontSize
    local fallbackFont, fallbackSize, fallbackFlags = GameFontNormal:GetFont()

    for i = 1, #self.lines do
        local t = self.lines[i]
        if t then
            local ok = pcall(function()
                t:SetFont(fontPath, fs, "OUTLINE")
            end)
            if not ok then
                t:SetFont(fallbackFont, fs or fallbackSize or 14, fallbackFlags or "OUTLINE")
            end
        end
    end
end

-------------------------------------------------
-- Color helpers (target colored by class if player; else by reaction)
-------------------------------------------------
local function HexFromRGB(r, g, b)
    r = math.floor((r or 1) * 255 + 0.5)
    g = math.floor((g or 1) * 255 + 0.5)
    b = math.floor((b or 1) * 255 + 0.5)
    return string.format("%02x%02x%02x", r, g, b)
end

local function Colorize(text, r, g, b)
    if not text then return "" end
    return "|cff" .. HexFromRGB(r, g, b) .. text .. "|r"
end

local function GetUnitFullName(unit)
    local name, _ = UnitName(unit)
    if not name then return nil end
    return name
end

local function GetColoredUnitName(unit)
    local name = GetUnitFullName(unit)
    if not name then return nil end

    -- Player: class color
    if UnitIsPlayer(unit) then
        local _, classFile = UnitClass(unit)
        local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
        if c then
            return Colorize(name, c.r, c.g, c.b)
        end
        return name
    end

    -- NPC: reaction color
    local reaction = UnitReaction(unit, "player")
    if reaction and FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction] then
        local c = FACTION_BAR_COLORS[reaction]
        return Colorize(name, c.r, c.g, c.b)
    end

    return name
end

-------------------------------------------------
-- State
-------------------------------------------------
function EnemyCastList:Reset()
    self.units = {} -- [unit] = true
    self.casts = {} -- [unit] = { spellName, casterName, targetName }
end

local function IsUnitValidHostile(self, unit)
    if not UnitExists(unit) then return false end

    if self.db.onlyHostile then
        if not UnitCanAttack("player", unit) then
            return false
        end
    end

    return true
end

local function IsTargetingPlayer(unit)
    local tu = unit .. "target"
    return UnitExists(tu) and UnitIsUnit(tu, "player")
end

local function TryGetUnitTargetName(unit, noTargetText)
    local tu = unit .. "target"
    if UnitExists(tu) then
        return GetColoredUnitName(tu) or (noTargetText or "(sin target)")
    end
    return noTargetText or "(sin target)"
end

function EnemyCastList:ReadUnitCast(unit)
    if not UnitExists(unit) then return nil end

    local now = GetTime()

    -- Casting
    local spellName, _, _, _, startMS, endMS = UnitCastingInfo(unit)
    local isChannel = false

    -- Channeling
    if not spellName and (self.db.showChannels ~= false) then
        spellName, _, _, _, startMS, endMS = UnitChannelInfo(unit)
        if spellName then isChannel = true end
    end

    if not spellName then return nil end

    local casterName = UnitName(unit) or unit
    local targetName = TryGetUnitTargetName(unit, self.db.noTargetText)

    local hold = tonumber(self.db.channelHoldSeconds)
        or tonumber(defaults.channelHoldSeconds)
        or 0.20

    return {
        unit = unit,
        casterName = casterName,
        spellName = spellName,
        targetName = targetName,
        isChannel = isChannel,

        -- ✅ estado para alpha + anti-flicker
        targetingMe = IsTargetingPlayer(unit),
        holdUntil = now + (isChannel and hold or 0), -- solo aplicamos “hold” a canalizadas
        lastSeen = now,
    }
end


function EnemyCastList:RefreshAll()
    local now = GetTime()

    for unit, _ in pairs(self.units) do
        if UnitExists(unit) and IsUnitValidHostile(self, unit) then
            local c = self:ReadUnitCast(unit)

            if c then
                -- cast “fresco”
                self.casts[unit] = c
            else
                -- si no hay info ahora, intenta mantener el último estado un poco (anti-flicker)
                local prev = self.casts[unit]
                if prev and prev.isChannel and prev.holdUntil and now < prev.holdUntil then
                    -- refresca target/alpha aunque el channel “parpadee” en API
                    prev.targetName = TryGetUnitTargetName(unit, self.db.noTargetText)
                    prev.targetingMe = IsTargetingPlayer(unit)
                    prev.lastSeen = now
                    self.casts[unit] = prev
                else
                    self.casts[unit] = nil
                end
            end
        else
            self.casts[unit] = nil
        end
    end
end


-------------------------------------------------
-- Rendering
-------------------------------------------------
function EnemyCastList:ShouldShow()
    if not self.db or self.db.enabled == false then return false end
    if self.db.onlyWhilePlayerInCombat and not UnitAffectingCombat("player") then
        return false
    end
    return true
end

function EnemyCastList:Update()
    if not self.frame or not self.lines then return end
    if not self.db or self.db.enabled == false then
        self.frame:Hide()
        return
    end

    if self:ShouldShow() ~= true then
        self.frame:Hide()
        return
    end

    local maxLines = tonumber(self.db.maxLines) or defaults.maxLines
    if maxLines < 1 then maxLines = 1 end
    if maxLines > 20 then maxLines = 20 end

    local list = {}
    for _, c in pairs(self.casts or {}) do
        if c then list[#list + 1] = c end
    end

    if #list == 0 then
        if self.db.debugAlwaysShow then
            self.frame:Show()
            local a1 = tonumber(self.db.alphaTargetingMe) or 1
            local a0 = tonumber(self.db.alphaNotTargetingMe) or 0
            local onlyMe = (self.db.onlyTargetingMe == true)

            for i = 1, maxLines do
                local t = self.lines[i]
                local c = list[i]
                if t and c then
                    local msg = (c.spellName or "Unknown") ..
                        " >> " .. (c.targetName or (self.db.noTargetText or "(sin target)"))
                    msg = msg .. "  |cffaaaaaa(" .. (c.casterName or "?") .. ")|r"
                    t:SetText(msg)

                    local showLine = (not onlyMe) or (c.targetingMe == true)

                    if t.SetAlphaFromBoolean then
                        t:SetAlphaFromBoolean(showLine, a1, a0)
                    else
                        t:SetAlpha(showLine and a1 or a0)
                    end

                    t:Show()
                elseif t then
                    t:SetText("")
                    t:SetAlpha(1)
                    t:Hide()
                end
            end
        else
            self.frame:Hide()
        end
        return
    end

    self.frame:Show()

    local a1 = tonumber(self.db.alphaTargetingMe) or 1
    local a0 = tonumber(self.db.alphaNotTargetingMe) or 0
    local onlyMe = (self.db.onlyTargetingMe == true)

    for i = 1, maxLines do
        local t = self.lines[i]
        local c = list[i]
        if t and c then
            local msg = (c.spellName or "Unknown") ..
                " >> " .. (c.targetName or (self.db.noTargetText or "(sin target)"))
            msg = msg .. "  |cffaaaaaa(" .. (c.casterName or "?") .. ")|r"
            t:SetText(msg)

            if onlyMe and t.SetAlphaFromBoolean then
                t:SetAlphaFromBoolean(c.targetingMe, a1, a0)
            else
                t:SetAlpha(c.targetingMe and a1 or a0)
            end

            t:Show()
        elseif t then
            t:SetText("")
            t:SetAlpha(1)
            t:Hide()
        end
    end
end

-------------------------------------------------
-- Ticker
-------------------------------------------------
function EnemyCastList:StartTicker()
    BS:StopTicker(self)
    local interval = tonumber(self.db and self.db.updateInterval) or defaults.updateInterval
    if interval < 0.02 then interval = 0.02 end

    BS:RegisterTicker(self, interval, function()
        self:RefreshAll()
        self:Update()
    end)
end

function EnemyCastList:StopTicker()
    BS:StopTicker(self)
end

-------------------------------------------------
-- Public hooks for Config UI
-------------------------------------------------
function EnemyCastList:ApplyOptions()
    EnsureUI(self)
    ApplyPosition(self)
    ApplySizeAndLayout(self)
    ApplyFont(self)
    BS.Movers:Apply("EnemyCastList")
    if self.enabled then
        self:StartTicker()
        self:RefreshAll()
        self:Update()
    else
        if self.frame then self.frame:Hide() end
        self:StopTicker()
    end
end

-------------------------------------------------
-- Init
-------------------------------------------------
function EnemyCastList:OnInit()
    self.db = EnsureDB()
    self.enabled = (self.db.enabled ~= false)

    EnsureUI(self)
    ApplyPosition(self)
    ApplySizeAndLayout(self)
    ApplyFont(self)

    BS.Movers:Register(self.frame, self.name, "Enemy Cast List")
    self:Reset()

    self.frame:SetShown(self.enabled)

    if self.enabled then
        self:StartTicker()
        self:RefreshAll()
        self:Update()
    else
        self.frame:Hide()
        self:StopTicker()
    end

    self:EnsureEventFrame()
    self:UnregisterAllLocalEvents()

    self:RegisterLocalEvent("NAME_PLATE_UNIT_ADDED")
    self:RegisterLocalEvent("NAME_PLATE_UNIT_REMOVED")
end

-------------------------------------------------
-- Events
-------------------------------------------------
EnemyCastList.events.NAME_PLATE_UNIT_ADDED = function(self, unit)
    if not self.enabled then return end
    if not unit then return end
    if not IsUnitValidHostile(self, unit) then return end

    self.units[unit] = true

    local c = self:ReadUnitCast(unit)
    if c then self.casts[unit] = c end

    self:Update()
end

EnemyCastList.events.NAME_PLATE_UNIT_REMOVED = function(self, unit)
    if not self.enabled then return end
    if not unit then return end

    self.units[unit] = nil
    self.casts[unit] = nil

    self:Update()
end
