-- Core/Config.lua
local _, BS = ...

local DB = BS.DB
local UI = BS.UI

if not DB or not UI then
    error("BS: Missing Core/DB.lua or Core/UI.lua. Check .toc load order (DB.lua, UI.lua, then Config.lua).")
end

-------------------------------------------------
-- Slash command
-------------------------------------------------
SLASH_BS1 = "/bs"
---@diagnostic disable-next-line: duplicate-set-field
SlashCmdList["BS"] = function(msg)
    msg = (msg or ""):match("^%s*(.-)%s*$")

    if msg == "" then
        BS.MainPanel:Toggle()
        return
    end

    local cmd, rest = msg:match("^(%S+)%s*(.-)$")
    cmd = (cmd or ""):lower()
    rest = rest or ""

    if cmd == "config" then
        BS.MainPanel:Toggle()
        return
    end

    if cmd == "aq" or cmd == "autoqueue" then
        local m = BS.API.modules and BS.API.modules.AutoQueue
        if m and m.HandleSlash then
            m:HandleSlash(rest)
        else
            print("|cffb048f8BS:|r AutoQueue no está cargado.")
        end
        return
    end

    if cmd == "movers" then
        if not (BS.Movers and BS.Movers.Toggle) then
            print("|cffb048f8BS:|r Movers no está disponible ")
            return
        end

        local sub = (rest or ""):lower()
        sub = sub:match("^%s*(.-)%s*$")

        if sub == "" or sub == "toggle" then
            BS.Movers:Toggle()
            return
        end

        if sub == "on" or sub == "unlock" or sub == "show" then
            BS.Movers:Unlock()
            return
        end

        if sub == "off" or sub == "lock" or sub == "hide" then
            BS.Movers:Lock()
            return
        end

        if sub == "reset" then
            BS.Movers:ResetAll()
            print("|cffb048f8BS:|r Movers reseteados.")
            return
        end

        print("|cffb048f8BS:|r Uso: /bs movers [toggle|on|off|reset]")
        return
    end

    print("|cffb048f8BS:|r Comandos: /bs (config), /bs aq [toggle|on|off], /bs movers [toggle|on|off|reset]")
end

-------------------------------------------------
-- Apply enabled state on login (capability-aware)
-- (se mantiene aquí porque es “bootstrap”)
-------------------------------------------------
local function HasKey(t, k) return type(t) == "table" and t[k] ~= nil end

local function SupportsPosition(module, defaults)
    if module and module.frame then return true end
    if HasKey(defaults, "x") or HasKey(defaults, "y") then return true end
    if module and module.db and (HasKey(module.db, "x") or HasKey(module.db, "y")) then return true end
    return false
end

local function SupportsFont(module, defaults)
    if module and module.text and module.text.SetFont then return true end
    if HasKey(defaults, "font") or HasKey(defaults, "fontSize") or HasKey(defaults, "fontFlags") then return true end
    return false
end

local function NormalizeFontPath(p)
    if type(p) ~= "string" then return nil end
    p = p:gsub("/", "\\")
    p = p:gsub("^%s+", ""):gsub("%s+$", "")
    if p == "" then return nil end
    return p
end

local function EnsureFontDefaults(module, defaults)
    module.db = module.db or {}
    if module.db.font == nil then
        module.db.font = NormalizeFontPath(defaults and defaults.font) or "Fonts\\FRIZQT__.TTF"
    end
    if module.db.fontSize == nil and defaults and defaults.fontSize ~= nil then
        module.db.fontSize = defaults.fontSize
    end
    if module.db.fontFlags == nil and defaults and defaults.fontFlags ~= nil then
        module.db.fontFlags = defaults.fontFlags
    end
end

local function ApplyModulePosition(module)
    if not module or not module.frame or not module.db then return end
    local x = tonumber(module.db.x or 0) or 0
    local y = tonumber(module.db.y or 0) or 0
    module.frame:ClearAllPoints()
    module.frame:SetPoint("CENTER", UIParent, "CENTER", x, y)
end

local function ApplyModuleFont(module)
    if not module or not module.text or not module.text.SetFont or not module.db then return end
    local size  = tonumber(module.db.fontSize) or 20
    local font  = NormalizeFontPath(module.db.font) or "Fonts\\FRIZQT__.TTF"
    local flags = module.db.fontFlags or "OUTLINE"
    module.text:SetFont(font, size, flags)
end

local function ApplyModuleText(module)
    if module and module.Update then module:Update() end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if not (BS.API and BS.API.modules) then return end

    for _, m in pairs(BS.API.modules) do
        if type(m) == "table" and m.name then
            local defaults = m.defaults or { enabled = true }

            m.db = m.db or BS.DB:EnsureDB(m.name, defaults)
            if m.enabled == nil then m.enabled = (m.db.enabled ~= false) end

            if SupportsFont(m, defaults) then
                EnsureFontDefaults(m, defaults)
            end

            if m.frame then
                m.frame:SetShown(m.enabled ~= false)

                if SupportsPosition(m, defaults) then
                    ApplyModulePosition(m)
                end

                if SupportsFont(m, defaults) then
                    ApplyModuleFont(m)
                end

                ApplyModuleText(m)
            end
        end
    end
end)
