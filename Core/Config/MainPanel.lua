-- MainPanel.lua
local _, BS = ...
BS.MainPanel = BS.MainPanel or {}

local MainPanel = BS.MainPanel

local UI = BS.UI
local ConfigFrame

local PANEL_W, PANEL_H = 840, 535

function MainPanel:Toggle()
    local menu = ConfigFrame or MainPanel:CreateMenu()
    menu:SetShown(not menu:IsShown())
end

local function onSelectModule(leftPanel, module)
    if leftPanel and leftPanel.SetActive then
        leftPanel:SetActive(module and module.name)
    end
    if BS.RightPanel and BS.RightPanel.ShowModule then
        BS.RightPanel:ShowModule(module)
    end
end

function MainPanel:CreateMenu()
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

    -- Title + Icon
    local iconPath = "Interface\\AddOns\\BlackSignal\\Media\\icon_64.tga"
    local icon = ConfigFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetTexture(iconPath)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", ConfigFrame, "TOPLEFT", 60, -14)

    local title = UI:CreateText(ConfigFrame, "BlackSignal", "LEFT", icon, "RIGHT", 6, 0, "GameFontNormalLarge")
    title:SetTextColor(unpack(BS.Colors.Text.normal))

    -- Close
    local close = CreateFrame("Button", nil, ConfigFrame)
    close:SetSize(32, 32)
    close:SetPoint("TOPRIGHT", ConfigFrame, "TOPRIGHT", -8, -8)
    close:SetNormalFontObject("GameFontHighlight")
    close:SetText("X")
    close:GetFontString():SetTextColor(1, 1, 1, 1)
    close:SetScript("OnClick", function() ConfigFrame:Hide() end)
    close:SetScript("OnEnter", function(self) self:GetFontString():SetTextColor(1, 0.3, 0.3, 1) end)
    close:SetScript("OnLeave", function(self) self:GetFontString():SetTextColor(1, 1, 1, 1) end)

    -- Movers
    local movers = BS.Button:Create("BSConfigMoversButton", ConfigFrame, 80, 25, "Movers", "RIGHT", close, "LEFT", -6, 0)
    movers:SetScript("OnClick", function()
        if BS.Movers and BS.Movers.Toggle then BS.Movers:Toggle() end
    end)

    -- Left panel
    local leftPanel = BS.LeftPanel:Create(ConfigFrame, function(module)
        onSelectModule(leftPanel, module)
    end)

    -- Right panel
    BS.RightPanel:Create(ConfigFrame, leftPanel)

    -- Select first module by default
    if leftPanel and leftPanel.GetFirstModule then
        local first = leftPanel:GetFirstModule()
        if first then
            onSelectModule(leftPanel, first)
        end
    end

    ConfigFrame:Hide()
    return ConfigFrame
end
