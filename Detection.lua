-- Detection.lua
-- Listens for item announcements via chat and addon messages

LootRoller.Detection = {}

local recentItems = {}  -- tracks recently seen items for deduplication
local DEDUPE_WINDOW = 3  -- seconds

function LootRoller.Detection:RegisterEvents()
    if not LootRoller.Settings:Get("enabled") then return end

    local frame = CreateFrame("Frame")
    self.frame = frame

    -- Chat events for item links
    frame:RegisterEvent("CHAT_MSG_RAID")
    frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
    frame:RegisterEvent("CHAT_MSG_RAID_WARNING")
    frame:RegisterEvent("CHAT_MSG_PARTY")

    -- System messages for roll results
    frame:RegisterEvent("CHAT_MSG_SYSTEM")

    -- Addon messages for RollFor integration
    frame:RegisterEvent("CHAT_MSG_ADDON")

    frame:SetScript("OnEvent", function()
        LootRoller.Detection:OnEvent(event, arg1, arg2, arg3, arg4)
    end)

    LootRoller:Debug("Detection events registered")
end

function LootRoller.Detection:OnEvent(event, arg1, arg2, arg3, arg4)
    if event == "CHAT_MSG_RAID" or event == "CHAT_MSG_RAID_LEADER"
       or event == "CHAT_MSG_RAID_WARNING" or event == "CHAT_MSG_PARTY" then
        self:ParseChatForItems(arg1)
    elseif event == "CHAT_MSG_SYSTEM" then
        self:ParseRollResult(arg1)
    elseif event == "CHAT_MSG_ADDON" then
        self:ParseAddonMessage(arg1, arg2, arg3, arg4)
    end
end

function LootRoller.Detection:ParseChatForItems(message)
    if not message then return end

    -- Pattern for item links: |cffxxxxxx|Hitem:itemId:...|h[Name]|h|r
    local itemLink = string.match(message, "|c%x+|Hitem:(%d+).-|h%[.-%]|h|r")

    if itemLink then
        -- Extract full item link for display
        local fullLink = string.match(message, "(|c%x+|Hitem:.+|h%[.-%]|h|r)")
        if fullLink then
            self:OnItemAnnounced(fullLink)
        end
    end
end

function LootRoller.Detection:OnItemAnnounced(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end

    -- Deduplicate within time window
    local itemId = self:GetItemIdFromLink(itemLink)
    local now = GetTime()

    if recentItems[itemId] and (now - recentItems[itemId]) < DEDUPE_WINDOW then
        LootRoller:Debug("Deduplicating item: " .. itemId)
        return
    end

    recentItems[itemId] = now

    LootRoller:Debug("Item announced: " .. itemLink)

    -- Trigger UI popup
    LootRoller.UI:ShowItem(itemLink)
end

function LootRoller.Detection:GetItemIdFromLink(itemLink)
    local itemId = string.match(itemLink, "item:(%d+)")
    return itemId or "unknown"
end

function LootRoller.Detection:ParseRollResult(message)
    -- Pattern: "PlayerName rolls X (1-Y)"
    -- Used to detect when a roll is resolved
    -- TODO: Implement roll resolution detection
end

function LootRoller.Detection:ParseAddonMessage(prefix, message, channel, sender)
    -- TODO: RollFor addon message integration
    -- Need to identify RollFor's addon prefix
end
