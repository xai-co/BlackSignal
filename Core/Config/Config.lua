-- Core/Config.lua
local BS = _G.BS or {}
_G.BS = BS
BS.modules = BS.modules or {}

BS.Fonts = BS.Fonts or {}

local DB = BS.DB
local UI = BS.UI

if not DB or not UI then
    error("BS: Missing Core/DB.lua or Core/UI.lua. Check .toc load order (DB.lua, UI.lua, then Config.lua).")
end

-------------------------------------------------
-- Config state
-------------------------------------------------
local Config = {
    frame = nil,
    contentFrames = {},
    moduleButtons = {},
    selectedModule = nil,
}

local PANEL_W, PANEL_H = 860, 540
local LEFT_W = 240

-------------------------------------------------
-- Fonts (dynamic list)
-------------------------------------------------
local BASE_FONTS = {
    { label = "Friz Quadrata (default)", path = "Fonts\\FRIZQT__.TTF" },
    { label = "Arial Narrow",            path = "Fonts\\ARIALN.TTF" },
    { label = "Morpheus",                path = "Fonts\\MORPHEUS.TTF" },
    { label = "Skurri",                  path = "Fonts\\SKURRI.TTF" },
}

local function NormalizeFontPath(p)
    if type(p) ~= "string" then return nil end
    p = p:gsub("/", "\\")
    p = p:gsub("^%s+", ""):gsub("%s+$", "")
    if p == "" then return nil end
    return p
end

