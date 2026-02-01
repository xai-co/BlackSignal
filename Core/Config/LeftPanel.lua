-- LeftPanel.lua
-- @module LeftPanel
-- @alias LeftPanel
local _, BS = ...

BS.LeftPanel    = BS.LeftPanel or {}
local LeftPanel = BS.LeftPanel

local WIDTH         = 235 -- Panel width
local BUTTON_H      = 26  -- Button height
local BUTTON_GAP    = 6   -- Gap between buttons
local BUTTON_PAD    = 5   -- Button padding


--- Get an ordered list of modules from the modules table
--- @local
--- @param modulesTable table The table containing module data
--- @return table table The ordered list of modules
local function OrderedModules(modulesTable)
    local list = {}
    if type(modulesTable) ~= "table" then return list end

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


--- Create the left panel for module selection
--- @param parent Frame table The parent frame to attach the left panel
--- @param onClick function The callback function when a module button is clicked
--- @return frame Frame The created left panel frame
function LeftPanel:Create(parent, onClick)
    local panel = CreateFrame("Frame", "BSLeftPanel", parent, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -58)
    panel:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 14, 14)
    panel:SetWidth(WIDTH)

    BS.UI:ApplyPanelStyle(panel, 0.20, 1)

    panel._bsButtons = {}
    panel._bsModules = OrderedModules(BS.API and BS.API.modules)

    local y = -8

    for _, m in ipairs(panel._bsModules) do
        m.db = m.db or BS.DB:EnsureDB(m.name, m.defaults or { enabled = true })
        if m.enabled == nil then m.enabled = m.db.enabled end

        local btn = BS.Button:Create(nil, panel, 1, BUTTON_H, m.name, "TOPLEFT", panel, "TOPLEFT", BUTTON_PAD, y)
        btn:SetPoint("TOPLEFT", panel, "TOPLEFT", BUTTON_PAD, y)
        btn:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -BUTTON_PAD, y)

        if not btn.SetActive then
            function btn:SetActive(isActive)
                self._active = isActive and true or false
                if self._active and self.SetBackdropBorderColor then
                    self:SetBackdropBorderColor(unpack(BS.Colors.Button.borderHover or { 0.2, 0.6, 1, 1 }))
                end
            end
        end

        btn:SetScript("OnClick", function()
            panel:SetActive(m.name)
            if onClick and type(onClick) == "function" then
                onClick(m)
            end
        end)

        panel._bsButtons[m.name] = btn
        y = y - (BUTTON_H + BUTTON_GAP)
    end

    --- Set the active module button
    --- @local
    --- @param name string The module name to set as active
    function panel:SetActive(name)
        for n, b in pairs(self._bsButtons) do
            if b and b.SetActive then
                b:SetActive(n == name)
            end
        end
    end

    --- Get the first module in the list
    --- @local
    --- @return table table The first module data
    function panel:GetFirstModule()
        return self._bsModules and self._bsModules[1]
    end

    return panel
end
