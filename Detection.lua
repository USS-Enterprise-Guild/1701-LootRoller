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
    local playerName, roll, minRoll, maxRoll = string.match(message, "(.+) rolls (%d+) %((%d+)%-(%d+)%)")

    if playerName and roll then
        LootRoller:Debug("Roll detected: " .. playerName .. " rolled " .. roll .. " (1-" .. maxRoll .. ")")

        -- Check if this could be a winning roll (loot master announces winner)
        -- For now, we just track rolls. The popup auto-closes on new item or timeout.
    end
end

-- Track current item being rolled on
local currentItemId = nil

function LootRoller.Detection:SetCurrentItem(itemId)
    currentItemId = itemId
end

function LootRoller.Detection:GetCurrentItem()
    return currentItemId
end

-- Clean up old dedupe entries periodically
local function CleanupRecentItems()
    local now = GetTime()
    for itemId, timestamp in pairs(recentItems) do
        if (now - timestamp) > DEDUPE_WINDOW * 2 then
            recentItems[itemId] = nil
        end
    end
end

-- Run cleanup every 30 seconds
local cleanupFrame = CreateFrame("Frame")
cleanupFrame.elapsed = 0
cleanupFrame:SetScript("OnUpdate", function()
    this.elapsed = this.elapsed + arg1
    if this.elapsed > 30 then
        CleanupRecentItems()
        this.elapsed = 0
    end
end)

-- Known RollFor addon prefixes to listen for
local ROLLFOR_PREFIXES = {
    "RollFor",
    "RF",
}

function LootRoller.Detection:ParseAddonMessage(prefix, message, channel, sender)
    -- Check if this is from RollFor
    local isRollFor = false
    for _, rfPrefix in ipairs(ROLLFOR_PREFIXES) do
        if prefix == rfPrefix then
            isRollFor = true
            break
        end
    end

    if not isRollFor then return end

    LootRoller:Debug("RollFor message: " .. (message or "nil") .. " from " .. (sender or "unknown"))

    -- Try to parse item link from message
    -- RollFor may send item links in various formats
    local fullLink = string.match(message, "(|c%x+|Hitem:.+|h%[.-%]|h|r)")

    if fullLink then
        self:OnItemAnnounced(fullLink)
    end
end

-- Enable/disable detection
function LootRoller.Detection:SetEnabled(enabled)
    if enabled then
        self:RegisterEvents()
    else
        if self.frame then
            self.frame:UnregisterAllEvents()
        end
    end
end
