-- Core/UI.lua
-- UI helpers + reusable styles
local _, BS = ...;
BS.UI = {}


local UI = BS.UI

-------------------------------------------------
-- Basic creators
-------------------------------------------------
function UI:CreateText(parent, text, point, rel, relPoint, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint(point, rel, relPoint, x, y)
    fs:SetText(text or "")
    return fs
end

function UI:CreateButton(parent, text, w, h, point, rel, relPoint, x, y, styleOpts)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetPoint(point, rel, relPoint, x, y)
    btn:SetText(text or "")

    for _, region in ipairs({ btn:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetTexture(nil)
        end
    end

    if self.ApplyNavButtonStyle then
        self:ApplyNavButtonStyle(btn, styleOpts)
    end

    return btn
end

function UI:CreateEditBox(parent, w, h, point, rel, relPoint, x, y, styleOpts)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, h)
    eb:SetPoint(point, rel, relPoint, x, y)
    eb:SetAutoFocus(false)

    if self.ApplyEditBoxStyle then
        self:ApplyEditBoxStyle(eb, styleOpts)
    end

    return eb
end

function UI:CreateCheck(parent, label, point, rel, relPoint, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint(point, rel, relPoint, x, y)
    cb.text:SetText(label)
    return cb
end

function UI:ShowColorPicker(r, g, b, a, callback)
    r = tonumber(r) or 1
    g = tonumber(g) or 1
    b = tonumber(b) or 1
    a = tonumber(a) or 1

    local function fire(newR, newG, newB, newA)
        if callback then callback(newR, newG, newB, newA) end
    end

    -- Retail API moderno
    if ColorPickerFrame and ColorPickerFrame.SetupColorPickerAndShow then
        local info = {
            r = r,
            g = g,
            b = b,
            opacity = 1 - a,
            hasOpacity = true,
            swatchFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
                fire(nr, ng, nb, na)
            end,
            opacityFunc = function()
                local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
                fire(nr, ng, nb, na)
            end,
            cancelFunc = function(prev)
                if prev then
                    local na = 1 - (prev.opacity or 0)
                    fire(prev.r, prev.g, prev.b, na)
                else
                    fire(r, g, b, a)
                end
            end,
        }
        ColorPickerFrame:SetupColorPickerAndShow(info)
        return
    end

    -- Fallback clásico
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - a

    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = 1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0)
        fire(nr, ng, nb, na)
    end
    ColorPickerFrame.opacityFunc = ColorPickerFrame.func
    ColorPickerFrame.cancelFunc = function()
        fire(r, g, b, a)
    end

    ColorPickerFrame:Show()
end

function UI:CreateDropdown(parent, w, h, point, rel, relPoint, x, y, items, getFunc, setFunc, tooltipText, styleOpts)
    items = items or {}
    styleOpts = styleOpts or {}

    local GRAY = 0.16
    local ebBgA = styleOpts.bgA or 0.85
    local openA = styleOpts.focusA or 1

    -- Holder
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(w, h)
    holder:SetPoint(point, rel, relPoint, x, y)

    -- Display (EditBox look)
    local eb = CreateFrame("EditBox", nil, holder, "InputBoxTemplate")
    eb:SetAllPoints(holder)
    eb:SetAutoFocus(false)
    eb:EnableKeyboard(false)
    eb:EnableMouse(true)
    eb:SetTextInsets(8, 22, 4, 4)

    if self.ApplyEditBoxStyle then
        self:ApplyEditBoxStyle(eb, styleOpts)
    end

    -- Arrow texture: ArrowUp.tga (default rotated down; open -> up)
    local ARROW_TEX = "Interface\\AddOns\\BlackSignal\\Media\\ArrowUp.tga"
    local arrowTex = eb:CreateTexture(nil, "OVERLAY")
    arrowTex:SetSize(12, 12)
    arrowTex:SetPoint("RIGHT", eb, "RIGHT", -8, 0)
    arrowTex:SetTexture(ARROW_TEX)
    arrowTex:SetRotation(math.pi) -- down by default

    -- Fallback ASCII if texture missing
    if not arrowTex:GetTexture() then
        arrowTex:Hide()
        local arrow = eb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        arrow:SetPoint("RIGHT", eb, "RIGHT", -8, 0)
        arrow:SetTextColor(1, 1, 1, 1)
        arrow:SetText("v")
        holder._arrowFS = arrow
    end

    -- Menu
    local menu = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    menu:Hide()
    menu:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 0, -2)
    menu:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", 0, -2)

    -- Menu background like EditBox (gray)
    if menu.SetBackdrop then
        menu:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        menu:SetBackdropColor(GRAY, GRAY, GRAY, ebBgA)
        menu:SetBackdropBorderColor(0, 0, 0, 1)
    elseif self.ApplyPanelStyle then
        self:ApplyPanelStyle(menu, ebBgA, 1)
    end

    -- Click-out overlay (only while open)
    local overlay = CreateFrame("Frame", nil, UIParent)
    overlay:Hide()
    overlay:EnableMouse(true)
    overlay:SetAllPoints(UIParent)

    local buttons = {}
    local rowH = 22

    local function Refresh()
        local current = getFunc and getFunc() or nil
        local text = ""

        for _, it in ipairs(items) do
            if it[1] == current then
                text = it[2] or tostring(it[1])
                break
            end
        end
        if text == "" and current ~= nil then text = tostring(current) end
        eb:SetText(text)

        -- highlight selected if supported
        for _, b in ipairs(buttons) do
            if b.SetBSActive then
                b:SetBSActive(b._value == current)
            end
        end
    end

    local function CloseMenu()
        menu:Hide()
        overlay:Hide()
        holder._open = false

        -- arrow down
        if arrowTex and arrowTex.SetRotation then
            arrowTex:SetRotation(math.pi)
        elseif holder._arrowFS then
            holder._arrowFS:SetText("v")
        end

        -- restore editbox bg
        if eb._bs and eb._bs.bgTex then
            eb._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, ebBgA)
        end
    end

    local function OpenMenu()
        if holder._open then return end

        -- Put menu above config panels
        menu:SetFrameStrata("DIALOG")
        menu:SetFrameLevel((holder:GetFrameLevel() or 0) + 50)

        -- Overlay under menu so buttons still clickable
        overlay:SetFrameStrata(menu:GetFrameStrata())
        overlay:SetFrameLevel(menu:GetFrameLevel() - 1)
        overlay:Show()

        -- arrow up
        if arrowTex and arrowTex.SetRotation then
            arrowTex:SetRotation(0)
        elseif holder._arrowFS then
            holder._arrowFS:SetText("^")
        end

        -- focus bg
        if eb._bs and eb._bs.bgTex then
            eb._bs.bgTex:SetColorTexture(0, 0, 0, openA)
        end

        menu:Show()
        holder._open = true
        Refresh()
    end

    local function ToggleMenu()
        if holder._open then CloseMenu() else OpenMenu() end
    end

    overlay:SetScript("OnMouseDown", CloseMenu)

    local function RebuildMenu()
        for _, b in ipairs(buttons) do
            b:Hide()
            b:SetParent(nil)
        end
        wipe(buttons)

        local totalH = 0

        for i, it in ipairs(items) do
            local value, label = it[1], it[2]

            local b = CreateFrame("Button", nil, menu, "UIPanelButtonTemplate")
            b:SetSize(w - 2, rowH)
            b:SetText(label or tostring(value))
            b._value = value

            if UI.ApplyNavButtonStyle then
                UI:ApplyNavButtonStyle(b, {
                    bgA = 0.35,
                    hoverA = 0.55,
                    activeA = 0.75,
                    borderA = 1,
                    edgeSize = 1,
                    paddingX = 10,
                })
            end

            -- ensure above overlay
            b:SetFrameLevel(menu:GetFrameLevel() + i)

            if i == 1 then
                b:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -1)
                b:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -1)
            else
                b:SetPoint("TOPLEFT", buttons[i-1], "BOTTOMLEFT", 0, -1)
                b:SetPoint("TOPRIGHT", buttons[i-1], "BOTTOMRIGHT", 0, -1)
            end

            b:SetScript("OnClick", function()
                if setFunc then setFunc(value) end
                Refresh()
                CloseMenu()
            end)

            buttons[i] = b
            totalH = totalH + rowH + 1
        end

        menu:SetHeight(math.max(1, totalH + 2))
        Refresh()
    end

    -- Tooltip
    if tooltipText then
        holder:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        holder:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Click to toggle
    eb:SetScript("OnMouseDown", ToggleMenu)

    -- Avoid stuck open
    holder:HookScript("OnHide", CloseMenu)

    -- Public API
    holder.SetItems = function(self, newItems)
        items = newItems or {}
        RebuildMenu()
    end
    holder.Refresh = Refresh
    holder.CloseMenu = CloseMenu
    holder.OpenMenu = OpenMenu
    holder.EditBox = eb
    holder.Menu = menu

    -- Init
    RebuildMenu()
    Refresh()

    return holder
