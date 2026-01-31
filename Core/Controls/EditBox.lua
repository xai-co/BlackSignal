local _, BS = ...;
BS.EditBox = {};

local EditBox = BS.EditBox;

local function ApplyStyle(eb, opts)
    opts = opts or {}

    -- -----------------------------
    -- Options / defaults
    -- -----------------------------
    local edgeSize = (opts.edgeSize ~= nil) and opts.edgeSize or 1
    local paddingX = (opts.paddingX ~= nil) and opts.paddingX or 6
    local paddingY = (opts.paddingY ~= nil) and opts.paddingY or 4
    local caretW   = (opts.caretW   ~= nil) and opts.caretW   or 1
    local caretA   = (opts.caretA   ~= nil) and opts.caretA   or 1

    -- Cursor X offset:
    local caretXOffset = (opts.caretXOffset ~= nil) and opts.caretXOffset or (paddingX + 1)

    eb._bs = eb._bs or {}

    -- -----------------------------
    -- Internal helpers
    -- -----------------------------
    local function KillTemplateTextures()
        if eb.Left then eb.Left:Hide() end
        if eb.Middle then eb.Middle:Hide() end
        if eb.Right then eb.Right:Hide() end

        for _, region in ipairs({ eb:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
    end

    local function EnsureBackground()
        if eb._bs.bgTex then return end
        local bg = eb:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(eb)
        eb._bs.bgTex = bg
    end

    local function EnsureBorder()
        if eb._bs.border then return end
        local b = {
            top    = eb:CreateTexture(nil, "BORDER"),
            bottom = eb:CreateTexture(nil, "BORDER"),
            left   = eb:CreateTexture(nil, "BORDER"),
            right  = eb:CreateTexture(nil, "BORDER"),
        }
        eb._bs.border = b
    end

    local function LayoutBorder(color)
        local border  = eb._bs.border
        local es = edgeSize

        border.top:ClearAllPoints()
        border.top:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
        border.top:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0)
        border.top:SetHeight(es)

        border.bottom:ClearAllPoints()
        border.bottom:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0)
        border.bottom:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
        border.bottom:SetHeight(es)

        border.left:ClearAllPoints()
        border.left:SetPoint("TOPLEFT", eb, "TOPLEFT", 0, 0)
        border.left:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", 0, 0)
        border.left:SetWidth(es)

        border.right:ClearAllPoints()
        border.right:SetPoint("TOPRIGHT", eb, "TOPRIGHT", 0, 0)
        border.right:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 0, 0)
        border.right:SetWidth(es)

        for _, t in pairs(border) do
            t:SetColorTexture(unpack(color or BS.Colors.EditBox.border))
            t:Show()
        end
    end

    local function EnsureCaret()
        if eb._bs.caret then return end
        local caret = eb:CreateTexture(nil, "OVERLAY")
        caret:SetColorTexture(1, 1, 1, caretA)
        caret:Hide()
        eb._bs.caret = caret
    end

    local function PixelSnap(x)
        return math.floor((x or 0) + 0.5)
    end

    local function UpdateCaret(x, h)
        local caret = eb._bs.caret
        if not caret or not eb:HasFocus() then return end

        local height = (h and h > 0) and h or (eb:GetHeight() - paddingY * 2)
        local px = PixelSnap((x or 0) + caretXOffset)

        caret:ClearAllPoints()
        caret:SetPoint("BOTTOMLEFT", eb, "BOTTOMLEFT", px, paddingY)
        caret:SetSize(caretW, height)
        caret:Show()
    end

    local function ForceCursorRefresh()
        local pos = eb:GetCursorPosition()
        eb:SetCursorPosition(pos)
    end

    -- -----------------------------
    -- Base editbox config
    -- -----------------------------
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetTextColor(1, 1, 1, 1)
    eb:SetJustifyH("LEFT")
    eb:SetJustifyV("MIDDLE")
    eb:SetTextInsets(paddingX, paddingX, paddingY, paddingY)
    eb:SetAutoFocus(false)
    eb:EnableKeyboard(true)

    KillTemplateTextures()
    EnsureBackground()
    EnsureBorder()
    EnsureCaret()

    -- -----------------------------
    -- Visuals (idle state)
    -- -----------------------------
    eb._bs.bgTex:SetColorTexture(unpack(BS.Colors.EditBox.background))
    LayoutBorder()

    -- -----------------------------
    -- Scripts (set, don't stack)
    -- -----------------------------
    eb:SetScript("OnEditFocusGained", function()
        LayoutBorder(BS.Colors.EditBox.borderFocused)
        eb._bs.caret:SetColorTexture(1, 1, 1, caretA)
        eb._bs.caret:Show()
        ForceCursorRefresh()
    end)

    eb:SetScript("OnEditFocusLost", function()
        LayoutBorder(BS.Colors.EditBox.border)
        eb._bs.caret:Hide()
    end)

    eb:SetScript("OnCursorChanged", function(_, x, _, _, h)
        UpdateCaret(x, h)
    end)

    -- Update caret when text changes without cursor event (rare, but happens)
    if not eb._bs._caretHooked then
        eb:HookScript("OnTextChanged", function()
            ForceCursorRefresh()
        end)
        eb._bs._caretHooked = true
    end
end


function EditBox:Create(name, parent, width, height, text, point, relativeTo, relativePoint, xOfs, yOfs)
    local ed = CreateFrame("EditBox", name, parent, "InputBoxTemplate");
    ed:SetSize(width, height);
    ed:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs);
    ed:SetText(text);

    ApplyStyle(ed);

    return ed;
end