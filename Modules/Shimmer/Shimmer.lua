-- Modules/Shimmer.lua
-- @module Shimmer
-- @alias Shimmer

local _, BS   = ...;

local API     = BS.API
local Events  = BS.Events


local Shimmer = {
  name = "Shimmer",
  enabled = true,
  classes = "MAGE",
  events = {},
}

API:Register(Shimmer)

-------------------------------------------------
-- Constants
-------------------------------------------------
local GetSpellCooldown = C_Spell.GetSpellCooldown
local BLINK_ID         = 1953
local SHIMMER_ID       = 212653

local defaults         = {
  enabled  = true,
  x        = 0,
  y        = 18,
  fontSize = 20,
  text     = "No Shimmer: ",
  font     = "Fonts\\FRIZQT__.TTF"
}

-------------------------------------------------
-- UI
-------------------------------------------------
local function EnsureUI(self)
  if self.frame and self.text then return end

  local displayFrame = CreateFrame("Frame", "BS_ShimmerDisplay", UIParent)
  displayFrame:SetSize(400, 30)
  displayFrame:SetFrameStrata("LOW")
  displayFrame:Show()

  local statusText = displayFrame:CreateFontString(nil, "OVERLAY")
  statusText:SetPoint("CENTER")
  statusText:SetJustifyH("CENTER")
  statusText:SetTextColor(1, 1, 1, 1)

  self.frame = displayFrame
  self.text = statusText
end

local function ApplyPosition(self)
  if not self.frame or not self.db then return end
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", self.db.x or 0, self.db.y or 18)
end

local function ApplyFont(self)
  if not self.text or not self.db then return end
  self.text:SetFont(self.db.font, tonumber(self.db.fontSize) or 20, "OUTLINE")
end

-------------------------------------------------
-- Spell selection
-------------------------------------------------
--- Resolve which spell ID to use based on talents
--- @return nil
-------------------------------------------------
function Shimmer:ResolveSpell()
  if C_SpellBook.IsSpellKnown(SHIMMER_ID) then
    self.spellID = SHIMMER_ID
  else
    self.spellID = BLINK_ID
  end
end

-------------------------------------------------
-- Update
-------------------------------------------------
--- Update the shimmer display
--- @return nil
-------------------------------------------------
function Shimmer:Update()
  if not self.db or self.db.enabled == false then return end
  if not self.spellID or not self.frame or not self.text then return end

  local durationObject = C_Spell.GetSpellCooldownDuration(self.spellID)
  ---@diagnostic disable-next-line: undefined-field
  if not durationObject or not durationObject.GetRemainingDuration then return end

  ---@diagnostic disable-next-line: undefined-field
  local actualCooldown = durationObject:GetRemainingDuration(1)

  local prefix = self.db.text or defaults.text

  local cdInfo = GetSpellCooldown(self.spellID)
  local isOnGCD = cdInfo and cdInfo.isOnGCD

  if self.frame.SetAlphaFromBoolean then
    self.frame:SetAlphaFromBoolean(isOnGCD ~= false, 0, 1)
  else
    self.frame:SetAlpha((isOnGCD ~= false) and 1 or 0)
  end

  self.text:SetText(string.format("%s%.1f", prefix, actualCooldown))
end

-------------------------------------------------
-- Ticker
-------------------------------------------------
--- Start the update ticker
--- @return nil
-------------------------------------------------
function Shimmer:StartTicker()
  BS.Tickers:Stop(self)
  BS.Tickers:Register(self, 0.1, function()
    self:Update()
  end)
end

-------------------------------------------------
-- Init
-------------------------------------------------
function Shimmer:OnInit()
  self.db = BS.DB:EnsureDB(self.name, defaults)

  self.enabled = (self.db.enabled ~= false)

  EnsureUI(self)
  ApplyPosition(self)
  ApplyFont(self)
  BS.Movers:Register(self.frame, self.name, "Shimmer Text")

  self:ResolveSpell()
  self.frame:SetShown(self.enabled)

  if self.enabled then
    self:StartTicker()
    self:Update()
  else
    BS.Tickers:Stop(self)
  end

  Events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
end

-------------------------------------------------
-- Events
-------------------------------------------------
Shimmer.events.SPELL_UPDATE_COOLDOWN = function(self)
  self:Update()
end

local function TalentUpdate(self)
  C_Timer.After(0.5, function()
    self:ResolveSpell()
  end)
  C_Timer.After(0.6, function()
    if self.enabled then
      self:StartTicker()
      self:Update()
    end
  end)
end

Shimmer.events.PLAYER_SPECIALIZATION_CHANGED = TalentUpdate
Shimmer.events.TRAIT_CONFIG_UPDATED          = TalentUpdate
Shimmer.events.ACTIVE_TALENT_GROUP_CHANGED   = TalentUpdate
