-- Modules/MouseRing.lua
local BS = _G.BS
if not BS then return end

local DB = BS.DB

local MouseRing = {
  name = "MouseRing",
  enabled = true,
  events = {},
}

BS:RegisterModule(MouseRing)

-------------------------------------------------
-- Defaults (para que Core/Config lo “entienda”)
-------------------------------------------------
function MouseRing:BuildDefaults()
  return {
    enabled = true,

    -- No se usan para posicionar va al cursor, pero por si acaso lo declaro
    x = 0,
    y = 0,

    -- Mouse ring settings
    ringEnabled   = true,
    ringSize      = 48,
    ringAlpha     = 0.9,
    ringColorR    = 0,
    ringColorG    = 1,
    ringColorB    = 0,
    ringThickness = 20, -- 10/20/30/40 (px)
    --Para añadir el colorPicker en el panel de configuración
    colorPicker = true,
  }
end

local function GetRingTexturePath(mdb)
  local thickness = tonumber(mdb.ringThickness) or 20
  if thickness ~= 10 and thickness ~= 20 and thickness ~= 30 and thickness ~= 40 then
    thickness = 20
  end

  return string.format("Interface\\AddOns\\BlackSignal\\Media\\Ring_%dpx.tga", thickness)
end

function MouseRing:ApplySettings()
  if not self.frame or not self.texture or not self.db then return end

  local mdb = self.db

  local size  = tonumber(mdb.ringSize) or 48
  local alpha = tonumber(mdb.ringAlpha) or 1

  if size < 12 then size = 12 end
  if size > 256 then size = 256 end
  if alpha < 0 then alpha = 0 end
  if alpha > 1 then alpha = 1 end

  local r = tonumber(mdb.ringColorR); if r == nil then r = 0 end
  local g = tonumber(mdb.ringColorG); if g == nil then g = 1 end
  local b = tonumber(mdb.ringColorB); if b == nil then b = 0 end

  if r < 0 then r = 0 elseif r > 1 then r = 1 end
  if g < 0 then g = 0 elseif g > 1 then g = 1 end
  if b < 0 then b = 0 elseif b > 1 then b = 1 end

  self.frame:SetSize(size, size)
  self.texture:SetTexture(GetRingTexturePath(mdb))
  self.texture:SetVertexColor(r, g, b, alpha)
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
  if not DB then return end

  -- DB por módulo (integración con Core/Config)
  self.db = self.db or DB:EnsureModuleDB(self.name, DB:BuildDefaults(self))
  self.enabled = (self.db.enabled ~= false)

  if self.__initialized and self.frame then
    -- Reload / reinit seguro
    self:Update()
    return
  end
  self.__initialized = true

  local ring = CreateFrame("Frame", "BS_MouseRing", UIParent)
  ring:SetFrameStrata("TOOLTIP")
  ring:Hide()

  local tex = ring:CreateTexture(nil, "OVERLAY")
  tex:SetAllPoints()
  tex:SetBlendMode("ADD")

  self.frame = ring
  self.texture = tex

  -- Seguir cursor (mientras está visible)
  ring:SetScript("OnUpdate", function()
    if not ring:IsShown() then return end

    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()

    -- Offset opcional usando db.x/db.y (por si quieres)
    local ox = tonumber(self.db.x) or 0
    local oy = tonumber(self.db.y) or 0

    ring:ClearAllPoints()
    ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", (x / scale) + ox, (y / scale) + oy)
  end)

  -- Ticker ligero para show/hide y settings
  self.ticker = C_Timer.NewTicker(0.10, function()
    self:Update()
  end)

  self:ApplySettings()
  self:Update()
end

function MouseRing:GetCustomOptions(f, lastAnchor, ApplyModuleExtra)
    local UI = BS.UI
    local ringSizeEdit
    local ringColorPicker

    -- Ring Size
    if self.db.ringSize ~= nil then
        local lbl = UI:CreateText(
            f,
            "Ring Size:",
            "TOPLEFT",
            lastAnchor,
            "BOTTOMLEFT",
            0,
            -14,
            "GameFontHighlight"
        )

        local eb = UI:CreateEditBox(f, 70, 20, "LEFT", lbl, "RIGHT", 10, 0)
        eb:SetText(tostring(self.db.ringSize or 48))

        eb:SetScript("OnEnterPressed", function(selfBox)
            local v = tonumber(selfBox:GetText())
            if v then
                v = math.floor(v)
                if v < 12 then v = 12 end
                if v > 256 then v = 256 end
                self.db.ringSize = v
                ApplyModuleExtra(self)
            end
            selfBox:ClearFocus()
        end)

        ringSizeEdit = eb
        lastAnchor = lbl
    end

    -- Ring Color
    if self.db.ringColorR ~= nil then
        local lbl = UI:CreateText(
            f,
            "Ring Color:",
            "TOPLEFT",
            lastAnchor,
            "BOTTOMLEFT",
            0,
            -14,
            "GameFontHighlight"
        )

        ringColorPicker = UI:CreateColorPicker(
            f, 26, 26,
            "LEFT", lbl, "RIGHT", 10, 0,
            function()
                return
                    self.db.ringColorR or 0,
                    self.db.ringColorG or 1,
                    self.db.ringColorB or 0,
                    self.db.ringAlpha or 1
            end,
            function(r, g, b, a)
                self.db.ringColorR = r
                self.db.ringColorG = g
                self.db.ringColorB = b
                self.db.ringAlpha  = a
                ApplyModuleExtra(self)
            end,
            "Click para cambiar el color del Mouse Ring"
        )

        lastAnchor = lbl
    end

    -- Devuelve el último anchor para que Config continúe debajo
    return lastAnchor, {
        ringSizeEdit = ringSizeEdit,
        ringColorPicker = ringColorPicker,
    }
end