end

-------------------------------------------------
-- Panel style
-------------------------------------------------
function UI:ApplyPanelStyle(frame, bgAlpha, borderSize)
    local edge = borderSize or 1

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = edge,
        insets = { left = edge, right = edge, top = edge, bottom = edge },
    })

    frame:SetBackdropColor(0, 0, 0, bgAlpha or 0.85)
    frame:SetBackdropBorderColor(0, 0, 0, 1)
end

-------------------------------------------------
-- Left-list button style (BackdropTemplate)
-------------------------------------------------
function UI:ApplyNavButtonStyle(btn, opts)
    opts           = opts or {}
    local bgA      = opts.bgA or 1
    local hoverA   = opts.hoverA or 0.55
    local activeA  = opts.activeA or 0.75
    local borderA  = opts.borderA or 1
    local edgeSize = opts.edgeSize or 1
    local paddingX = opts.paddingX or 10
    local GRAY     = 0.16

    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetDisabledFontObject("GameFontDisableSmall")

    -- Kill UIPanelButtonTemplate textures (Left/Middle/Right etc.)
    if btn.Left then btn.Left:Hide() end
    if btn.Middle then btn.Middle:Hide() end
    if btn.Right then btn.Right:Hide() end
    for _, region in ipairs({ btn:GetRegions() }) do
        if region and region:IsObjectType("Texture") then
            region:SetTexture(nil)
        end
    end

    -- -------------------------
    -- Background (texture-based)
    -- -------------------------
    btn._bs = btn._bs or {}

    if not btn._bs.bgTex then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        btn._bs.bgTex = bg
    end
    btn._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, bgA)

    -- -------------------------
    -- Border (4 textures)
    -- -------------------------
    if not btn._bs.border then
        local b = {}
        b.top = btn:CreateTexture(nil, "BORDER")
        b.bottom = btn:CreateTexture(nil, "BORDER")
        b.left = btn:CreateTexture(nil, "BORDER")
        b.right = btn:CreateTexture(nil, "BORDER")

        btn._bs.border = b
    end

    local b = btn._bs.border
    local es = edgeSize

    b.top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    b.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    b.top:SetHeight(es)

    b.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    b.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    b.bottom:SetHeight(es)

    b.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    b.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    b.left:SetWidth(es)

    b.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    b.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    b.right:SetWidth(es)

    for _, t in pairs(b) do
        t:SetColorTexture(0, 0, 0, borderA)
        t:Show()
    end

    -- Text alignment / padding
    local fs = btn:GetFontString()
    if fs then
        fs:SetJustifyH("LEFT")
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", btn, "LEFT", paddingX, 0)
        fs:SetTextColor(1, 1, 1, 1)
    end

    btn._bs.bgA = bgA
    btn._bs.hoverA = hoverA
    btn._bs.activeA = activeA

    btn:SetScript("OnEnter", function(self)
        if not self._bsActive then
            self._bs.bgTex:SetColorTexture(0, 0, 0, self._bs.hoverA)
        end
    end)

    btn:SetScript("OnLeave", function(self)
        if not self._bsActive then
            self._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, self._bs.bgA)
        end
    end)

    function btn:SetBSActive(active)
        self._bsActive = active and true or false
        if self._bsActive then
            self._bs.bgTex:SetColorTexture(0, 0, 0, self._bs.activeA)
        else
            self._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, self._bs.bgA)
        end
    end
