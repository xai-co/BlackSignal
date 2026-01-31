-- Core/Events.lua
local _, BS = ...;
BS.Events = {}

local Events = BS.Events

function Events:Create()
  return CreateFrame("Frame")
end

local f = Events:Create()

f:SetScript("OnEvent", function(_, event, ...)
  for _, module in pairs(BS.API.modules) do
    if module and module.events and module.events[event] then
      module.events[event](module, ...)
    end
  end
end)

-- Eventos base
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:RegisterEvent("TRAIT_CONFIG_UPDATED")
f:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")

-- Core module: carga módulos al login
BS.API.modules.__core = BS.API.modules.__core or {
  name = "__core",
  enabled = true,
  events = {
    PLAYER_LOGIN = function()
      BS.API:Load()
    end,
  },
}