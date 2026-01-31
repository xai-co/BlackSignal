local _, BS = ...;
BS.CheckButton = {};

local CheckButton = BS.CheckButton;

local function ApplyStyle(check, opts)
    opts = opts or {}

    local size        = opts.size or 14
    local markSize    = opts.markSize or (size - 2)
    local edgeSize    = opts.edgeSize or 1
    local gap         = opts.gap or 8

    local bgOff       = opts.bgOff or BS.Colors.CheckButton.boxBg or { 0.12, 0.12, 0.12, 1 }
    local bgOn        = opts.bgOn  or BS.Colors.CheckButton.mark or { 0.16, 0.16, 0.16, 1 }
    local border      = opts.border or BS.Colors.CheckButton.boxBorder or { 0, 0, 0, 1 }
    local markColor   = opts.markColor or BS.Colors.CheckButton.mark or { 1, 1, 1, 1 }

    local function KillTexturesOnce()
        if check._bsTexturesKilled then return end
        check._bsTexturesKilled = true

        local t = check.GetNormalTexture and check:GetNormalTexture()
        if t then t:SetTexture(nil) end
        t = check.GetPushedTexture and check:GetPushedTexture()
        if t then t:SetTexture(nil) end
        t = check.GetHighlightTexture and check:GetHighlightTexture()
        if t then t:SetTexture(nil) end
        t = check.GetCheckedTexture and check:GetCheckedTexture()
        if t then t:SetTexture(nil) end

        for _, region in ipairs({ check:GetRegions() }) do
            if region and region.IsObjectType and region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end
    end

    local function EnsureBox()
        if check._box and check._mark then return end

        local box = CreateFrame("Frame", nil, check, "BackdropTemplate")
        box:SetSize(size, size)
        box:SetPoint("LEFT", check, "LEFT", 0, 0)
        box:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = edgeSize,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        box:SetBackdropBorderColor(unpack(border))
        box:SetBackdropColor(unpack(bgOff))

        local mark = box:CreateTexture(nil, "OVERLAY")
        mark:SetPoint("CENTER")
        mark:SetSize(markSize, markSize)
        mark:SetTexture("Interface\\Buttons\\WHITE8X8")
        mark:SetVertexColor(unpack(markColor))
        mark:Hide()

        check._box = box
        check._mark = mark
    end

    local function StyleText()
        local text = check.Text or check.text or (check.GetFontString and check:GetFontString())
        if not text then return end

        text:SetTextColor(1, 1, 1, 1)
        text:SetJustifyH("LEFT")
        text:ClearAllPoints()
        text:SetPoint("LEFT", check._box, "RIGHT", gap, 0)
    end

    local function EnsureSizing()
        if check._bsSized then return end
        check._bsSized = true
        check:SetHeight(math.max(20, size + 6))
    end

    local function Sync()
        if not check._box or not check._mark then return end
        local isOn = not not check:GetChecked()
        check._mark:SetShown(isOn)
        check._box:SetBackdropColor(unpack(isOn and bgOn or bgOff))
    end

    KillTexturesOnce()
    EnsureBox()
    StyleText()
    EnsureSizing()

    -- Hook scripts without nuking existing handlers (so it plays nice with other code)
    if not check._bsHooked then
        check._bsHooked = true

        check:HookScript("OnLeave", function()
            Sync()
        end)

        check:HookScript("OnClick", function()
            Sync()
        end)

        check:HookScript("OnShow", function()
            Sync()
        end)
    end

    check._bsSync = Sync
    Sync()
end



function CheckButton:Create(name, parent, width, height, text, point, relativeTo, relativePoint, xOfs, yOfs)
    local cb = CreateFrame("CheckButton", name, parent, "UICheckButtonTemplate");
    cb:SetSize(width, height);
    cb:SetPoint(point, relativeTo, relativePoint, xOfs, yOfs);
    cb:SetText(text);

    ApplyStyle(cb);

    return cb;
end