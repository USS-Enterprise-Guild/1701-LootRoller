-- Options.lua
-- Settings UI (slash command + Interface panel)

LootRoller.Options = {}

-- Register slash commands
SLASH_LOOTROLLER1 = "/lootroller"
SLASH_LOOTROLLER2 = "/lr"

SlashCmdList["LOOTROLLER"] = function(msg)
    local cmd = string.lower(msg or "")

    if cmd == "" then
        LootRoller.Options:ToggleOptionsPanel()
    elseif cmd == "toggle" then
        local enabled = not LootRoller.Settings:Get("enabled")
        LootRoller.Settings:Set("enabled", enabled)
        LootRoller:Print("Addon " .. (enabled and "enabled" or "disabled"))
    elseif cmd == "test" then
        LootRoller.Options:ShowTestPopup()
    elseif cmd == "debug" then
        local debug = not LootRoller.Settings:Get("debug")
        LootRoller.Settings:Set("debug", debug)
        LootRoller:Print("Debug mode " .. (debug and "enabled" or "disabled"))
    elseif cmd == "reset" then
        LootRoller.Settings:Reset()
        LootRoller:Print("Settings reset to defaults")
    else
        LootRoller:Print("Commands:")
        LootRoller:Print("  /lr - Open settings")
        LootRoller:Print("  /lr toggle - Enable/disable addon")
        LootRoller:Print("  /lr test - Show test popup")
        LootRoller:Print("  /lr debug - Toggle debug mode")
        LootRoller:Print("  /lr reset - Reset to defaults")
    end
end

function LootRoller.Options:ShowTestPopup()
    -- Test with a known item (Perdition's Blade as example)
    local testItemId = 18816  -- Perdition's Blade
    local testLink = "|cffff8000|Hitem:18816:0:0:0|h[Perdition's Blade]|h|r"

    -- Try to show the item
    LootRoller:Print("Showing test popup...")
    LootRoller.UI:ShowItem(testLink)
end
