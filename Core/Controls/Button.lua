local _, BS = ...;
BS.Button = {};

local Button = BS.Button;

local function ApplyStyle(btn, opts)
    opts               = opts or {}

    -- -----------------------------
    -- Options / defaults
    -- -----------------------------
    local bgA          = opts.bgA or 1
    local hoverA       = opts.hoverA or 0.55
    local activeA      = opts.activeA or 0.75
    local edgeSize     = opts.edgeSize or 1

    local color        = opts.color or BS.Colors.Button.normal
    local colorActive  = opts.colorActive or BS.Colors.Button.active
    local normalText   = opts.normalText or BS.Colors.Text.normal
    local normalBorder = opts.normalBorder or BS.Colors.Button.borderNormal
    local hoverBorder  = opts.hoverBorder or BS.Colors.Button.borderHover

    -- -----------------------------
    -- One-time setup
    -- -----------------------------
    btn._bs            = btn._bs or {}
    local st           = btn._bs

    btn:SetNormalFontObject("GameFontHighlightSmall")
    btn:SetHighlightFontObject("GameFontHighlightSmall")
    btn:SetDisabledFontObject("GameFontDisableSmall")

    -- Strip default textures ONCE (expensive-ish / noisy)
    if not st.stripped then
        if btn.Left then btn.Left:Hide() end
        if btn.Middle then btn.Middle:Hide() end
        if btn.Right then btn.Right:Hide() end
        for _, region in ipairs({ btn:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
        st.stripped = true
    end

    -- Background texture
    if not st.bgTex then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        st.bgTex = bg
    end

    -- Border textures (top/bottom/left/right)
    if not st.border then
        local b = {
            top    = btn:CreateTexture(nil, "BORDER"),
            bottom = btn:CreateTexture(nil, "BORDER"),
            left   = btn:CreateTexture(nil, "BORDER"),
            right  = btn:CreateTexture(nil, "BORDER"),
        }
        st.border = b
    end

    -- Cache style values for callbacks / updates
    st.bgA          = bgA
    st.hoverA       = hoverA
    st.activeA      = activeA
    st.edgeSize     = edgeSize

    st.color        = color
    st.activeColor  = colorActive
    st.normalText   = normalText
    st.normalBorder = normalBorder
    st.hoverBorder  = hoverBorder

    -- -----------------------------
    -- Layout + helpers
    -- -----------------------------
    local border    = st.border
    local es        = edgeSize

    -- Re-anchor every apply (safe if size changes). If you want ultra-minimal, you can guard with st.anchored+es.
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.top:SetHeight(es)

    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(es)

    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(es)

    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(es)

    local function SetBorderRGBA(r, g, bl, a)
        border.top:SetColorTexture(r, g, bl, a); border.top:Show()
        border.bottom:SetColorTexture(r, g, bl, a); border.bottom:Show()
        border.left:SetColorTexture(r, g, bl, a); border.left:Show()
        border.right:SetColorTexture(r, g, bl, a); border.right:Show()
    end

    local function SetTextRGBA()
        local fs = btn:GetFontString()
        if not fs then return end
        fs:SetJustifyH("CENTER")
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetTextColor(unpack(st.normalText))
    end

    local function RenderState(mode)
        -- mode: "normal" | "hover" | "active"
        if mode == "active" then
            st.bgTex:SetColorTexture(0, 0, 0, st.activeA)
            SetBorderRGBA(unpack(st.normalBorder))
            SetTextRGBA()
            return
        end

        -- normal / hover share bg color (you can change this to adjust alpha if you want)
        st.bgTex:SetColorTexture(unpack(st.color))
        if mode == "hover" then
            SetBorderRGBA(unpack(st.hoverBorder))
        else
            SetBorderRGBA(unpack(st.normalBorder))
        end
        SetTextRGBA()
    end

    -- -----------------------------
    -- Initial render
    -- -----------------------------
    RenderState(st._active and "active" or "normal")

    -- -----------------------------
    -- Events (only hook once)
    -- -----------------------------
    if not st.hooked then
        btn:SetScript("OnEnter", function(self)
            local s = self._bs
            if not s or s._active then return end
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border
            local r, g, b, a = unpack(s.hoverBorder)
            bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
            bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
            bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
            bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            local s = self._bs
            if not s or s._active then return end
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border
            local r, g, b, a = unpack(s.normalBorder)
            bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
            bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
            bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
            bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
        end)

        function btn:SetActive(active)
            local s = self._bs
            if not s then return end
            s._active = active and true or false
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border

            if s._active then
                local r, g, b, a = unpack(s.hoverBorder)
                bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
                bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
                bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
                bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
            else
                local r, g, b, a = unpack(s.normalBorder)
                bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
                bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
                bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
                bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
            end
        end

        st.hooked = true
    end
end

local function ApplyNavStyle(btn, opts)
    opts               = opts or {}

    -- -----------------------------
    -- Options / defaults
    -- -----------------------------
    local bgA          = opts.bgA or 1
    local hoverA       = opts.hoverA or 0.55
    local activeA      = opts.activeA or 0.75
    local edgeSize     = opts.edgeSize or 1

    local color        = opts.color or BS.Colors.Button.navNormal
    local colorActive  = opts.colorActive or BS.Colors.Button.active
    local normalText   = opts.normalText or BS.Colors.Text.white
    local normalBorder = opts.normalBorder or BS.Colors.Button.borderNormal
    local hoverBorder  = opts.hoverBorder or BS.Colors.Button.borderHover

    -- -----------------------------
    -- One-time setup
    -- -----------------------------
    btn._bs            = btn._bs or {}
    local st           = btn._bs

    btn:SetNormalFontObject("GameFontHighlightMedium")
    btn:SetHighlightFontObject("GameFontHighlightMedium")
    btn:SetDisabledFontObject("GameFontDisableMed2")

    -- Strip default textures ONCE (expensive-ish / noisy)
    if not st.stripped then
        if btn.Left then btn.Left:Hide() end
        if btn.Middle then btn.Middle:Hide() end
        if btn.Right then btn.Right:Hide() end
        for _, region in ipairs({ btn:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
        st.stripped = true
    end

    -- Background texture
    if not st.bgTex then
        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(btn)
        st.bgTex = bg
    end

    -- Border textures (top/bottom/left/right)
    if not st.border then
        local b = {
            top    = btn:CreateTexture(nil, "BORDER"),
            bottom = btn:CreateTexture(nil, "BORDER"),
            left   = btn:CreateTexture(nil, "BORDER"),
            right  = btn:CreateTexture(nil, "BORDER"),
        }
        st.border = b
    end

    -- Cache style values for callbacks / updates
    st.bgA          = bgA
    st.hoverA       = hoverA
    st.activeA      = activeA
    st.edgeSize     = edgeSize

    st.color        = color
    st.activeColor  = colorActive
    st.normalText   = normalText
    st.normalBorder = normalBorder
    st.hoverBorder  = hoverBorder

    -- -----------------------------
    -- Layout + helpers
    -- -----------------------------
    local border    = st.border
    local es        = edgeSize

    -- Re-anchor every apply (safe if size changes). If you want ultra-minimal, you can guard with st.anchored+es.
    border.top:ClearAllPoints()
    border.top:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.top:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.top:SetHeight(es)

    border.bottom:ClearAllPoints()
    border.bottom:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.bottom:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    border.bottom:SetHeight(es)

    border.left:ClearAllPoints()
    border.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    border.left:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 0, 0)
    border.left:SetWidth(es)

    border.right:ClearAllPoints()
    border.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)
    border.right:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 0, 0)
    border.right:SetWidth(es)

    local function SetBorderRGBA(r, g, bl, a)
        border.top:SetColorTexture(r, g, bl, a); border.top:Show()
        border.bottom:SetColorTexture(r, g, bl, a); border.bottom:Show()
        border.left:SetColorTexture(r, g, bl, a); border.left:Show()
        border.right:SetColorTexture(r, g, bl, a); border.right:Show()
    end

    local function SetTextRGBA()
        local fs = btn:GetFontString()
        if not fs then return end
        fs:SetJustifyH("CENTER")
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", btn, "CENTER", 0, 0)
        fs:SetTextColor(unpack(st.normalText))
    end

    local function RenderState(mode)
        -- mode: "normal" | "hover" | "active"
        if mode == "active" then
            st.bgTex:SetColorTexture(0, 0, 0, st.activeA)
            SetBorderRGBA(unpack(st.normalBorder))
            SetTextRGBA()
            return
        end

        -- normal / hover share bg color (you can change this to adjust alpha if you want)
        st.bgTex:SetColorTexture(unpack(st.color))
        if mode == "hover" then
            SetBorderRGBA(unpack(st.hoverBorder))
        else
            SetBorderRGBA(unpack(st.normalBorder))
        end
        SetTextRGBA()
    end

    -- -----------------------------
    -- Initial render
    -- -----------------------------
    RenderState(st._active and "active" or "normal")

    -- -----------------------------
    -- Events (only hook once)
    -- -----------------------------
    if not st.hooked then
        btn:SetScript("OnEnter", function(self)
            local s = self._bs
            if not s or s._active then return end
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border
            local r, g, b, a = unpack(s.hoverBorder)
            bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
            bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
            bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
            bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
        end)

        btn:SetScript("OnLeave", function(self)
            local s = self._bs
            if not s or s._active then return end
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border
            local r, g, b, a = unpack(s.normalBorder)
            bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
            bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
            bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
            bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
        end)

        function btn:SetActive(active)
            local s = self._bs
            if not s then return end
            s._active = active and true or false
            s.bgTex:SetColorTexture(unpack(s.color))
            local bb = s.border

            if s._active then
                local r, g, b, a = unpack(s.hoverBorder)
                bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
                bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
                bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
                bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
            else
                local r, g, b, a = unpack(s.normalBorder)
                bb.top:SetColorTexture(r, g, b, a); bb.top:Show()
                bb.bottom:SetColorTexture(r, g, b, a); bb.bottom:Show()
                bb.left:SetColorTexture(r, g, b, a); bb.left:Show()
                bb.right:SetColorTexture(r, g, b, a); bb.right:Show()
            end
        end

        st.hooked = true
    end
end



-- Creates a styled button
--@param name Button name
--@param parent Parent frame
--@param width Button width
--@param height Button height
--@param text Button text
--@param point Anchor point
--@param relativeTo Relative frame
--@param relativePoint Relative point
--@param xOfs X offset
--@param yOfs Y offset
--@return Button API
function Button:Create(name, parent, width, height, text, point, relativeTo, relativePoint, xOfs, yOfs)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate");
    btn:SetSize(width, height);
    btn:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs);
    btn:SetText(text);

    ApplyStyle(btn);

    return btn;
end

function Button:CreateNav(name, parent, width, height, text, point, relativeTo, relativePoint, xOfs, yOfs)
    local btn = CreateFrame("Button", name, parent, "UIPanelButtonTemplate");
    btn:SetSize(width, height);
    btn:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs);
    btn:SetText(text);

    ApplyNavStyle(btn);

    return btn;
end
