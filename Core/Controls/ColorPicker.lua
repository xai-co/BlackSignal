local _, BS = ...;
BS.ColorPicker = {};

local ColorPicker = BS.ColorPicker;

local function Clamp01(v)
    v = tonumber(v) or 0
    if v < 0 then return 0 end
    if v > 1 then return 1 end
    return v
end

local function showPopup(r, g, b, a, callback)
    -- Normalize inputs (avoid nil / strings)
    r = Clamp01(r)
    g = Clamp01(g)
    b = Clamp01(b)
    a = Clamp01(a)

    local function Fire(nr, ng, nb, na)
        if callback then callback(Clamp01(nr), Clamp01(ng), Clamp01(nb), Clamp01(na)) end
    end

    local function GetOpacityValue()
        -- Retail: opacity slider is often nested, not global
        local s =
            (ColorPickerFrame and ColorPickerFrame.Content and ColorPickerFrame.Content.OpacitySlider)
            or (ColorPickerFrame and ColorPickerFrame.opacitySlider)
            or (ColorPickerFrame and ColorPickerFrame.OpacitySliderFrame)
            or OpacitySliderFrame

        if s and s.GetValue then
            local v = tonumber(s:GetValue())
            -- Some variants use 0..100
            if v and v > 1 then v = v / 100 end
            return v
        end

        -- Fallback to stored frame opacity
        return tonumber(ColorPickerFrame and ColorPickerFrame.opacity)
    end

    local function GetPickedRGBA()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        nr, ng, nb = Clamp01(nr), Clamp01(ng), Clamp01(nb)

        -- Prefer API alpha when it exists and is initialized
        if ColorPickerFrame.GetColorAlpha then
            local na = tonumber(ColorPickerFrame:GetColorAlpha())
            if na and na > 0 then
                return nr, ng, nb, Clamp01(na)
            end
        end

        local opacity = GetOpacityValue()
        if opacity == nil then
            -- UI not ready yet: use cached initial alpha
            local initA = ColorPickerFrame and ColorPickerFrame._bsInitAlpha
            return nr, ng, nb, Clamp01(initA or 1)
        end

        opacity = Clamp01(opacity)
        local na = 1 - opacity
        return nr, ng, nb, Clamp01(na)
    end

    local function OnChanged()
        Fire(GetPickedRGBA())
    end

    local function OnCancel(prev)
        if prev then
            -- prev.opacity is "opacity" (0..1), not alpha
            local na = 1 - Clamp01(prev.opacity or 0)
            Fire(prev.r, prev.g, prev.b, na)
        else
            Fire(r, g, b, a)
        end
    end

    -- Cache initial alpha so the first read doesn't default to 0
    if ColorPickerFrame then
        ColorPickerFrame._bsInitAlpha = a
    end

    -- Retail API
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r = r,
            g = g,
            b = b,
            opacity = 1 - a,     -- opacity 0..1 (1 = transparent)
            hasOpacity = true,

            swatchFunc  = OnChanged,
            opacityFunc = OnChanged,
            cancelFunc  = OnCancel,
        })

        -- Some builds support setting alpha explicitly after setup
        if ColorPickerFrame.SetColorAlpha then
            ColorPickerFrame:SetColorAlpha(a)
        end

        return
    end

    -- Classic fallback
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - a

    -- Ensure slider reflects current opacity (if present)
    local s = OpacitySliderFrame
    if s and s.SetValue then
        s:SetValue(ColorPickerFrame.opacity or 0)
    end

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
        return Clamp01(r or 1), Clamp01(g or 1), Clamp01(b or 1), Clamp01(a or 1)
    end

    function cp:Refresh()
        local r, g, b, a = SafeGet()
        -- Paint alpha too
        self:SetBackdropColor(r, g, b, a)
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
