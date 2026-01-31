-- Core/Ticker.lua
local _, BS = ...;
BS.Tickers = {}

local Tickers = BS.Tickers

function Tickers:Register(owner, interval, func)
  self:Stop(owner)
  self[owner] = C_Timer.NewTicker(interval, func)
end

function Tickers:Stop(owner)
  local t = self[owner]
  if t then
    t:Cancel()
    self[owner] = nil
  end
end