end

function UI:ApplyEditBoxStyle(eb, opts)
    opts               = opts or {}

    local bgA          = opts.bgA or 0.85
    local focusA       = opts.focusA or 1
    local borderA      = opts.borderA or 1
    local edgeSize     = opts.edgeSize or 1
    local paddingX     = opts.paddingX or 6
    local paddingY     = opts.paddingY or 4

    local caretW       = opts.caretW or 1
    local caretA       = opts.caretA or 1

    -- Cursor X offset:
    -- OnCursorChanged's x is usually relative to the *text origin*, so add the left inset.
    -- With Blizzard default font, an extra +1 px tends to align perfectly.
    local caretXOffset = opts.caretXOffset
    if caretXOffset == nil then caretXOffset = paddingX + 1 end

    local GRAY = 0.16

    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetJustifyH("LEFT")
    eb:SetJustifyV("MIDDLE")
    eb:SetTextInsets(paddingX, paddingX, paddingY, paddingY)
    eb:SetAutoFocus(false)
    eb:EnableKeyboard(true)

    -- Kill InputBoxTemplate textures
    if eb.Left then eb.Left:Hide() end
    if eb.Middle then eb.Middle:Hide() end
    if eb.Right then eb.Right:Hide() end
    for _, region in ipairs({ eb:GetRegions() }) do
        if region and region:IsObjectType("Texture") then
            region:SetTexture(nil)
        end
    end

    eb._bs = eb._bs or {}

    -- Background
    if not eb._bs.bgTex then
        local bg = eb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(eb)
        eb._bs.bgTex = bg
    end
    eb._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, bgA)

    -- Border (4 textures)
    if not eb._bs.border then
        local b = {}
        b.top = eb:CreateTexture(nil, "BORDER")
        b.bottom = eb:CreateTexture(nil, "BORDER")
        b.left = eb:CreateTexture(nil, "BORDER")
        b.right = eb:CreateTexture(nil, "BORDER")
        eb._bs.border = b
    end

    local b = eb._bs.border
    local es = edgeSize

    b.top:ClearAllPoints()
    b.top:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
    b.top:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0)
    b.top:SetHeight(es)

    b.bottom:ClearAllPoints()
    b.bottom:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0)
    b.bottom:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
    b.bottom:SetHeight(es)

    b.left:ClearAllPoints()
    b.left:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
    b.left:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0)
    b.left:SetWidth(es)

    b.right:ClearAllPoints()
    b.right:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0)
    b.right:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
    b.right:SetWidth(es)

    for _, t in pairs(b) do
        t:SetColorTexture(0, 0, 0, borderA)
        t:Show()
    end

    -- ✅ Custom caret (more visible than native one)
    if not eb._bs.caret then
        local caret = eb:CreateTexture(nil, "OVERLAY")
        caret:SetColorTexture(1, 1, 1, caretA)
        caret:Hide()
        eb._bs.caret = caret
    end

    local function UpdateCaret(self, x, h)
        local caret = self._bs and self._bs.caret
        if not caret or not self:HasFocus() then return end

        local height = (h and h > 0) and h or (self:GetHeight() - paddingY * 2)

        -- Pixel-snap to avoid blur on odd UI scales
        local px = math.floor((x or 0) + caretXOffset + 0.5)

        caret:ClearAllPoints()
        caret:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", px, paddingY)
        caret:SetSize(caretW, height)
        caret:Show()
    end

    eb:SetScript("OnEditFocusGained", function(self)
        self._bs.bgTex:SetColorTexture(0, 0, 0, focusA)
        self._bs.caret:Show()

        -- Force immediate refresh
        local pos = self:GetCursorPosition()
        self:SetCursorPosition(pos)
    end)

    eb:SetScript("OnEditFocusLost", function(self)
        self._bs.bgTex:SetColorTexture(GRAY, GRAY, GRAY, bgA)
        self._bs.caret:Hide()
    end)

    eb:SetScript("OnCursorChanged", function(self, x, y, w, h)
        UpdateCaret(self, x, h)
    end)

    -- Also update caret when text changes without cursor event (rare, but happens)
    eb:HookScript("OnTextChanged", function(self)
        local pos = self:GetCursorPosition()
        self:SetCursorPosition(pos)
    end)
