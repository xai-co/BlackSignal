-- Modules/EnemyCastList.lua
-- Listado genérico de casteos de enemigos en combate (via Combat Log)
-- Muestra: "Spell >> Target (by Caster)"
-- No usa cooldown APIs (evita "secret values"). Solo castTime de GetSpellInfo (ms) que es seguro.

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

    width = 420,
    maxLines = 6,

    fontSize = 14,
    font = FONT,

    updateInterval = 0.05,

    -- Filtros
    onlyWhilePlayerInCombat = true,     -- si true, solo muestra cuando TU estás en combate
    onlyIfDestIsMeOrGroup = true,       -- si true, solo registra casts cuyo dest sea tú o tu grupo/raid/pet

    -- Debug
    debugAlwaysShow = false,            -- si true, muestra aunque no haya nada (útil para posicionar)
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
-- UI
-------------------------------------------------
local function EnsureUI(self)
    if self.frame and self.lines then return end

    local f = CreateFrame("Frame", "BS_EnemyCastList", UIParent)
    f:SetSize(420, 140)
    f:SetFrameStrata("LOW")
    f:Hide()

    self.frame = f
    self.lines = {}

    for i = 1, (defaults.maxLines or 6) do
        local t = f:CreateFontString(nil, "OVERLAY")
        t:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -((i - 1) * (defaults.fontSize + 2)))
        t:SetJustifyH("LEFT")
        t:SetTextColor(1, 1, 1, 1)
        t:SetText("")
        t:Hide()
        self.lines[i] = t
    end
end

local function ApplyPosition(self)
    if not self.frame or not self.db then return end
    self.frame:ClearAllPoints()
    self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or -40)
end

local function ApplySize(self)
    if not self.frame or not self.db then return end
    local w = tonumber(self.db.width) or defaults.width
    local maxLines = tonumber(self.db.maxLines) or defaults.maxLines
    if maxLines < 1 then maxLines = 1 end
    if maxLines > 20 then maxLines = 20 end

    local fs = tonumber(self.db.fontSize) or defaults.fontSize
    local lineH = fs + 2
    self.frame:SetSize(w, (maxLines * lineH))

    -- Asegura que existan suficientes líneas
    for i = 1, maxLines do
        if not self.lines[i] then
            local t = self.frame:CreateFontString(nil, "OVERLAY")
            t:SetJustifyH("LEFT")
            t:SetTextColor(1, 1, 1, 1)
            t:SetText("")
            t:Hide()
            self.lines[i] = t
        end
    end

    -- Recoloca todas las existentes
    for i = 1, #self.lines do
        local t = self.lines[i]
        if t then
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 0, -((i - 1) * lineH))
        end
    end
end

local function ApplyFont(self)
    if not self.lines or not self.db then return end
    local fontPath = self.db.font or FONT
    local fs = tonumber(self.db.fontSize) or defaults.fontSize

    for i = 1, #self.lines do
        local t = self.lines[i]
        if t then
            t:SetFont(fontPath, fs, "OUTLINE")
        end
    end
end

-------------------------------------------------
-- Helpers (group filter)
-------------------------------------------------
local function IsDestMeOrGroup(destName)
    if not destName or destName == "" then return false end

    local me = UnitName("player")
    if me and destName == me then return true end

    -- party/raid (nombres sin realm normalmente, destName suele venir igual; si viene con realm, aún así
    -- en la práctica muchas veces coincide; no lo fuerzo para no romper)
    if IsInRaid() then
        local n = GetNumGroupMembers()
        for i = 1, n do
            local unit = "raid" .. i
            local name = UnitName(unit)
            if name and destName == name then return true end
        end
    elseif IsInGroup() then
        local n = GetNumSubgroupMembers()
        for i = 1, n do
            local unit = "party" .. i
            local name = UnitName(unit)
            if name and destName == name then return true end
        end
    end

    -- pet
    local pet = UnitName("pet")
    if pet and destName == pet then return true end

    return false
end

local function SafeSpellNameAndCastTime(spellId, fallbackName)
    if spellId then
        local name, _, _, castTimeMS = GetSpellInfo(spellId)
        if name then
            return name, (castTimeMS or 0)
        end
    end
    return fallbackName or "Unknown", 0
end

-------------------------------------------------
-- State
-------------------------------------------------
function EnemyCastList:Reset()
    self.castsBySource = {}   -- [sourceGUID] = { sourceName, spellName, spellId, destName, startedAt, endsAt }
    self.castOrder = {}       -- list of sourceGUID for stable iteration
end

function EnemyCastList:RemoveCast(sourceGUID)
    if not sourceGUID then return end
    if self.castsBySource then
        self.castsBySource[sourceGUID] = nil
    end
end

function EnemyCastList:CleanupExpired(now)
    if not self.castsBySource then return end
    now = now or GetTime()

    for guid, c in pairs(self.castsBySource) do
        if not c or not c.endsAt or c.endsAt <= now then
            self.castsBySource[guid] = nil
        end
    end
end

local function SortCasts(a, b)
    -- a/b son tablas cast
    if not a or not b then return false end
    local ea = a.endsAt or 0
    local eb = b.endsAt or 0
    if ea == eb then
        return (a.startedAt or 0) > (b.startedAt or 0)
    end
    return ea < eb
end

