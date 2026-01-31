-- Core/API.lua
local _, BS = ...;
BS.API = {}

local API = BS.API
API.modules = {}

function API:Register(module)
  if type(module) ~= "table" or not module.name then return end
  self.modules[module.name] = module
end

function API:Load()
  local _, class = UnitClass("player")

  for _, module in pairs(self.modules) do
    if module.enabled ~= false then
      if not module.classes or module.classes == class then
        if module.OnInit and not module.__initialized then
          module.__initialized = true
          module:OnInit()
        elseif module.OnInit and module.__initialized and module.OnReload then
          module:OnReload()
        end
      end
    end
  end
end
