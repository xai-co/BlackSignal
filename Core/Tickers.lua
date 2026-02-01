-- Core/Ticker.lua
-- @module Tickers
-- @alias Tickers
local _, BS   = ...;

BS.Tickers    = {}
local Tickers = BS.Tickers

--- Register a ticker for a specific owner
--- @param owner any The owner of the ticker
--- @param interval number The interval in seconds
--- @param func function The function to call on each tick
--- @return nil
function Tickers:Register(owner, interval, func)
  self:Stop(owner)
  self[owner] = C_Timer.NewTicker(interval, func)
end

--- Stop and remove a ticker for a specific owner
--- @param owner any The owner of the ticker
--- @return nil
function Tickers:Stop(owner)
  local t = self[owner]
  if t then
    t:Cancel()
    self[owner] = nil
  end
end
