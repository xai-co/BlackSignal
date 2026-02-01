-- Core/DB.lua
-- @module DB
-- @alias DB

local _, BS = ...;

BS.DB       = {}
local DB    = BS.DB

--- Initialize the database structure
--- @local
--- @return table DB The initialized database
local function Initialize()
    if not DB.profile then
        DB.profile = { modules = {} }
    end
    return DB
end

--- Ensure the database for a specific module with defaults
--- @param moduleName string The module name
--- @param defaults table The default values for the moduleName
--- @return table The ensured database for the moduleName
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

--- Load the database from the saved variables
local eventFrame = CreateFrame("Frame")

--- Handle the ADDON_LOADED event to initialize the database
eventFrame:RegisterEvent("ADDON_LOADED")

--- Event handler for ADDON_LOADED
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
