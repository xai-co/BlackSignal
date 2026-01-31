-- Core/Movers.lua
local _, BS = ...;

BS.Movers       = {}
local Movers    = BS.Movers

Movers._movers  = Movers._movers  or {}  -- key -> data
Movers._holders = Movers._holders or {}  -- key -> holder
Movers._shown   = Movers._shown   or false

-------------------------------------------------
-- DB helper
-------------------------------------------------

local function GetDB()
    Movers.db = Movers.db or BS.DB:EnsureDB("Movers", {})
    return Movers.db
end

-------------------------------------------------
-- Module enabled check (key == module.name)
-------------------------------------------------
local function IsModuleEnabled(key)
    if not key or key == "" then return true end

    local m = BS and BS.API and BS.API.modules and BS.API.modules[key]
    if not m then return true end

    if m.enabled == false then return false end
    if m.db and m.db.enabled == false then return false end

    return true
end

-------------------------------------------------
-- Position helpers (safe)
-------------------------------------------------
local function ApplyHolderPosition(key, holder)
    local db = GetDB()
    local t = db and db[key]
    if type(t) ~= "table" then return false end

    local point    = type(t.point) == "string" and t.point or "CENTER"
    local relPoint = type(t.relPoint) == "string" and t.relPoint or "CENTER"
    local x        = tonumber(t.x) or 0
    local y        = tonumber(t.y) or 0

    holder:ClearAllPoints()
    holder:SetPoint(point, UIParent, relPoint, x, y)
    return true
end

local function SaveHolderPosition(key, holder)
    local db = GetDB()
    db[key] = db[key] or {}

    local point, _, relPoint, x, y = holder:GetPoint(1)
    if not point then return end

    db[key].point = point
    db[key].relPoint = relPoint
    db[key].x = x
    db[key].y = y
end

-------------------------------------------------
-- Holder
-------------------------------------------------
local function CreateHolder(key)
    local h = CreateFrame("Frame", "BS_MoverHolder_" .. key, UIParent)
    h:SetSize(10, 10)
    h:SetPoint("CENTER")
    h:SetClampedToScreen(true)
    h:SetMovable(true)
    h:EnableMouse(false)
    return h
end

-------------------------------------------------
-- Mover overlay (visual)
-------------------------------------------------
local function CreateMoverOverlay(key, label, w, h)
    local m = CreateFrame("Button", "BS_Mover_" .. key, UIParent, "BackdropTemplate")

    m:SetSize(w or 160, h or 22)
    m:SetFrameStrata("TOOLTIP")
    m:SetClampedToScreen(true)

    m:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    m:SetBackdropColor(unpack(BS.Colors.Movers.active))
    m:SetBackdropBorderColor(unpack(BS.Colors.Brand.primary))

    m:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(BS.Colors.Movers.hover))
        self:SetBackdropBorderColor(unpack(BS.Colors.Brand.primary))
    end)

    m:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(BS.Colors.Movers.active))
        self:SetBackdropBorderColor(unpack(BS.Colors.Brand.primary))
    end)

    local txt = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt:SetPoint("CENTER")
    txt:SetText(label or key)
    txt:SetTextColor(unpack(BS.Colors.Text.normal))
    m.text = txt

    m:RegisterForDrag("LeftButton")
    m:SetMovable(true)
    m:EnableMouse(true)

    return m
end

-------------------------------------------------
-- Public API
-------------------------------------------------

function Movers:Register(frame, key, label)
    if not frame or not key then return end

    -- Ya registrado → reaplica
    if self._movers[key] then
        self:Apply(key)
        return self._movers[key].mover
    end

    local holder = self._holders[key]
    if not holder then
        holder = CreateHolder(key)
        self._holders[key] = holder
    end

    local db = GetDB()

    -- Default DB entry desde posición actual del frame
    if not db[key] then
        local cx, cy = frame:GetCenter()
        local ux, uy = UIParent:GetCenter()

        local x, y = 0, 0
        if cx and ux then
            x = math.floor((cx - ux) + 0.5)
            y = math.floor((cy - uy) + 0.5)
        end

        db[key] = {
            point = "CENTER",
            relPoint = "CENTER",
            x = x,
            y = y,
        }
    end

    -- Aplica posición al holder
    ApplyHolderPosition(key, holder)

    -- Ancla frame real al holder
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", holder, "CENTER", 0, 0)

    -- Tamaño del mover = tamaño real del frame
    local w = frame:GetWidth()  or 160
    local h = frame:GetHeight() or 22

    -- Overlay
    local mover = CreateMoverOverlay(key, label or key, w, h)
    mover:SetPoint("CENTER", holder, "CENTER", 0, 0)
    mover:SetShown(self._shown)

    mover:SetScript("OnDragStart", function()
        if InCombatLockdown() then
            UIErrorsFrame:AddMessage("BlackSignal: no puedes mover en combate.", 1, 0.2, 0.2)
            return
        end
        holder:StartMoving()
    end)

    mover:SetScript("OnDragStop", function()
        holder:StopMovingOrSizing()
        SaveHolderPosition(key, holder)

        mover:ClearAllPoints()
        mover:SetPoint("CENTER", holder, "CENTER", 0, 0)

        frame:ClearAllPoints()
        frame:SetPoint("CENTER", holder, "CENTER", 0, 0)
    end)

    self._movers[key] = {
        key    = key,
        frame  = frame,
        holder = holder,
        mover  = mover,
    }

    return mover
end

function Movers:Apply(key)
    local data = self._movers[key]
    if not data then return end

    local ok = ApplyHolderPosition(key, data.holder)
    if not ok then
        data.holder:ClearAllPoints()
        data.holder:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    data.mover:ClearAllPoints()
    data.mover:SetPoint("CENTER", data.holder, "CENTER", 0, 0)

    data.frame:ClearAllPoints()
    data.frame:SetPoint("CENTER", data.holder, "CENTER", 0, 0)
end

function Movers:ApplyAll()
    for key in pairs(self._movers) do
        self:Apply(key)
    end
end

function Movers:Unlock()
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("BlackSignal: no puedes activar movers en combate.", 1, 0.2, 0.2)
        return
    end

    self._shown = true
    for key, data in pairs(self._movers) do
        if IsModuleEnabled(key) then
            data.mover:Show()
        else
            data.mover:Hide()
        end
    end
end

function Movers:Lock()
    self._shown = false
    for _, data in pairs(self._movers) do
        data.mover:Hide()
    end
end

function Movers:Toggle()
    if self._shown then self:Lock() else self:Unlock() end
end

function Movers:Reset(key)
    local db = GetDB()
    db[key] = nil
    self:Apply(key)
end

function Movers:ResetAll()
    local db = GetDB()
    wipe(db)
    self:ApplyAll()
end
