-- Modules/AutoQueue.lua
-- Auto-complete LFG Role Check

local BS = _G.BS
if not BS then return end

local AutoQueue = {
  name = "AutoQueue",
  enabled = true,
  events = {},
}

BS:RegisterModule(AutoQueue)

-------------------------------------------------
-- Defaults
-------------------------------------------------
local defaults = {
  enabled = true,
  active = true,
  printOnAccept = true,
}

AutoQueue.defaults = defaults

-------------------------------------------------
-- DB
-------------------------------------------------
local function EnsureDB()
  _G.BS_DB = _G.BS_DB or {}
  local db = _G.BS_DB

  db.profile = db.profile or {}
  db.profile.modules = db.profile.modules or {}
  db.profile.modules.AutoQueue = db.profile.modules.AutoQueue or {}

  local mdb = db.profile.modules.AutoQueue
  for k, v in pairs(defaults) do
    if mdb[k] == nil then mdb[k] = v end
  end
  
  return mdb
end

-------------------------------------------------
-- Utils
-------------------------------------------------
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffb048f8BS AutoQueue:|r " .. tostring(msg))
end

-------------------------------------------------
-- Core: Role check accept
-------------------------------------------------
function AutoQueue:TryCompleteRoleCheck()
  if not self.db.enabled or not self.db.active then return end
  if not CompleteLFGRoleCheck then return end

  local ok, err = pcall(CompleteLFGRoleCheck, true)
  if ok then
    if self.db.printOnAccept then
      Print("Role check accepted.")
    end
  else
    Print("Role check accept failed: " .. tostring(err))
  end
end

function AutoQueue:OnEvent(event, ...)
  if event == "LFG_ROLE_CHECK_SHOW" then
    self:TryCompleteRoleCheck()
  end
end

-------------------------------------------------
-- Slash handler (called by /xui router in Core/Config.lua)
-------------------------------------------------
function AutoQueue:HandleSlash(arg)
  arg = (arg or ""):lower()

  if arg == "" or arg == "toggle" then
    self.db.active = not self.db.active
    Print("Auto Role Check: " .. (self.db.active and "ON" or "OFF"))
    return
  end

  if arg == "on" then
    self.db.active = true
    Print("Auto Role Check: ON")
    return
  end

  if arg == "off" then
    self.db.active = false
    Print("Auto Role Check: OFF")
    return
  end

  Print("Usage: /xui aq [toggle|on|off]")
end

-------------------------------------------------
-- Init / Apply
-------------------------------------------------
function AutoQueue:OnInit()
  self.db = EnsureDB()

  if not self.eventFrame then
    local f = CreateFrame("Frame")
    self.eventFrame = f
    f:SetScript("OnEvent", function(_, event, ...)
      self:OnEvent(event, ...)
    end)
  end

  self.eventFrame:UnregisterAllEvents()

  if self.db.enabled then
    self.eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
  end
end

function AutoQueue:Apply()
  if not self.db then self.db = EnsureDB() end

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    if self.db.enabled then
      self.eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
    end
  end
end