-------------------------------------------------
-- UI Update
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

    local now = GetTime()
    self:CleanupExpired(now)

    local maxLines = tonumber(self.db.maxLines) or defaults.maxLines
    if maxLines < 1 then maxLines = 1 end
    if maxLines > 20 then maxLines = 20 end

    -- Construir lista ordenada
    local list = {}
    if self.castsBySource then
        for _, c in pairs(self.castsBySource) do
            if c then
                list[#list + 1] = c
            end
        end
    end
    table.sort(list, SortCasts)

    if #list == 0 then
        if self.db.debugAlwaysShow then
            self.frame:Show()
            for i = 1, maxLines do
                local t = self.lines[i]
                if t then
                    if i == 1 then
                        t:SetText("EnemyCastList: sin casteos")
                        t:Show()
                    else
                        t:SetText("")
                        t:Hide()
                    end
                end
            end
        else
            self.frame:Hide()
        end
        return
    end

    self.frame:Show()

    for i = 1, maxLines do
        local t = self.lines[i]
        local c = list[i]

        if t and c then
            local msg = c.spellName or "Unknown"
            if c.destName and c.destName ~= "" then
                msg = msg .. " >> " .. c.destName
            end
            if c.sourceName and c.sourceName ~= "" then
                msg = msg .. "  |cffaaaaaa(" .. c.sourceName .. ")|r"
            end

            t:SetText(msg)
            t:Show()
        elseif t then
            t:SetText("")
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
        self:Update()
    end)
end

function EnemyCastList:StopTicker()
    BS:StopTicker(self)
end

-------------------------------------------------
-- Combat log ingestion
-------------------------------------------------
local function IsHostileSource(sourceFlags)
    if not sourceFlags then return false end
    -- Hostile reaction
    if bit.band(sourceFlags, COMBATLOG_OBJECT_REACTION_HOSTILE) == 0 then
        return false
    end
    return true
end

local function HandleCastStart(self, sourceGUID, sourceName, destName, spellId, spellNameFromLog)
    if not sourceGUID or not sourceName then return end
    if not self.db or self.db.enabled == false then return end

    if self.db.onlyIfDestIsMeOrGroup then
        if not IsDestMeOrGroup(destName) then
            return
        end
    end

    local safeName, castTimeMS = SafeSpellNameAndCastTime(spellId, spellNameFromLog)
    local now = GetTime()
    local endsAt = now + ((castTimeMS or 0) / 1000)

    -- Si es instant (0ms), lo mostramos un pelín para que se vea en lista
    if endsAt <= now then
        endsAt = now + 0.75
    end

    self.castsBySource = self.castsBySource or {}
    self.castsBySource[sourceGUID] = {
        sourceGUID = sourceGUID,
        sourceName = sourceName,
        destName = destName,
        spellId = spellId,
        spellName = safeName,
        startedAt = now,
        endsAt = endsAt,
    }
end

local function HandleCastStop(self, sourceGUID, spellId)
    -- Eliminamos el cast activo del sourceGUID (si coincide o si no nos importa spellId)
    if not sourceGUID then return end
    if not self.castsBySource or not self.castsBySource[sourceGUID] then return end

    -- si viene spellId, intentamos coincidir para no borrar otro cast "nuevo"
    if spellId and self.castsBySource[sourceGUID].spellId and self.castsBySource[sourceGUID].spellId ~= spellId then
        return
    end

    self.castsBySource[sourceGUID] = nil
end

-------------------------------------------------
-- Public hooks for Config UI
-------------------------------------------------
function EnemyCastList:ApplyOptions()
    EnsureUI(self)
    ApplyPosition(self)
    ApplySize(self)
    ApplyFont(self)

    if self.enabled then
        self:StartTicker()
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
    ApplySize(self)
    ApplyFont(self)

    self:Reset()

    self.frame:SetShown(self.enabled)

    if self.enabled then
        self:StartTicker()
        self:Update()
    else
        self.frame:Hide()
        self:StopTicker()
    end

    -- Eventos
    BS:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    BS:RegisterEvent("PLAYER_REGEN_ENABLED")   -- para limpiar al salir de combate
    BS:RegisterEvent("PLAYER_REGEN_DISABLED")  -- opcional: update inmediato al entrar
end

-------------------------------------------------
-- Events (BS dispatcher)
-------------------------------------------------
EnemyCastList.events.PLAYER_REGEN_DISABLED = function(self)
    if not self.enabled then return end
    self:Update()
end

EnemyCastList.events.PLAYER_REGEN_ENABLED = function(self)
    if not self.enabled then return end
    -- limpia casts al salir de combate para evitar “fantasmas”
    self:Reset()
    self:Update()
end

EnemyCastList.events.COMBAT_LOG_EVENT_UNFILTERED = function(self)
    if not self.enabled then return end
    if not self.db or self.db.enabled == false then return end

    -- Si solo queremos cuando el player está en combate, ni procesamos
    if self.db.onlyWhilePlayerInCombat and not UnitAffectingCombat("player") then
        return
    end

    local ts, subEvent,
        hideCaster,
        sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
        destGUID, destName, destFlags, destRaidFlags,
        spellId, spellName = CombatLogGetCurrentEventInfo()

    if not subEvent then return end
    if not sourceGUID or not sourceName then return end
    if not IsHostileSource(sourceFlags) then return end

    -- Capturamos inicios y finalizaciones razonables
    if subEvent == "SPELL_CAST_START" then
        HandleCastStart(self, sourceGUID, sourceName, destName, spellId, spellName)
        -- no hacemos Update aquí (coste); el ticker refresca. Si lo quieres instantáneo:
        -- self:Update()

    elseif subEvent == "SPELL_CAST_FAILED"
        or subEvent == "SPELL_INTERRUPT"
        or subEvent == "SPELL_CAST_SUCCESS"
    then
        -- Para casts normales: SUCCESS suele llegar al final (o instant). Para channels puede variar,
        -- pero esto limpia bastante bien.
        HandleCastStop(self, sourceGUID, spellId)
        -- self:Update()
    end
end
