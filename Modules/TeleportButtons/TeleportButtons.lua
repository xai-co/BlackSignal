-- Modules/TeleportButtons/TeleportButtons.lua
-- @module TeleportButtons
-- @alias TeleportButtons
local _, BS = ...;

local API   = BS.API
local DB    = BS.DB

local TeleportButtons = {
  name = "TeleportButtons",
  enabled = true,
  events = {},
}

API:Register(TeleportButtons)

-------------------------------------------------
--  Config 
-------------------------------------------------
local BUTTON_SIZE = 32
local BUTTON_GAP  = 2
local MAX_ROWS    = 8
local OFFSET_X    = -10
local OFFSET_Y    = -30
local FONT_PATH   = "Fonts\\FRIZQT__.TTF"
local FONT_SIZE   = 12

-------------------------------------------------
--  Season data (ACTUAL)
-- TODO: hacer dinámico en el futuro
-------------------------------------------------
local SEASON_SPELLS = {
  {445417, "ARA"},
  {445414, "DB"},
  {1237215, "ECO"},
  {354465, "HOA"},
  {1216786, "FLOOD"},
  {445444, "PRIO"},
  {367416, "TZV"},
}

-------------------------------------------------
-- Helpers: ChallengesFrame
-------------------------------------------------
local function EnsureChallengesUI()
  if C_AddOns and C_AddOns.LoadAddOn then
    if not C_AddOns.IsAddOnLoaded("Blizzard_ChallengesUI") then
      C_AddOns.LoadAddOn("Blizzard_ChallengesUI")
    end
  elseif LoadAddOn then
    if not IsAddOnLoaded("Blizzard_ChallengesUI") then
      LoadAddOn("Blizzard_ChallengesUI")
    end
  end
end

local function GetAnchorFrame()
  EnsureChallengesUI()
  return _G.ChallengesFrame or UIParent
end

-------------------------------------------------
-- PVEFrame anchor-family fix (anti WindTools)
-------------------------------------------------
local function IsBadRelative(frame, rel)
  if not frame or not rel then return false end
  if rel == frame then return true end

  local move = frame.MoveFrame or _G.PVEFrameMoveFrame
  if move and rel == move then return true end

  if rel.IsDescendantOf and rel:IsDescendantOf(frame) then
    return true
  end
  return false
end

local function FixPVEFrameAnchor()
  local f = _G.PVEFrame
  if not f or not f.GetPoint or InCombatLockdown() then return end

  local _, rel = f:GetPoint(1)
  if not rel or not IsBadRelative(f, rel) then return end

  local left, top = f:GetLeft(), f:GetTop()
  f:ClearAllPoints()

  if left and top and UIParent:GetLeft() and UIParent:GetTop() then
    f:SetPoint(
      "TOPLEFT",
      UIParent,
      "TOPLEFT",
      left - UIParent:GetLeft(),
      top - UIParent:GetTop()
    )
  else
    f:SetPoint("CENTER")
  end
end

-------------------------------------------------
-- Spell helpers (Retail-safe)
-------------------------------------------------
local function GetSpellTextureByID(spellID)
  if C_Spell and C_Spell.GetSpellTexture then
    local t = C_Spell.GetSpellTexture(spellID)
    if t then return t end
  end
  if _G.GetSpellTexture then
    local t = GetSpellTexture(spellID)
    if t then return t end
  end
  return [[Interface\Icons\INV_Misc_QuestionMark]]
end

local function IsKnownOrAlwaysShow(spellID)
  -- IsSpellKnown suele seguir existiendo, pero lo protegemos
  if IsSpellKnown then
    return IsSpellKnown(spellID)
  end
  -- si no existe, asumimos true para no romper (verás el botón)
  return true
end

-------------------------------------------------
-- UI
-------------------------------------------------
local function EnsureFrame(self)
  if self.container then return end

  local f = CreateFrame("Frame", "BS_TeleportButtons", UIParent)
  f:Hide()

  self.container = f
  self.buttons = {}
end

local function ApplyAnchor(self)
  local anchor = GetAnchorFrame()
  self.container:SetParent(anchor)
  self.container:ClearAllPoints()
  self.container:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", OFFSET_X, OFFSET_Y)
