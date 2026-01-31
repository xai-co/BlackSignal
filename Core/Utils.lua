-- Core/Utils.lua
local _, BS = ...;
BS.Utils = {}

local Utils = BS.Utils

function Utils:IsValidNumber(v)
    return v ~= nil and type(v) == "number"
end
