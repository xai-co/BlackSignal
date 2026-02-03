-- Modules/MouseRing.lua
-- @module MouseRing
-- @alias MouseRing

local _, BS = ...
local DB    = BS.DB
local API   = BS.API

local MouseRing = {
    name    = "BS_CR",
    label   = "Cursor Ring",
    enabled = true,
    events  = {},
}

API:Register(MouseRing)

-------------------------------------------------
-- Defaults (para que Core/Config lo “entienda”)
-------------------------------------------------
local defaults = {
    enabled     = true,

    ringEnabled = true,
    size        = 48,

    ringAlpha   = 0.9, -- 0..1

    -- 0..1
    ringColorR  = 0,
    ringColorG  = 1,
    ringColorB  = 0,

    thickness   = 20, -- 10/20/30/40 (px)

    -- Para añadir el colorPicker en el panel de configuración
    colorPicker = true,

    -- optional offsets (your code was using them but they weren't in defaults)
    x = 0,
    y = 0,
}

MouseRing.defaults = defaults

-------------------------------------------------
-- Helpers
-------------------------------------------------
local function Clamp(v, minV, maxV)
    if v < minV then return minV end
    if v > maxV then return maxV end
    return v
end

local function ToNumber(v, fallback)
    v = tonumber(v)
    if v == nil then return fallback end
    return v
end

local function Clamp01(v)
    return Clamp(v, 0, 1)
end

local function GetRingTexturePath(mdb)
    local thickness = ToNumber(mdb.thickness, 20)
    if thickness ~= 10 and thickness ~= 20 and thickness ~= 30 and thickness ~= 40 then
        thickness = 20
    end
    return string.format("Interface\\AddOns\\BlackSignal\\Media\\Ring_%dpx.tga", thickness)
end

-------------------------------------------------
-- Core
-------------------------------------------------
function MouseRing:ApplySettings()
    if not self.frame or not self.texture or not self.db then return end
    local mdb = self.db

    local size  = Clamp(ToNumber(mdb.size, 48), 12, 256)
    local alpha = Clamp01(ToNumber(mdb.ringAlpha, 1))

    local r = Clamp01(ToNumber(mdb.ringColorR, 0))
    local g = Clamp01(ToNumber(mdb.ringColorG, 1))
    local b = Clamp01(ToNumber(mdb.ringColorB, 0))

    self.frame:SetSize(size, size)

    local path = GetRingTexturePath(mdb)
    self.texture:SetTexture(path)

    -- IMPORTANT:
    -- "ADD" makes black invisible. Use "BLEND" so (0,0,0,alpha) still renders.
    -- If you *really* wanted additive glow, you'd need a non-black texture/color.
    self.texture:SetBlendMode("BLEND")

    -- Apply color + alpha predictably
    self.texture:SetVertexColor(r, g, b)
    self.texture:SetAlpha(alpha)
end

function MouseRing:Update()
    if not self.frame or not self.db then return end

    -- Respeta el toggle del Config genérico (module.db.enabled) + el propio ringEnabled
    local show = (self.db.enabled ~= false) and (self.db.ringEnabled ~= false)

    self.frame:SetShown(show)
    if show then
        self:ApplySettings()
    end
end

function MouseRing:OnInit()
    self.db = DB:EnsureDB(self.name, defaults)
    self.enabled = (self.db.enabled ~= false)

    if self.__initialized and self.frame then
        self:Update()
        return
    end
    self.__initialized = true

    local ring = CreateFrame("Frame", "BS_MouseRing", UIParent)
    ring:SetFrameStrata("TOOLTIP")
    ring:Hide()

    local tex = ring:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints()

    -- NOTE: Blend mode is set in ApplySettings()

    self.frame = ring
    self.texture = tex

    -- Follow cursor (while visible)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", UIParent, "CENTER", 0, 0)

    ring:SetScript("OnUpdate", function()
        if not ring:IsShown() then return end

        local cx, cy = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()

        local ox = ToNumber(self.db.x, 0)
        local oy = ToNumber(self.db.y, 0)

        ring:ClearAllPoints()
        ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (cx / scale) + ox, (cy / scale) + oy)
    end)

    -- Light ticker for show/hide + settings
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
    self.ticker = C_Timer.NewTicker(0.10, function()
        self:Update()
    end)

    self:ApplySettings()
    self:Update()
end


function MouseRing:OnDisabled()
    self.db = DB:EnsureDB(self.name, defaults)
    self.enabled = false
    if self.db then self.db.enabled = false end

    -- Stop ticker
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end

    -- Hide UI immediately
    if self.frame then
        self.frame:Hide()

        -- Optional: detach scripts to avoid any accidental work
        self.frame:SetScript("OnUpdate", nil)
    end
end
