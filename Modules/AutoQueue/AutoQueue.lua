-- Modules/AutoQueue.lua
-- Auto-complete LFG Role Check

local BS = _G.BS
local DB = BS.DB

if not BS and not DB then return end

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
  printOnAccept = true,
}

AutoQueue.defaults = defaults

-------------------------------------------------
-- DB
-------------------------------------------------
local function EnsureDB()
  _G.BlackSignal = _G.BlackSignal or {}
  local db = _G.BlackSignal

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
  print("Attempting to accept role check...")
  if not self.enabled then return end
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
-- Slash
-------------------------------------------------
function AutoQueue:HandleSlash(arg)
  arg = (arg or ""):lower()

  if arg == "" or arg == "toggle" then
    self.db.enabled = not self.db.enabled
    Print("Auto Role Check: " .. (self.db.enabled and "ON" or "OFF"))
    return
  end

  if arg == "on" then
    self.db.enabled = true
    Print("Auto Role Check: ON")
    return
  end

  if arg == "off" then
    self.db.enabled = false
    Print("Auto Role Check: OFF")
    return
  end

  Print("Usage: /bs aq [toggle|on|off]")
end

-------------------------------------------------
-- Init / Apply
-------------------------------------------------
function AutoQueue:OnInit()
  self.db = EnsureDB()

  self.enabled = (self.db.enabled ~= false)

  if not self.eventFrame then
    local f = CreateFrame("Frame")
    self.eventFrame = f
    f:SetScript("OnEvent", function(_, event, ...)
      self:OnEvent(event, ...)
    end)
  end

  self.eventFrame:UnregisterAllEvents()

  if self.enabled then
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
