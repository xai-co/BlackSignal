-- Core/DB.lua
-- DB + (legacy) Config UI file.
-- CORRECCIÓN: añade DB:BuildDefaults y expone DB:EnsureModuleDB para que Core/Config.lua no rompa.

local BS = _G.BS or {}
_G.BS = BS
BS.modules = BS.modules or {}

_G.BSDB = _G.BSDB or { profile = { modules = {} } }
local BSDB = _G.BSDB

local DB = {}
BS.DB = DB

local function EnsureProfile()
    BSDB.profile = BSDB.profile or {}
    BSDB.profile.modules = BSDB.profile.modules or {}
end

-------------------------------------------------
-- DB API (used by Core/Config.lua and modules)
-------------------------------------------------
function DB:EnsureModuleDB(moduleName, defaults)
    EnsureProfile()
    BSDB.profile.modules[moduleName] = BSDB.profile.modules[moduleName] or {}
    local db = BSDB.profile.modules[moduleName]
    for k, v in pairs(defaults or {}) do
        if db[k] == nil then db[k] = v end
    end
    return db
end

-- Back-compat: mantener el helper local existente
local function EnsureModuleDB(moduleName, defaults)
    return DB:EnsureModuleDB(moduleName, defaults)
end

-- IMPORTANT: esto es lo que te faltaba (error en Core/Config.lua: DB:BuildDefaults nil)
function DB:BuildDefaults(module)
    if type(module) ~= "table" then
        return {}
    end

    -- 1) Preferir BuildDefaults() del módulo si existe
    if type(module.BuildDefaults) == "function" then
        local ok, defs = pcall(module.BuildDefaults, module)
        if ok and type(defs) == "table" then
            return defs
        end
        return {}
    end

    -- 2) Si expone defaults como tabla
    if type(module.defaults) == "table" then
        return module.defaults
    end

    -- 3) Fallback mínimo
    return {
        enabled = module.enabled ~= false,
        x = 0,
        y = 18,
        fontSize = 20,
        text = "",
    }
end

-------------------------------------------------
-- Module list ordering
-------------------------------------------------
local function OrderedModules(modulesTable)
    local list = {}

    for k, v in pairs(modulesTable) do
        if type(v) == "table" then
            if (type(k) == "string" and k:match("^__")) or v.hidden then
                -- skip
            else
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
-- UI Helpers
-------------------------------------------------
local function CreateText(parent, text, point, rel, relPoint, x, y, template)
    local fs = parent:CreateFontString(nil, "ARTWORK", template or "GameFontNormal")
    fs:SetPoint(point, rel, relPoint, x, y)
    fs:SetText(text or "")
    return fs
end

local function CreateButton(parent, text, w, h, point, rel, relPoint, x, y)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(w, h)
    btn:SetPoint(point, rel, relPoint, x, y)
    btn:SetText(text)
    return btn
end

local function CreateEditBox(parent, w, h, point, rel, relPoint, x, y)
    local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    eb:SetSize(w, h)
    eb:SetPoint(point, rel, relPoint, x, y)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightSmall")
    return eb
end

local function CreateCheck(parent, label, point, rel, relPoint, x, y)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint(point, rel, relPoint, x, y)
    cb.text:SetText(label)
    return cb
end

-------------------------------------------------
-- Main Config Window (legacy)
-------------------------------------------------
local Config = {}
Config.frame = nil
Config.contentFrames = {}
Config.selectedModule = nil

local PANEL_W, PANEL_H = 860, 540
local LEFT_W = 240
local PADDING = 14

local function ApplyModulePosition(module)
    if not module or not module.frame or not module.db then return end
    module.frame:ClearAllPoints()
    module.frame:SetPoint("CENTER", UIParent, "CENTER", module.db.x or 0, module.db.y or 0)
end

local function ApplyModuleFont(module)
    if not module or not module.text or not module.db then return end
    local size = tonumber(module.db.fontSize) or 20
    module.text:SetFont("Fonts\\FRIZQT__.TTF", size, "OUTLINE")
end

local function ApplyModuleText(module)
    if module and module.Update then
        module:Update()
    end
end

-- generic "apply" helper for extra options
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