end

-------------------------------------------------
-- Minimal checkbox style (custom box + mark)
-------------------------------------------------
function UI:ApplyMinimalCheckStyle(check)
    local bg = check:GetNormalTexture()
    if bg then bg:SetTexture(nil) end

    local pushed = check:GetPushedTexture()
    if pushed then pushed:SetTexture(nil) end

    local highlight = check:GetHighlightTexture()
    if highlight then highlight:SetTexture(nil) end

    local checked = check:GetCheckedTexture()
    if checked then checked:SetTexture(nil) end

    for _, region in ipairs({ check:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetTexture(nil)
        end
    end

    local box = check._box
    if not box then
        box = CreateFrame("Frame", nil, check, "BackdropTemplate")
        box:SetSize(14, 14)
        box:SetPoint("LEFT", check, "LEFT", 0, 0)

        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        box:SetBackdropBorderColor(0, 0, 0, 1)
        box:SetBackdropColor(0.12, 0.12, 0.12, 1)

        local mark = box:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("CENTER")
        mark:SetSize(12, 12)
        mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        mark:SetVertexColor(1, 1, 1, 1)
        mark:Hide()

        check._box = box
        check._mark = mark
    end

    local text = check.Text or check.text or check:GetFontString()
    if text then
        text:SetTextColor(1, 1, 1, 1)
        text:SetJustifyH("LEFT")
        text:ClearAllPoints()
        text:SetPoint("LEFT", check._box, "RIGHT", 8, 0)
    end

    if not check._sized then
        check:SetHeight(20)
        check._sized = true
    end

    local function Sync()
        local isOn = check:GetChecked() and true or false
        check._mark:SetShown(isOn)
        if isOn then
            check._box:SetBackdropColor(0.16, 0.16, 0.16, 1)
        else
            check._box:SetBackdropColor(0.12, 0.12, 0.12, 1)
        end
    end

    check:SetScript("OnEnter", function()
        check._box:SetBackdropColor(0.18, 0.18, 0.18, 1)
    end)

    check:SetScript("OnLeave", function()
        Sync()
    end)

    check._bsSync = Sync
    Sync()
end

-------------------------------------------------
-- ColorPickerFrame
-------------------------------------------------
function UI:CreateColorPicker(parent, w, h, point, relativeTo, relativePoint, x, y, getFunc, setFunc, tooltipText)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(w or 26, h or 26)
    btn:SetPoint(point or "TOPLEFT", relativeTo or parent, relativePoint or "TOPLEFT", x or 0, y or 0)
    btn:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropBorderColor(0, 0, 0, 1)

    local function Refresh()
        local r, g, b, a = 1, 1, 1, 1
        if getFunc then
            r, g, b, a = getFunc()
        end
        btn:SetBackdropColor(r or 1, g or 1, b or 1, 1)
        btn.__alpha = a or 1
    end

    btn:SetScript("OnClick", function()
        local r, g, b, a = 1, 1, 1, 1
        if getFunc then r, g, b, a = getFunc() end

        UI:ShowColorPicker(r, g, b, a, function(nr, ng, nb, na)
            if setFunc then setFunc(nr, ng, nb, na) end
            Refresh()
        end)
    end)

    if tooltipText then
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tooltipText)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    btn.Refresh = Refresh
    Refresh()
    return btn
end

return UI
