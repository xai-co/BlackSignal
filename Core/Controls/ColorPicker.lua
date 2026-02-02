local _, BS = ...;
BS.ColorPicker = {};

local ColorPicker = BS.ColorPicker;

local function DebugColor(r,g,b,a, tag)
  print(tag or "COLOR", "r", r, "g", g, "b", b, "a", a)
end


local function showPopup(r, g, b, a, callback)
    -- Normalize inputs (avoid nil / strings)
    r = tonumber(r) or 1
    g = tonumber(g) or 1
    b = tonumber(b) or 1
    a = tonumber(a) or 1

    -- WoW usa "opacity" (0..1) para el slider: 0 = opaco, 1 = transparente
    -- Nosotros trabajamos con alpha (0..1): 0 = transparente, 1 = opaco
    local lastOpacity = 1 - a

    local function Fire(nr, ng, nb, na)
        if callback then callback(nr, ng, nb, na) end
    end

    local function GetPickedRGBA()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()

        -- Retail moderno: si existe, alpha directo (0..1)
        if ColorPickerFrame.GetColorAlpha then
            local na = ColorPickerFrame:GetColorAlpha()
            return nr, ng, nb, na
        end

        -- Si no hay GetColorAlpha, usamos opacity
        local opacity = lastOpacity

        -- Algunos layouts guardan opacity aquí
        if ColorPickerFrame.opacity ~= nil then
            local v = tonumber(ColorPickerFrame.opacity)
            if v ~= nil then opacity = v end
        end

        -- Fallback Classic
        if OpacitySliderFrame and OpacitySliderFrame.GetValue then
            local v = tonumber(OpacitySliderFrame:GetValue())
            if v ~= nil then opacity = v end
        end

        local na = 1 - (tonumber(opacity) or 0)
        return nr, ng, nb, na
    end

    local function OnChanged(...)
        -- Retail: opacityFunc(opacity) suele pasar un número 0..1
        local o = tonumber(...)
        if o ~= nil then
            lastOpacity = o
        end
        Fire(GetPickedRGBA())
    end

    local function OnCancel(prev)
        if prev then
            local na = 1 - (prev.opacity or 0)
            Fire(prev.r, prev.g, prev.b, na)
        else
            Fire(r, g, b, a)
        end
    end

    -- Retail / mainline
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = Clamp and Clamp(lastOpacity, 0, 1) or math.max(0, math.min(1, lastOpacity)),
            hasOpacity = true,

            swatchFunc  = OnChanged,
            opacityFunc = OnChanged,
            cancelFunc  = OnCancel,
        })
        return
    end

    -- Classic fallback
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - a  -- <-- IMPORTANT: opacity, no alpha
    lastOpacity = ColorPickerFrame.opacity

    ColorPickerFrame.func = OnChanged
    ColorPickerFrame.opacityFunc = OnChanged
    ColorPickerFrame.cancelFunc = function() OnCancel(nil) end
    ColorPickerFrame:Show()
end




function ColorPicker:Create(parent, w, h, point, relativeTo, relativePoint, x, y, getFunc, setFunc, tooltipText)
    local cp = CreateFrame("Button", nil, parent, "BackdropTemplate")

    -- Defaults
    w, h = w or 26, h or 26
    point = point or "TOPLEFT"
    relativeTo = relativeTo or parent
    relativePoint = relativePoint or "TOPLEFT"
    x, y = x or 0, y or 0

    cp:SetSize(w, h)
    cp:SetPoint(point, relativeTo, relativePoint, x, y)

    cp:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile     = false,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    cp:SetBackdropBorderColor(unpack(BS.Colors.ColorPicker.border))

    local function SafeGet()
        if not getFunc then return 1, 1, 1, 1 end
        local r, g, b, a = getFunc()
        return r or 1, g or 1, b or 1, a or 1
    end

    function cp:Refresh()
        local r, g, b, a = SafeGet()
        self:SetBackdropColor(r, g, b, 1)
        self.__alpha = a
    end

    cp:SetScript("OnClick", function(self)
        local r, g, b, a = SafeGet()
        showPopup(r, g, b, a, function(nr, ng, nb, na)
            if setFunc then setFunc(nr, ng, nb, na) end
            self:Refresh()
        end)
    end)

    if tooltipText and tooltipText ~= "" then
        cp:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        cp:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    cp:Refresh()
    return cp
end
