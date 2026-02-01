-- Modules/AutoQueue.lua
-- @module AutoQueue
-- @alias AutoQueue

local _, BS = ...;

local DB    = BS.DB

local AutoQueue = {
  name = "AutoQueue",
  enabled = true,
  events = {},
}

BS.API:Register(AutoQueue)

-------------------------------------------------
-- Defaults
-------------------------------------------------
local defaults = {
  enabled = true,
  printOnAccept = true,
}

AutoQueue.defaults = defaults

-------------------------------------------------
-- Utils
-------------------------------------------------
--- Print message to chat frame
--- @local
--- @param msg string The message to print
--- @return nil
-------------------------------------------------
local function Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage("|cffb048f8BS AutoQueue:|r " .. tostring(msg))
end

-------------------------------------------------
-- Core: Role check accept
-------------------------------------------------
--- Try to complete the role check
--- @return nil
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

-------------------------------------------------
--- Event Handler
--- @param event string The event name
--- @param ... any Additional event arguments
--- @return nil
-------------------------------------------------
function AutoQueue:OnEvent(event, ...)
  if event == "LFG_ROLE_CHECK_SHOW" then
    self:TryCompleteRoleCheck()
  end
end

-------------------------------------------------
-- Slash
-------------------------------------------------
--- Handle slash commands
--- @param arg string The slash command argument
--- @return nil
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
  self.db = DB:EnsureDB(self.name, self.defaults)

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

-------------------------------------------------
--- Apply configuration changes
--- @return nil
-------------------------------------------------
function AutoQueue:Apply()
  if not self.db then self.db = DB:EnsureDB(self.name, self.defaults) end

  if self.eventFrame then
    self.eventFrame:UnregisterAllEvents()
    if self.db.enabled then
      self.eventFrame:RegisterEvent("LFG_ROLE_CHECK_SHOW")
    end
  end
end
