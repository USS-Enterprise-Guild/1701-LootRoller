-- LootRoller.lua
-- Main addon file, initialization and namespace

LootRoller = {}
LootRoller.name = "LootRoller"
LootRoller.version = "1.0.0"

-- Create main event frame
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function()
    if event == "ADDON_LOADED" and arg1 == "LootRoller" then
        LootRoller:OnAddonLoaded()
    elseif event == "PLAYER_LOGIN" then
        LootRoller:OnPlayerLogin()
    end
end)

function LootRoller:OnAddonLoaded()
    -- Initialize settings
    LootRoller.Settings:Initialize()
    LootRoller:Print("v" .. self.version .. " loaded. Type /lr for options.")
end

function LootRoller:OnPlayerLogin()
    -- Register detection events after login
    LootRoller.Detection:RegisterEvents()

    -- Pre-create options panel for Interface Options
    LootRoller.Options:CreateOptionsPanel()
end

function LootRoller:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00LootRoller:|r " .. msg)
end

function LootRoller:Debug(msg)
    if LootRoller_Settings and LootRoller_Settings.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888LootRoller Debug:|r " .. msg)
    end
end
