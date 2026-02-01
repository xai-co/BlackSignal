-- Core/Events.lua
-- @module Events
-- @alias Events

local _, BS  = ...;

BS.Events    = BS.Events or CreateFrame("Frame")

--- Event frame to handle and dispatch events to modules
local f = BS.Events

--- Event handler to dispatch events to registered module event handlers
f:SetScript("OnEvent", function(_, event, ...)
  for _, module in pairs(BS.API.modules) do
    if module and module.events and module.events[event] then
      module.events[event](module, ...)
    end
  end
end)

--- Register events to the event frames
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

--- Core module to handle core events
BS.API.modules.__core = BS.API.modules.__core or {
  name = "__core",
  enabled = true,
  events = {
    PLAYER_LOGIN = function()
      BS.API:Load()
    end,
  },
}