-- If LibSharedMedia-3.0 exists, use it. Otherwise use BS.Fonts + BASE_FONTS.
local function GetAvailableFonts()
    local fonts = {}

    -- 1) LibSharedMedia
    local LSM = _G.LibStub and _G.LibStub("LibSharedMedia-3.0", true) or nil
    if LSM and LSM.List and LSM.Fetch then
        local ok, list = pcall(LSM.List, LSM, "font")
        if ok and type(list) == "table" then
            for _, name in ipairs(list) do
                local ok2, path = pcall(LSM.Fetch, LSM, "font", name)
                path = NormalizeFontPath(path)
                if ok2 and path then
                    fonts[#fonts + 1] = { label = name, path = path }
                end
            end
        end
    end

    -- 2) BS.Fonts registry
    do
        local reg = BS.Fonts
        if type(reg) == "table" then
            local isArray = (#reg > 0)
            if isArray then
                for _, it in ipairs(reg) do
                    if type(it) == "table" then
                        local label = it.label or it.name or it[1]
                        local path = NormalizeFontPath(it.path or it.file or it[2])
                        if label and path then
                            fonts[#fonts + 1] = { label = tostring(label), path = path }
                        end
                    end
                end
            else
                for label, path in pairs(reg) do
                    path = NormalizeFontPath(path)
                    if label and path then
                        fonts[#fonts + 1] = { label = tostring(label), path = path }
                    end
                end
            end
        end
    end

    -- 3) BASE fonts (ensure at least some)
    for _, f in ipairs(BASE_FONTS) do
        fonts[#fonts + 1] = { label = f.label, path = f.path }
    end

    -- De-dup by path+label
    local seen = {}
    local out = {}
    for _, f in ipairs(fonts) do
        local key = (f.path or "") .. "||" .. (f.label or "")
        if f.path and f.label and not seen[key] then
            seen[key] = true
            out[#out + 1] = f
        end
    end

    table.sort(out, function(a, b) return (a.label or "") < (b.label or "") end)
    return out
end

-- Minimal dropdown helper (no external libs)
local function CreateDropdown(parent, width, anchorPoint, anchorFrame, relPoint, x, y)
    local dd = CreateFrame("Frame", nil, parent, "UIDropDownMenuTemplate")
    dd:SetPoint(anchorPoint, anchorFrame, relPoint, x, y)
    UIDropDownMenu_SetWidth(dd, width or 180)
    UIDropDownMenu_SetButtonWidth(dd, width or 180)
    UIDropDownMenu_JustifyText(dd, "LEFT")
    return dd
end

local function SetDropdownSelectionByValue(dd, value, items)
    if not dd or not items then return end
    value = NormalizeFontPath(value) or value

    local display = nil
    for _, it in ipairs(items) do
        if it.path == value then
            display = it.label
            break
        end
    end

    if not display then
        if type(value) == "string" and value ~= "" then
            display = value:gsub(".*\\", "")
        else
            display = "—"
        end
    end

    UIDropDownMenu_SetText(dd, display)
end

-------------------------------------------------
-- Capability detection (important!)
-------------------------------------------------
local function HasKey(t, k)
    return type(t) == "table" and t[k] ~= nil
end

local function SupportsPosition(module, defaults)
    -- Position only makes sense if a frame exists OR module explicitly uses x/y in defaults/db
    if module and module.frame then return true end
    if HasKey(defaults, "x") or HasKey(defaults, "y") then return true end
    if module and module.db and (HasKey(module.db, "x") or HasKey(module.db, "y")) then return true end
    return false
end

local function SupportsFont(module, defaults)
    -- Font controls only make sense if module has a FontString (module.text) OR defaults/db declare font fields
    if module and module.text and module.text.SetFont then return true end
    if HasKey(defaults, "font") or HasKey(defaults, "fontSize") or HasKey(defaults, "fontFlags") then return true end
    return false
end

local function SupportsTextField(module, defaults)
    -- Only show "Text:" input if module declares it (defaults/db). Avoid forcing it on modules like AutoQueue.
    if HasKey(defaults, "text") then return true end
    if module and module.db and HasKey(module.db, "text") then return true end
    return false
end

local function EnsureFontDefaults(module, defaults)
    module.db = module.db or {}
    if module.db.font == nil then
        module.db.font = NormalizeFontPath(defaults and defaults.font) or "Fonts\\FRIZQT__.TTF"
    end
    if module.db.fontSize == nil and defaults and defaults.fontSize ~= nil then
        module.db.fontSize = defaults.fontSize
    end
    if module.db.fontFlags == nil and defaults and defaults.fontFlags ~= nil then
        module.db.fontFlags = defaults.fontFlags
    end
end

-------------------------------------------------
-- Module apply helpers (guarded)
-------------------------------------------------
local function ApplyModulePosition(module)
    if not module or not module.frame or not module.db then return end
    local x = tonumber(module.db.x or 0) or 0
    local y = tonumber(module.db.y or 0) or 0
    module.frame:ClearAllPoints()
    module.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function ApplyModuleFont(module)
    if not module or not module.text or not module.text.SetFont or not module.db then return end
    local size = tonumber(module.db.fontSize) or 20
    local font = NormalizeFontPath(module.db.font) or "Fonts\\FRIZQT__.TTF"
    local flags = module.db.fontFlags or "OUTLINE"
    module.text:SetFont(font, size, flags)
end

local function ApplyModuleText(module)
    if module and module.Update then
        module:Update()
    end
end

local function ApplyModuleExtra(module)
    if not module then return end
    if module.ApplyOptions then
        module:ApplyOptions()
        return
    end
    if module.Update then
        module:Update()
    end
end

local function SetModuleEnabled(module, enabled)
    enabled = enabled and true or false

    module.enabled = enabled
    if module.db then module.db.enabled = enabled end

    if enabled and module.OnInit then
        module:OnInit()
    end

    if module.frame then
        module.frame:SetShown(enabled)
        if enabled then
            ApplyModulePosition(module)
            ApplyModuleFont(module)
            ApplyModuleText(module)
        end
    end
end

-------------------------------------------------
-- Module list ordering
-------------------------------------------------
local function OrderedModules(modulesTable)
    local list = {}

    for k, v in pairs(modulesTable) do
        if type(v) == "table" then
            local isHidden = false
            if (type(k) == "string" and k:match("^__")) then isHidden = true end
            if v.hidden then isHidden = true end

            if not isHidden then
                if v.name then
                    table.insert(list, v)
                elseif type(k) == "string" then
                    v.name = k
                    table.insert(list, v)
                end
            end
        end
    end

    table.sort(list, function(a, b) return (a.name or "") < (b.name or "") end)
    return list
end

-------------------------------------------------
-- Content factory
-------------------------------------------------
local function CreateModuleContent(parent, module)
    local defaults = DB:BuildDefaults(module) or {}

    module.db = module.db or DB:EnsureModuleDB(module.name, defaults)
    if module.enabled == nil then module.enabled = module.db.enabled end

    local canPos  = SupportsPosition(module, defaults)
    local canFont = SupportsFont(module, defaults)
    local canText = SupportsTextField(module, defaults)

    if canFont then
        EnsureFontDefaults(module, defaults)
    end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()

    -- Title
    local title = UI:CreateText(f, module.name, "TOPLEFT", f, "TOPLEFT", 0, 0, "GameFontNormalLarge")
    title:SetTextColor(1, 1, 1, 1)

    -- Enable
    local enable = UI:CreateCheck(f, "Enable", "TOPLEFT", f, "TOPLEFT", 0, -36)
    enable:SetChecked(module.enabled ~= false)
    UI:ApplyMinimalCheckStyle(enable)

    enable:SetScript("OnClick", function(self)
        SetModuleEnabled(module, self:GetChecked())
        if self._bsSync then self._bsSync() end
    end)

    local lastAnchor = enable

    -------------------------------------------------
    -- Position (optional)
    -------------------------------------------------
    local xEdit, yEdit
    if canPos then
        local xLabel = UI:CreateText(f, "X:", "TOPLEFT", enable, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        xEdit = UI:CreateEditBox(f, 70, 20, "LEFT", xLabel, "RIGHT", 10, 0)
        xEdit:SetText(tostring(module.db.x or 0))

        local yLabel = UI:CreateText(f, "Y:", "TOPLEFT", xLabel, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        yEdit = UI:CreateEditBox(f, 70, 20, "LEFT", yLabel, "RIGHT", 10, 0)
        yEdit:SetText(tostring(module.db.y or 0))

        local function CommitXY()
            local xVal = tonumber(xEdit:GetText())
            local yVal = tonumber(yEdit:GetText())
            if xVal ~= nil then module.db.x = xVal end
            if yVal ~= nil then module.db.y = yVal end
            ApplyModulePosition(module)
        end

        xEdit:SetScript("OnEnterPressed", function(self)
            CommitXY(); self:ClearFocus()
        end)
        yEdit:SetScript("OnEnterPressed", function(self)
            CommitXY(); self:ClearFocus()
        end)

        lastAnchor = yLabel
    end

    -------------------------------------------------
    -- Font controls (optional)
    -------------------------------------------------
    local fontEdit, fontDD, fonts
    if canFont then
        local fontLabel = UI:CreateText(f, "Font Size:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        fontEdit = UI:CreateEditBox(f, 70, 20, "LEFT", fontLabel, "RIGHT", 10, 0)
        fontEdit:SetText(tostring(module.db.fontSize or 20))
        fontEdit:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 6 then
                module.db.fontSize = v
                ApplyModuleFont(module)
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)

        fonts = GetAvailableFonts()
        local fontPickLabel = UI:CreateText(f, "Font:", "TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        fontDD = CreateDropdown(f, 260, "LEFT", fontPickLabel, "RIGHT", 10, -2)

        UIDropDownMenu_Initialize(fontDD, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            for _, it in ipairs(fonts) do
                info.text = it.label
                info.value = it.path
                info.func = function()
                    module.db.font = it.path
                    SetDropdownSelectionByValue(fontDD, module.db.font, fonts)
                    ApplyModuleFont(module)
                    ApplyModuleExtra(module)
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end)

        SetDropdownSelectionByValue(fontDD, module.db.font, fonts)

        lastAnchor = fontPickLabel
    end

    -------------------------------------------------
    -- Text field (optional)
    -------------------------------------------------
    local textEdit
    if canText then
        local textLabel = UI:CreateText(f, "Text:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        textEdit = UI:CreateEditBox(f, 360, 20, "LEFT", textLabel, "RIGHT", 10, 0)
        textEdit:SetText(tostring(module.db.text or ""))
        textEdit:SetScript("OnEnterPressed", function(self)
            module.db.text = self:GetText() or ""
            ApplyModuleText(module)
            self:ClearFocus()
        end)
        lastAnchor = textLabel
    end

    -------------------------------------------------
    -- Optional controls (auto-render based on db keys)
    -------------------------------------------------
    if module.db.updateInterval ~= nil then
        local lbl = UI:CreateText(f, "Update Interval (s):", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local eb = UI:CreateEditBox(f, 70, 20, "LEFT", lbl, "RIGHT", 10, 0)
        eb:SetText(tostring(module.db.updateInterval or 1.0))
        eb:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 0.01 and v <= 10 then
                module.db.updateInterval = v
                if module.StopTicker then module:StopTicker() end
                if module.StartTicker then module:StartTicker() end
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = lbl
    end

    if module.db.thickness ~= nil then
        local lbl = UI:CreateText(f, "Thickness:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local eb = UI:CreateEditBox(f, 70, 20, "LEFT", lbl, "RIGHT", 10, 0)
        eb:SetText(tostring(module.db.thickness or 20))
        eb:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 10 and v <= 40 then
                module.db.thickness = v
                if module.StopTicker then module:StopTicker() end
                if module.StartTicker then module:StartTicker() end
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = lbl
    end

    if module.db.size ~= nil then
        local lbl = UI:CreateText(f, "Size:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local eb = UI:CreateEditBox(f, 70, 20, "LEFT", lbl, "RIGHT", 10, 0)
        eb:SetText(tostring(module.db.size or 48))
        eb:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 12 and v <= 256 then
                module.db.size = v
                if module.StopTicker then module:StopTicker() end
                if module.StartTicker then module:StartTicker() end
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = lbl
    end

    if module.db.onlyShowIfKickReady ~= nil then
        local cb = UI:CreateCheck(f, "Only show if kick is ready", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14)
        cb:SetChecked(module.db.onlyShowIfKickReady == true)
        UI:ApplyMinimalCheckStyle(cb)
        cb:SetScript("OnClick", function(self)
            module.db.onlyShowIfKickReady = self:GetChecked() and true or false
            ApplyModuleExtra(module)
            if self._bsSync then self._bsSync() end
        end)
        lastAnchor = cb
    end

    if module.db.kickSpellIdOverride ~= nil then
        local lbl = UI:CreateText(f, "Kick SpellId Override:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local eb = UI:CreateEditBox(f, 110, 20, "LEFT", lbl, "RIGHT", 10, 0)
        eb:SetText(tostring(module.db.kickSpellIdOverride or ""))
        eb:SetScript("OnEnterPressed", function(self)
            local raw = (self:GetText() or ""):gsub("%s+", "")
            if raw == "" then
                module.db.kickSpellIdOverride = nil
            else
                local v = tonumber(raw)
                if v and v > 0 then
                    module.db.kickSpellIdOverride = math.floor(v)
                end
            end
            ApplyModuleExtra(module)
            self:ClearFocus()
        end)
        lastAnchor = lbl
    end

    if module.db.debugAlwaysShow ~= nil then
        local cb = UI:CreateCheck(f, "Debug: always show", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14)
        cb:SetChecked(module.db.debugAlwaysShow == true)
        UI:ApplyMinimalCheckStyle(cb)
        cb:SetScript("OnClick", function(self)
            module.db.debugAlwaysShow = self:GetChecked() and true or false
            ApplyModuleExtra(module)
            if self._bsSync then self._bsSync() end
        end)
        lastAnchor = cb
    end

    if module.db.colorPicker then
        local lbl = UI:CreateText(
            f,
            "Color:",
            "TOPLEFT",
            lastAnchor,
            "BOTTOMLEFT",
            0,
            -14,
            "GameFontHighlight"
        )

        UI:CreateColorPicker(
            f, 26, 26,
            "LEFT", lbl, "RIGHT", 10, 0,
            function()
                return
                    module.db.ringColorR or 1,
                    module.db.ringColorG or 1,
                    module.db.ringColorB or 1,
                    module.db.ringAlpha or 1
            end,
            function(r, g, b, a)
                module.db.ringColorR = r
                module.db.ringColorG = g
                module.db.ringColorB = b
                module.db.ringAlpha  = a
                ApplyModuleExtra(module)
            end,
            "Click para cambiar el color"
        )

        lastAnchor = lbl
    end

    -------------------------------------------------
    -- Reset (capability-aware)
    -------------------------------------------------
    local reset = UI:CreateButton(f, "Reset Defaults", 140, 24, "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -18)
    reset:SetScript("OnClick", function()
        local d = DB:BuildDefaults(module) or {}

        -- Always reset enabled if present
        if d.enabled ~= nil then
            module.db.enabled = (d.enabled ~= false)
        else
            module.db.enabled = (module.db.enabled ~= false)
        end
        module.enabled = module.db.enabled

        -- Only reset fields that exist for this module
        if canPos then
            module.db.x = d.x or 0
            module.db.y = d.y or 0
            if xEdit then xEdit:SetText(tostring(module.db.x)) end
            if yEdit then yEdit:SetText(tostring(module.db.y)) end
            ApplyModulePosition(module)
        end

        if canFont then
            module.db.fontSize = d.fontSize or module.db.fontSize or 20
            module.db.font = NormalizeFontPath(d.font) or module.db.font or "Fonts\\FRIZQT__.TTF"
            if d.fontFlags ~= nil then module.db.fontFlags = d.fontFlags end
            if fontEdit then fontEdit:SetText(tostring(module.db.fontSize)) end

            -- refresh dropdown list + selection (in case LSM loaded late)
            fonts = GetAvailableFonts()
            if fontDD then SetDropdownSelectionByValue(fontDD, module.db.font, fonts) end

            ApplyModuleFont(module)
        end

        if canText then
            module.db.text = d.text or ""
            if textEdit then textEdit:SetText(tostring(module.db.text)) end
            ApplyModuleText(module)
        end

        -- Optional known fields
        if d.iconsOnly ~= nil then module.db.iconsOnly = d.iconsOnly end
        if d.iconSize ~= nil then module.db.iconSize = d.iconSize end
        if d.iconGap ~= nil then module.db.iconGap = d.iconGap end
        if d.updateInterval ~= nil then module.db.updateInterval = d.updateInterval end
        if d.showOnlyBuffICanApply ~= nil then module.db.showOnlyBuffICanApply = d.showOnlyBuffICanApply end
        if d.onlyShowIfKickReady ~= nil then module.db.onlyShowIfKickReady = d.onlyShowIfKickReady end
        if d.kickSpellIdOverride ~= nil then module.db.kickSpellIdOverride = d.kickSpellIdOverride end
        if d.debugAlwaysShow ~= nil then module.db.debugAlwaysShow = d.debugAlwaysShow end

        if d.colorPicker then
            module.db.ringColorR = d.ringColorR
            module.db.ringColorG = d.ringColorG
            module.db.ringColorB = d.ringColorB
            module.db.ringAlpha  = d.ringAlpha
        end

        enable:SetChecked(module.enabled)
        if enable._bsSync then enable._bsSync() end

        if module.frame then module.frame:SetShown(module.enabled) end

        if module.StopTicker then module:StopTicker() end
        if module.StartTicker and module.enabled ~= false then module:StartTicker() end

        ApplyModuleExtra(module)
    end)

    UI:CreateText(
        f,
        "Tip: pulsa Enter en cada campo para aplicar.",
        "TOPLEFT",
        reset,
        "BOTTOMLEFT",
        0,
        -14,
        "GameFontDisableSmall"
    )

    return f
end

-------------------------------------------------
-- Selection helpers
-------------------------------------------------
local function SelectModule(moduleName)
    if not Config.frame then return end

    for _, cf in pairs(Config.contentFrames) do
        cf:Hide()
    end

    local target = Config.contentFrames[moduleName]
    if target then
        target:Show()
        Config.selectedModule = moduleName
    end
end

local function SetActiveButton(activeName)
    for name, b in pairs(Config.moduleButtons) do
        if b and b.SetBSActive then
            b:SetBSActive(name == activeName)
        end
    end
end

-------------------------------------------------
-- Main window build
-------------------------------------------------
local function BuildUI()
    if Config.frame then return end

    local f = CreateFrame("Frame", "BSConfigFrame", UIParent, "BackdropTemplate")
    Config.frame = f

    tinsert(UISpecialFrames, f:GetName())

    f:SetSize(PANEL_W, PANEL_H)
    f:SetPoint("CENTER")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetFrameStrata("DIALOG")
    f:Hide()

    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 2,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0, 0, 0, 0.75)
    f:SetBackdropBorderColor(0, 0, 0, 1)

    -- Title + Icon
    local iconPath = "Interface\\AddOns\\BlackSignal\\Media\\icon_64.tga"
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -14)

    local title = UI:CreateText(f, "BlackSignal", "LEFT", icon, "RIGHT", 6, 0, "GameFontNormalLarge")
    title:SetTextColor(1, 1, 1, 1)

    -- Close
    local close = CreateFrame("Button", nil, f)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    close:SetNormalFontObject("GameFontHighlight")
    close:SetText("X")
    close:GetFontString():SetTextColor(1, 1, 1, 1)

    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function(self) self:GetFontString():SetTextColor(1, 0.3, 0.3, 1) end)
    close:SetScript("OnLeave", function(self) self:GetFontString():SetTextColor(1, 1, 1, 1) end)

    -- Left panel
    local left = CreateFrame("Frame", nil, f, "BackdropTemplate")
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -58)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    left:SetWidth(LEFT_W)
    UI:ApplyPanelStyle(left, 0.20, 1)

    -- Right panel
    local right = CreateFrame("Frame", nil, f, "BackdropTemplate")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    UI:ApplyPanelStyle(right, 0.20, 1)

    local modules = OrderedModules(BS.modules)
    if #modules == 0 then
        UI:CreateText(right, "No modules registered in BS.modules", "TOPLEFT", right, "TOPLEFT", 16, -16, "GameFontHighlight")
        return
    end

    local y = -8
    local btnGap = 6
    local btnH = 26
    local btnPad = 8

    for _, m in ipairs(modules) do
        m.db = m.db or DB:EnsureModuleDB(m.name, DB:BuildDefaults(m))
        if m.enabled == nil then m.enabled = m.db.enabled end

        local btn = CreateFrame("Button", nil, left, "BackdropTemplate")
        btn:SetHeight(btnH)
        btn:SetPoint("TOPLEFT", left, "TOPLEFT", btnPad, y)
        btn:SetPoint("TOPRIGHT", left, "TOPRIGHT", -btnPad, y)
        btn:SetText(m.name)

        UI:ApplyNavButtonStyle(btn, {
            bgA = 0,
            hoverA = 0.45,
            activeA = 0.70,
            edgeSize = 1,
            paddingX = 10,
        })

        btn:SetScript("OnClick", function()
            SetActiveButton(m.name)
            SelectModule(m.name)
        end)

        Config.moduleButtons[m.name] = btn

        y = y - (btnH + btnGap)

        local content = CreateModuleContent(right, m)
        content:SetPoint("TOPLEFT", right, "TOPLEFT", 16, -16)
        content:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", -16, 16)
        Config.contentFrames[m.name] = content
    end

    SetActiveButton(modules[1].name)
    SelectModule(modules[1].name)
end

local function ToggleConfig()
    BuildUI()
    if Config.frame:IsShown() then
        Config.frame:Hide()
    else
        Config.frame:Show()
    end
end

-------------------------------------------------
-- Slash command
-------------------------------------------------
SLASH_BS1 = "/bs"
---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList["BS"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$") -- trim

    -- no args -> open/close
    if msg == "" then
        ToggleConfig()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "config" then
        ToggleConfig()
        return
    end

    if cmd == "aq" or cmd == "autoqueue" then
        local m = _G.BS and _G.BS.modules and _G.BS.modules.AutoQueue
        if m and m.HandleSlash then
            m:HandleSlash(rest)
        else
            print("|cffb048f8BS:|r AutoQueue no está cargado.")
        end
        return
    end

    print("|cffb048f8BS:|r Comandos: /bs (config), /bs aq [toggle|on|off]")
end

-------------------------------------------------
-- Apply enabled state on login (capability-aware)
-------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    for _, m in pairs(BS.modules) do
        if type(m) == "table" and m.name then
            local d = DB:BuildDefaults(m) or {}
            m.db = m.db or DB:EnsureModuleDB(m.name, d)
            if m.enabled == nil then m.enabled = m.db.enabled end

            -- Only ensure font defaults when module supports fonts
            if SupportsFont(m, d) then
                EnsureFontDefaults(m, d)
            end

            if m.frame then
                m.frame:SetShown(m.enabled ~= false)

                if SupportsPosition(m, d) then
                    ApplyModulePosition(m)
                end

                if SupportsFont(m, d) then
                    ApplyModuleFont(m)
                end

                ApplyModuleText(m)
            end
        end
    end
end)
