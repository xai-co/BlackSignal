-- RightPanel.lua
-- @module RightPanel
-- @alias RightPanel

local _, BS = ...

BS.RightPanel       = {}
local RightPanel    = BS.RightPanel

local UI    = BS.UI
local UTILS = BS.Utils

local LEFT_GAP = 12 -- Gap between left and right panels

-- ------------------------------------------------
-- Fonts helpers
-- ------------------------------------------------
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

local function GetAvailableFonts()
    local fonts = {}

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

    for _, f in ipairs(BASE_FONTS) do
        fonts[#fonts + 1] = { label = f.label, path = f.path }
    end

    local seen, out = {}, {}
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

    local display
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

-- ------------------------------------------------
-- Capability detection
-- ------------------------------------------------
local function SupportsFont(module, defaults)
    if module and module.text and module.text.SetFont then return true end
    if UTILS:HasKey(defaults, "font") or UTILS:HasKey(defaults, "fontSize") or UTILS:HasKey(defaults, "fontFlags") then return true end
    return false
end

local function SupportsTextField(module, defaults)
    if UTILS:HasKey(defaults, "text") then return true end
    if module and module.db and UTILS:HasKey(module.db, "text") then return true end
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

-- ------------------------------------------------
-- Apply helpers
-- ------------------------------------------------
local function ApplyModulePosition(module)
    if not module or not module.frame or not module.db then return end
    local x = tonumber(module.db.x or 0) or 0
    local y = tonumber(module.db.y or 0) or 0
    module.frame:ClearAllPoints()
    module.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function ApplyModuleFont(module)
    if not module or not module.text or not module.text.SetFont or not module.db then return end
    local size  = tonumber(module.db.fontSize) or 20
    local font  = NormalizeFontPath(module.db.font) or "Fonts\\FRIZQT__.TTF"
    local flags = module.db.fontFlags or "OUTLINE"
    module.text:SetFont(font, size, flags)
end

local function ApplyModuleText(module)
    if module and module.Update then module:Update() end
end

local function ApplyModuleExtra(module)
    if not module then return end
    if module.ApplyOptions then
        module:ApplyOptions()
        return
    end
    if module.Update then module:Update() end
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

-- ------------------------------------------------
-- Content factory
-- ------------------------------------------------
local function CreateModuleContent(parent, module)
    local defaults = module.defaults or { enabled = true }

    module.db = module.db or BS.DB:EnsureDB(module.name, defaults)
    if module.enabled == nil then module.enabled = module.db.enabled end

    local canFont = SupportsFont(module, defaults)
    local canText = SupportsTextField(module, defaults)

    if canFont then EnsureFontDefaults(module, defaults) end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()

    -- Title
    local title = UI:CreateText(f, module.name, "TOPLEFT", f, "TOPLEFT", 0, 0, "GameFontNormalLarge")
    title:SetTextColor(1, 1, 1, 1)

    -- Enable
    local enableCB = BS.CheckButton:Create("EnableCheck", f, 150, 20, "Enable", "TOPLEFT", f, "TOPLEFT", 0, -36)
    enableCB:SetChecked(module.enabled ~= false)
    enableCB:SetScript("OnClick", function(self)
        SetModuleEnabled(module, self:GetChecked())
        if self._bsSync then self._bsSync() end
    end)

    local lastAnchor = enableCB

    -- Font controls
    local fontEdit, fontDD, fonts
    if canFont then
        local fontLabel = UI:CreateText(f, "Font Size:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        fontEdit = BS.EditBox:Create("ConfigFontSizeBox", f, 70, 20, "", "LEFT", fontLabel, "RIGHT", 10, 0)
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

        UIDropDownMenu_Initialize(fontDD, function(_, level)
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

    -- Text field
    local textEdit
    if canText then
        local textLabel = UI:CreateText(f, "Text:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        textEdit = BS.EditBox:Create("ConfigTextBox", f, 360, 20, "", "LEFT", textLabel, "RIGHT", 10, 0)
        textEdit:SetText(tostring(module.db.text or ""))
        textEdit:SetScript("OnEnterPressed", function(self)
            module.db.text = self:GetText() or ""
            ApplyModuleText(module)
            self:ClearFocus()
        end)
        lastAnchor = textLabel
    end

    -- Optional controls (tu lógica original)
    if module.db.updateInterval ~= nil then
        local lbl = UI:CreateText(f, "Update Interval (s):", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14,
            "GameFontHighlight")
        local eb = BS.EditBox:Create("ConfigUpdateIntervalBox", f, 70, 20, "", "LEFT", lbl, "RIGHT", 10, 0)
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

    if module.db.thickness ~= nil and UI.CreateDropdown then
        local lbl = UI:CreateText(f, "Thickness:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local thicknessItems = {
            { 10, "10 PX" },
            { 20, "20 PX" },
            { 30, "30 PX" },
            { 40, "40 PX" },
        }

        local dd = UI:CreateDropdown(
            f,
            160, 24,
            "LEFT", lbl, "RIGHT", 10, 0,
            thicknessItems,
            function() return tonumber(module.db.thickness) or 20 end,
            function(v)
                module.db.thickness = tonumber(v) or 20
                ApplyModuleExtra(module)
            end,
            "Grosor del anillo del mouse"
        )

        f._bsThicknessDD = dd
        lastAnchor = lbl
    end

    if module.db.size ~= nil then
        local lbl = UI:CreateText(f, "Size:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local eb = BS.EditBox:Create("ConfigSizeBox", f, 70, 20, "", "LEFT", lbl, "RIGHT", 10, 0)

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

    -- Reset (usa defaults reales si existen)
    local reset = BS.Button:Create("ResetButton", f, 140, 24, "Reset Defaults", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0,
        -18)
    reset:SetScript("OnClick", function()
        local d = module.defaults or { enabled = true }

        -- enabled
        module.db.enabled = (d.enabled ~= false)
        module.enabled = module.db.enabled
        enableCB:SetChecked(module.enabled)

        -- font
        if canFont then
            module.db.fontSize = d.fontSize or module.db.fontSize or 20
            module.db.font = NormalizeFontPath(d.font) or module.db.font or "Fonts\\FRIZQT__.TTF"
            if d.fontFlags ~= nil then module.db.fontFlags = d.fontFlags end
            if fontEdit then fontEdit:SetText(tostring(module.db.fontSize)) end

            fonts = GetAvailableFonts()
            if fontDD then SetDropdownSelectionByValue(fontDD, module.db.font, fonts) end

            ApplyModuleFont(module)
        end

        -- text
        if canText then
            module.db.text = d.text or ""
            if textEdit then textEdit:SetText(tostring(module.db.text)) end
            ApplyModuleText(module)
        end

        -- extras típicos
        if d.updateInterval ~= nil then module.db.updateInterval = d.updateInterval end
        if d.size ~= nil then module.db.size = d.size end
        if d.thickness ~= nil then
            module.db.thickness = d.thickness
            if f._bsThicknessDD and f._bsThicknessDD.Refresh then f._bsThicknessDD:Refresh() end
        end

        if module.frame then module.frame:SetShown(module.enabled ~= false) end
        if module.StopTicker then module:StopTicker() end
        if module.StartTicker and module.enabled ~= false then module:StartTicker() end

        ApplyModuleExtra(module)
    end)

    UI:CreateText(
        f,
        "Tip: Press Enter to apply changes.",
        "TOPLEFT",
        reset,
        "BOTTOMLEFT",
        0,
        -14,
        "GameFontDisableSmall"
    )

    return f
end

-- ------------------------------------------------
-- RightPanel API
-- ------------------------------------------------
function RightPanel:Create(parent, leftPanel)
    if self.panel then return self.panel end

    local panel = CreateFrame("Frame", "BSRightPanel", parent, "BackdropTemplate")
    self.panel = panel

    panel:SetPoint("TOPLEFT", leftPanel, "TOPRIGHT", LEFT_GAP, 0)
    panel:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -14, 14)

    UI:ApplyPanelStyle(panel, 0.20, 1)

    self.contentFrames = {}
    self.selectedModule = nil

    return panel
end

function RightPanel:ShowModule(module)
    if not module or not module.name then return end
    if not self.panel then return end

    -- hide all
    for _, cf in pairs(self.contentFrames) do
        if cf and cf.Hide then cf:Hide() end
    end

    -- create on demand
    local content = self.contentFrames[module.name]
    if not content then
        content = CreateModuleContent(self.panel, module)
        content:SetPoint("TOPLEFT", self.panel, "TOPLEFT", 16, -16)
        content:SetPoint("BOTTOMRIGHT", self.panel, "BOTTOMRIGHT", -16, 16)
        self.contentFrames[module.name] = content
    end

    content:Show()
    self.selectedModule = module.name
end
