-- Core/DB.lua
local _, BS = ...;
BS.DB = {}

local DB = BS.DB

local function Initialize()
    if not DB.profile then
        DB.profile = { modules = {} }
    end
    return DB
end

function DB:EnsureDB(moduleName, defaults)
    local db = Initialize()

    db.profile = db.profile or {}
    db.profile.modules = db.profile.modules or {}
    db.profile.modules[moduleName] = db.profile.modules[moduleName] or {}

    local mdb = db.profile.modules[moduleName]
    for k, v in pairs(defaults) do
        if mdb[k] == nil then mdb[k] = v end
    end

    return mdb
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "BlackSignal" then
        if not BlackSignalDB then
            BlackSignalDB = {}
        end
        eventFrame:UnregisterEvent("ADDON_LOADED")

        DB = BlackSignalDB

        Initialize()
    end
end)