local function CreateModuleContent(parent, module)
    local defaults = module.defaults or {
        enabled = module.enabled ~= false,
        x = 0,
        y = 18,
        fontSize = 20,
        text = (module.name == "Shimmer") and "No Shimmer: " or (module.db and module.db.text) or "",
    }

    module.db = module.db or EnsureModuleDB(module.name, defaults)
    if module.enabled == nil then module.enabled = module.db.enabled end

    local f = CreateFrame("Frame", nil, parent)
    f:SetAllPoints()
    f:Hide()

    -- Title
    local title = CreateText(f, module.name, "TOPLEFT", f, "TOPLEFT", 0, 0, "GameFontNormalLarge")
    title:SetTextColor(1, 1, 1, 1)

    -------------------------------------------------
    -- Enable
    -------------------------------------------------
    local function ApplyCheckStyle(check)
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

    local function SetModuleEnabled(module, enabled)
        enabled = enabled and true or false

        module.enabled = enabled
        module.db.enabled = enabled

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

    local enable = CreateCheck(f, "Enable", "TOPLEFT", f, "TOPLEFT", 0, -36)
    enable:SetChecked(module.enabled ~= false)

    ApplyCheckStyle(enable)

    enable:SetScript("OnClick", function(self)
        SetModuleEnabled(module, self:GetChecked())
        if self._bsSync then self._bsSync() end
    end)

    -------------------------------------------------
    -- X / Y
    -------------------------------------------------
    local xLabel = CreateText(f, "X:", "TOPLEFT", enable, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
    local xEdit = CreateEditBox(f, 70, 20, "LEFT", xLabel, "RIGHT", 10, 0)
    xEdit:SetText(tostring(module.db.x or 0))

    local yLabel = CreateText(f, "Y:", "TOPLEFT", xLabel, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
    local yEdit = CreateEditBox(f, 70, 20, "LEFT", yLabel, "RIGHT", 10, 0)
    yEdit:SetText(tostring(module.db.y or 18))

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

    -------------------------------------------------
    -- Font Size
    -------------------------------------------------
    local fontLabel = CreateText(f, "Font Size:", "TOPLEFT", yLabel, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
    local fontEdit = CreateEditBox(f, 70, 20, "LEFT", fontLabel, "RIGHT", 10, 0)
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

    -------------------------------------------------
    -- Text
    -------------------------------------------------
    local textLabel = CreateText(f, "Text:", "TOPLEFT", fontLabel, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
    local textEdit = CreateEditBox(f, 360, 20, "LEFT", textLabel, "RIGHT", 10, 0)
    textEdit:SetText(tostring(module.db.text or ""))
    textEdit:SetScript("OnEnterPressed", function(self)
        module.db.text = self:GetText() or ""
        ApplyModuleText(module)
        self:ClearFocus()
    end)

    local lastAnchor = textLabel

    -- Show Only Buff I can apply (checkbox)
    if module.db and module.db.showOnlyBuffICanApply ~= nil then
        local solo = CreateCheck(f, "Show only buff I can apply", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14)
        solo:SetChecked(module.db.showOnlyBuffICanApply == true)
        solo:SetScript("OnClick", function(self)
            module.db.showOnlyBuffICanApply = self:GetChecked() and true or false
            ApplyModuleExtra(module)
        end)
        lastAnchor = solo
    end

    -- Icons Only (checkbox)
    if module.db and module.db.iconsOnly ~= nil then
        local iconsOnly = CreateCheck(f, "Icons only", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14)
        iconsOnly:SetChecked(module.db.iconsOnly == true)
        iconsOnly:SetScript("OnClick", function(self)
            module.db.iconsOnly = self:GetChecked() and true or false
            ApplyModuleExtra(module)
        end)
        lastAnchor = iconsOnly
    end

    -- Icon Size (editbox)
    if module.db and module.db.iconSize ~= nil then
        local iconSizeLabel = CreateText(f, "Icon Size:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local iconSizeEdit = CreateEditBox(f, 70, 20, "LEFT", iconSizeLabel, "RIGHT", 10, 0)
        iconSizeEdit:SetText(tostring(module.db.iconSize or 20))
        iconSizeEdit:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 8 and v <= 64 then
                module.db.iconSize = v
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = iconSizeLabel
    end

    -- Icon Gap (editbox)
    if module.db and module.db.iconGap ~= nil then
        local iconGapLabel = CreateText(f, "Icon Gap:", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local iconGapEdit = CreateEditBox(f, 70, 20, "LEFT", iconGapLabel, "RIGHT", 10, 0)
        iconGapEdit:SetText(tostring(module.db.iconGap or 6))
        iconGapEdit:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 0 and v <= 40 then
                module.db.iconGap = v
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = iconGapLabel
    end

    -- Update Interval (editbox)
    if module.db and module.db.updateInterval ~= nil then
        local intervalLabel = CreateText(f, "Update Interval (s):", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local intervalEdit = CreateEditBox(f, 70, 20, "LEFT", intervalLabel, "RIGHT", 10, 0)
        intervalEdit:SetText(tostring(module.db.updateInterval or 1.0))
        intervalEdit:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 0.1 and v <= 10 then
                module.db.updateInterval = v
                if module.StopTicker then module:StopTicker() end
                if module.StartTicker then module:StartTicker() end
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = intervalLabel
    end

    -- Show when solo (checkbox)
    if module.db and module.db.showWhenSolo ~= nil then
        local solo = CreateCheck(f, "Show when solo", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14)
        solo:SetChecked(module.db.showWhenSolo == true)
        solo:SetScript("OnClick", function(self)
            module.db.showWhenSolo = self:GetChecked() and true or false
            ApplyModuleExtra(module)
        end)
        lastAnchor = solo
    end

    -- Max names in text (editbox)
    if module.db and module.db.maxNames ~= nil then
        local maxNamesLabel = CreateText(f, "Max Names (text):", "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -14, "GameFontHighlight")
        local maxNamesEdit = CreateEditBox(f, 70, 20, "LEFT", maxNamesLabel, "RIGHT", 10, 0)
        maxNamesEdit:SetText(tostring(module.db.maxNames or 6))
        maxNamesEdit:SetScript("OnEnterPressed", function(self)
            local v = tonumber(self:GetText())
            if v and v >= 1 and v <= 40 then
                module.db.maxNames = math.floor(v)
                ApplyModuleExtra(module)
            end
            self:ClearFocus()
        end)
        lastAnchor = maxNamesLabel
    end

    -------------------------------------------------
    -- Reset
    -------------------------------------------------
    local reset = CreateButton(f, "Reset Defaults", 140, 24, "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -18)
    reset:SetScript("OnClick", function()
        module.db.x = defaults.x or 0
        module.db.y = defaults.y or 18
        module.db.fontSize = defaults.fontSize or 20
        module.db.text = defaults.text or ""
        module.db.enabled = defaults.enabled ~= false
        module.enabled = module.db.enabled

        if defaults.iconsOnly ~= nil then module.db.iconsOnly = defaults.iconsOnly end
        if defaults.iconSize ~= nil then module.db.iconSize = defaults.iconSize end
        if defaults.iconGap ~= nil then module.db.iconGap = defaults.iconGap end
        if defaults.updateInterval ~= nil then module.db.updateInterval = defaults.updateInterval end
        if defaults.showWhenSolo ~= nil then module.db.showWhenSolo = defaults.showWhenSolo end
        if defaults.maxNames ~= nil then module.db.maxNames = defaults.maxNames end

        xEdit:SetText(tostring(module.db.x))
        yEdit:SetText(tostring(module.db.y))
        fontEdit:SetText(tostring(module.db.fontSize))
        textEdit:SetText(tostring(module.db.text))

        enable:SetChecked(module.enabled)
        if module.frame then module.frame:SetShown(module.enabled) end

        ApplyModulePosition(module)
        ApplyModuleFont(module)

        if module.StopTicker then module:StopTicker() end
        if module.StartTicker and module.enabled ~= false then module:StartTicker() end

        ApplyModuleExtra(module)
    end)

    CreateText(
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

local function BuildUI()
    if Config.frame then return end

    local f = CreateFrame("Frame", "BSConfigFrame", UIParent, "BackdropTemplate")
    Config.frame = f
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

    local title = CreateText(f, "BS UI", "TOPLEFT", f, "TOPLEFT", 18, -14, "GameFontNormalLarge")
    title:SetTextColor(1, 1, 1, 1)

    local close = CreateFrame("Button", nil, f)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -8)
    close:SetNormalFontObject("GameFontHighlight")
    close:SetText("X")
    close:GetFontString():SetTextColor(1, 1, 1, 1)
    close:SetScript("OnClick", function() f:Hide() end)
    close:SetScript("OnEnter", function(self) self:GetFontString():SetTextColor(1, 0.3, 0.3, 1) end)
    close:SetScript("OnLeave", function(self) self:GetFontString():SetTextColor(1, 1, 1, 1) end)

    local function ApplyPanelStyle(frame, bgAlpha, borderSize)
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = borderSize or 1,
            insets = { left = borderSize or 1, right = borderSize or 1, top = borderSize or 1, bottom = borderSize or 1 },
        })
        frame:SetBackdropColor(0, 0, 0, bgAlpha or 0.85)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    local function ApplyButtonStyle(btn, opts)
        opts = opts or {}
        local bgA = opts.bgA or 1
        local hoverA = opts.hoverA or 0.55
        local activeA = opts.activeA or 0.75
        local borderA = opts.borderA or 1
        local edgeSize = opts.edgeSize or 1
        local paddingX = opts.paddingX or 10
        local GRAY = 0.16

        btn:SetNormalFontObject("GameFontHighlightSmall")
        btn:SetHighlightFontObject("GameFontHighlightSmall")
        btn:SetDisabledFontObject("GameFontDisableSmall")

        for _, region in ipairs({ btn:GetRegions() }) do
            if region:IsObjectType("Texture") then
                region:SetTexture(nil)
            end
        end

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            tile = false,
            edgeSize = edgeSize,
            insets = { left = edgeSize, right = edgeSize, top = edgeSize, bottom = edgeSize }
        })
        btn:SetBackdropBorderColor(0, 0, 0, borderA)
        btn:SetBackdropColor(GRAY, GRAY, GRAY, bgA)

        local fs = btn:GetFontString()
        if fs then
            fs:SetJustifyH("LEFT")
            fs:ClearAllPoints()
            fs:SetPoint("LEFT", btn, "LEFT", paddingX, 0)
            fs:SetTextColor(1, 1, 1, 1)
        end

        btn._bs = btn._bs or {}
        btn._bs.bgA = bgA
        btn._bs.hoverA = hoverA
        btn._bs.activeA = activeA

        btn:SetScript("OnEnter", function(self)
            if not self._bsActive then
                self:SetBackdropColor(0, 0, 0, self._bs.hoverA)
            end
        end)

        btn:SetScript("OnLeave", function(self)
            if not self._bsActive then
                self:SetBackdropColor(0, 0, 0, self._bs.bgA)
            end
        end)

        function btn:SetBSActive(active)
            self._bsActive = active and true or false
            if self._bsActive then
                self:SetBackdropColor(0, 0, 0, self._bs.activeA)
            else
                self:SetBackdropColor(0, 0, 0, self._bs.bgA)
            end
        end
    end

    local left = CreateFrame("Frame", nil, f, "BackdropTemplate")
    left:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -46)
    left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 14)
    left:SetWidth(LEFT_W)
    ApplyPanelStyle(left, 0.20, 1)

    local right = CreateFrame("Frame", nil, f, "BackdropTemplate")
    right:SetPoint("TOPLEFT", left, "TOPRIGHT", 12, 0)
    right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 14)
    ApplyPanelStyle(right, 0.20, 1)

    local modules = OrderedModules(BS.modules)
    local y = -8
    local btnGap = 6
    local btnH = 26
    local btnPad = 8

    Config.moduleButtons = Config.moduleButtons or {}

    if #modules == 0 then
        CreateText(right, "No modules registered in BS.modules", "TOPLEFT", right, "TOPLEFT", 16, -16, "GameFontHighlight")
        return
    end

    local function SetActiveButton(activeName)
        for name, b in pairs(Config.moduleButtons) do
            if b and b.SetBSActive then
                b:SetBSActive(name == activeName)
            end
        end
    end

    for _, m in ipairs(modules) do
        m.db = m.db or EnsureModuleDB(m.name, m.defaults or { enabled = m.enabled ~= false, x = 0, y = 18, fontSize = 20, text = "" })
        if m.enabled == nil then m.enabled = m.db.enabled end

        local btn = CreateFrame("Button", nil, left, "BackdropTemplate")
        btn:SetHeight(btnH)
        btn:SetPoint("TOPLEFT", left, "TOPLEFT", btnPad, y)
        btn:SetPoint("TOPRIGHT", left, "TOPRIGHT", -btnPad, y)
        btn:SetText(m.name)

        ApplyButtonStyle(btn, {
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
-- Slash Command
-------------------------------------------------
SLASH_XUI1 = "/xui"
---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList["XUI"] = function()
    ToggleConfig()
end

-------------------------------------------------
-- Apply enabled state on login
-------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    for _, m in pairs(BS.modules) do
        if type(m) == "table" and m.name then
            m.db = m.db or EnsureModuleDB(m.name, m.defaults or { enabled = m.enabled ~= false, x = 0, y = 18, fontSize = 20, text = "" })
            if m.enabled == nil then m.enabled = m.db.enabled end

            if m.frame then
                m.frame:SetShown(m.enabled ~= false)
                ApplyModulePosition(m)
                ApplyModuleFont(m)
                ApplyModuleText(m)
            end
        end
    end
end)