-- MainPanel.lua
-- @module MainPanel
-- @alias MainPanel

local addonName, BS = ...
BS.MainPanel = BS.MainPanel or {}

local MainPanel = BS.MainPanel

local UI = BS.UI
local ConfigFrame

local PANEL_W = 840 -- Panel width
local PANEL_H = 535 -- Panel height

---------------------------------------------------------------+
----- Main Panel Toggle Functionality
---------------------------------------------------------------+

--- Toggle the main configuration panel
function MainPanel:Toggle()
    local menu = ConfigFrame or MainPanel:CreateMenu()
    menu:SetShown(not menu:IsShown())
end

--- Handle module selection from the left panel
--- @local
--- @param panel Frame table The panel instance
--- @param module table The selected module data
local function onSelectModule(panel, module)
    ---@diagnostic disable-next-line: undefined-field
    if panel and panel.SetActive then
        ---@diagnostic disable-next-line: undefined-field
        panel:SetActive(module and module.name)
    end

    if BS.RightPanel and BS.RightPanel.ShowModule then
        BS.RightPanel:ShowModule(module)
    end
end


--- Create the main configuration menu
--- @return frame Frame The created configuration frame
function MainPanel:CreateMenu()
    --- Create the main configuration frame
    ConfigFrame = CreateFrame("Frame", "BSConfig", UIParent, "BackdropTemplate")
    ConfigFrame:SetSize(PANEL_W, PANEL_H)
    ConfigFrame:SetPoint("CENTER")
    ConfigFrame:SetMovable(true)
    ConfigFrame:EnableMouse(true)
    ConfigFrame:RegisterForDrag("LeftButton")
    ConfigFrame:SetScript("OnDragStart", ConfigFrame.StartMoving)
    ConfigFrame:SetScript("OnDragStop", ConfigFrame.StopMovingOrSizing)
    ConfigFrame:SetFrameStrata("HIGH")

    tinsert(UISpecialFrames, ConfigFrame:GetName())

    ConfigFrame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    ConfigFrame:SetBackdropColor(unpack(BS.Colors.Backdrop.background))
    ConfigFrame:SetBackdropBorderColor(unpack(BS.Colors.Backdrop.border))

    --- Top 5 pixel panel color

    local topPanel = CreateFrame("Frame", "BSConfigTopColor", ConfigFrame, "BackdropTemplate")
    topPanel:SetSize(PANEL_W - 10, 5)
    topPanel:SetPoint("TOP", ConfigFrame, "TOP", 0, -5)

    topPanel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    topPanel:SetBackdropColor(unpack(BS.Colors.Brand.primary))
    topPanel:SetBackdropBorderColor(unpack(BS.Colors.Brand.primary))

    --- Title and Icon header
    local iconPath = "Interface\\AddOns\\BlackSignal\\Media\\icon_64.tga"
    local icon = ConfigFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 60, -19)

    local title = UI:CreateText(ConfigFrame, "BlackSignal", "LEFT", icon, "RIGHT", 6, 0, "GameFontNormalLarge")
    title:SetTextColor(unpack(BS.Colors.Text.normal))

    -- Close button
    local closeIconPath = "Interface\\AddOns\\BlackSignal\\Media\\Close.tga"

    local CloseButton = CreateFrame("Button", nil, ConfigFrame)
    CloseButton:SetSize(12, 12)
    CloseButton:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -16, -24)

    local tex = CloseButton:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    tex:SetTexture(closeIconPath)


    CloseButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

    CloseButton:SetScript("OnClick", function()
        ConfigFrame:Hide()
    end)

    --- Movers button
    local movers = BS.Button:Create("BSConfigMoversButton", ConfigFrame, 80, 25, "Movers", "RIGHT", CloseButton, "LEFT",
    -6, 0)
    movers:SetScript("OnClick", function()
        if BS.Movers and BS.Movers.Toggle then BS.Movers:Toggle() end
    end)

    --- Left panel
    local leftPanel = BS.LeftPanel:Create(ConfigFrame, function(module)
        onSelectModule(leftPanel, module)
    end)

    local version      = C_AddOns.GetAddOnMetadata(addonName, "Version")
    local versionText  = UI:CreateText(ConfigFrame, version, "CENTER", leftPanel, "BOTTOM", 0, -5, "GameFontNormalSmall")
    versionText:SetTextColor(unpack(BS.Colors.Text.normal))

    --- Right panel
    BS.RightPanel:Create(ConfigFrame, leftPanel)

    --- Select the first module by default
    if leftPanel and leftPanel.GetFirstModule then
        local first = leftPanel:GetFirstModule()
        if first then
            onSelectModule(leftPanel, first)
        end
    end

    ConfigFrame:Hide()
    return ConfigFrame
end