end

local function ClearButtons(self)
  for _, b in ipairs(self.buttons) do
    b:Hide()
    b:ClearAllPoints()
  end
  wipe(self.buttons)
end

local function BuildButtons(self)
  ClearButtons(self)

  local col, row = 1, 0

  for _, entry in ipairs(SEASON_SPELLS) do
    local spellId, label = entry[1], entry[2]
    if spellId and (IsKnownOrAlwaysShow(spellId)) then
      local b = CreateFrame("Button", nil, self.container, "InsecureActionButtonTemplate")
      b:SetAttribute("type", "spell")
      b:SetAttribute("spell", spellId)
      b:SetAttribute("unit", "player")
      b:RegisterForClicks("LeftButtonUp", "LeftButtonDown")

      b:SetSize(BUTTON_SIZE, BUTTON_SIZE)
      b:SetNormalTexture(GetSpellTextureByID(spellId))
      b:SetHighlightTexture([[Interface\QuestFrame\UI-QuestTitleHighlight]], "ADD")

      -- Tooltip FIX (no SetPoint)
      b:SetScript("OnEnter", function(btn)
        GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
        GameTooltip:SetSpellByID(spellId)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function() GameTooltip:Hide() end)

      b.text = b:CreateFontString(nil, "OVERLAY")
      b.text:SetFont(FONT_PATH, FONT_SIZE, "OUTLINE")
      b.text:SetPoint("CENTER", b, "TOP", 0, -2)
      b.text:SetText(label or "")

      if row >= MAX_ROWS then
        col = col + 1
        row = 0
      end

      b:SetPoint(
        "TOPLEFT",
        self.container,
        "TOPLEFT",
        (col - 1) * (BUTTON_SIZE + BUTTON_GAP),
        -row * (BUTTON_SIZE + BUTTON_GAP)
      )

      self.buttons[#self.buttons + 1] = b
      row = row + 1
    end
  end

  -- Ajuste tamaño del contenedor
  local usedCols = math.max(col, 1)
  local usedRows = math.min(MAX_ROWS, math.max(row, 1))

  local w = usedCols * BUTTON_SIZE + math.max(0, usedCols - 1) * BUTTON_GAP
  local h = usedRows * BUTTON_SIZE + math.max(0, usedRows - 1) * BUTTON_GAP
  self.container:SetSize(w, h)
end

local function RefreshVisibility(self)
  if not self.container then return end
  if not self.db or self.db.enabled == false then
    self.container:Hide()
    return
  end

  local cf = _G.ChallengesFrame
  self.container:SetShown(cf and cf:IsShown())
end

local function SetupHooks(self)
  if self._hooksDone then return end
  self._hooksDone = true

  EnsureChallengesUI()
  local cf = _G.ChallengesFrame
  if not cf then return end

  cf:HookScript("OnShow", function()
    if not self or not self.db or self.db.enabled == false then return end
    if not InCombatLockdown() then
      ApplyAnchor(self)
      BuildButtons(self)
    end
    RefreshVisibility(self)
  end)

  cf:HookScript("OnHide", function()
    if not self or not self.db then return end
    RefreshVisibility(self)
  end)
end

-------------------------------------------------
-- Init / Apply
-------------------------------------------------
function TeleportButtons:OnInit()
  self.db = DB:EnsureDB(self.name, { enabled = true })
  self.enabled = (self.db.enabled ~= false)

  EnsureFrame(self)
  FixPVEFrameAnchor()
  SetupHooks(self)

  if not self.enabled then
    if self.container then self.container:Hide() end
    return
  end

  if not InCombatLockdown() then
    ApplyAnchor(self)
    BuildButtons(self)
  end

  RefreshVisibility(self)
end

function TeleportButtons:Apply()
  if not self.db then self.db = DB:EnsureDB(self.name, { enabled = true }) end
  self.enabled = (self.db.enabled ~= false)

  FixPVEFrameAnchor()

  if not self.enabled then
    if self.container then self.container:Hide() end
    return
  end

  if not InCombatLockdown() then
    ApplyAnchor(self)
    BuildButtons(self)
  end

  RefreshVisibility(self)
end
