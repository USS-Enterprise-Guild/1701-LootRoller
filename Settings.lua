-- Settings.lua
-- Configuration state and persistence

LootRoller.Settings = {}

local defaults = {
    enabled = true,
    msRoll = 100,
    osRoll = 99,
    tmogRoll = 98,
    soundEnabled = true,
    autoHideTimeout = 60,
    multiItemMode = "replace",  -- "replace" or "stack"
    debug = false,
    framePosition = nil,  -- saved {point, x, y}
}

function LootRoller.Settings:Initialize()
    -- Create SavedVariables if not exists
    if not LootRoller_Settings then
        LootRoller_Settings = {}
    end

    -- Apply defaults for missing keys
    for key, value in pairs(defaults) do
        if LootRoller_Settings[key] == nil then
            LootRoller_Settings[key] = value
        end
    end
end

function LootRoller.Settings:Get(key)
    return LootRoller_Settings[key]
end

function LootRoller.Settings:Set(key, value)
    LootRoller_Settings[key] = value
end

function LootRoller.Settings:Reset()
    for key, value in pairs(defaults) do
        LootRoller_Settings[key] = value
    end
end
