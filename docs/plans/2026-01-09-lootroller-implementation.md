# LootRoller Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a RollFor companion addon that displays item announcements with stat comparison and quick-roll buttons.

**Architecture:** Event-driven Lua addon. Detection module listens for items, Comparison module calculates stat diffs, UI module displays popup with roll buttons. Settings persist via SavedVariables.

**Tech Stack:** WoW 1.12.1 Lua API, XML for frame templates (optional), tooltip scanning for stat extraction.

---

## Task 1: Create Addon Skeleton

**Files:**
- Create: `LootRoller.toc`
- Create: `LootRoller.lua`

**Step 1: Create TOC file**

```toc
## Interface: 11200
## Title: LootRoller
## Notes: RollFor companion - shows item comparison and quick roll buttons
## Author: USS Enterprise Guild
## Version: 1.0.0
## SavedVariables: LootRoller_Settings

LootRoller.lua
Settings.lua
Detection.lua
Comparison.lua
UI.lua
Options.lua
```

**Step 2: Create main addon file with namespace**

```lua
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
end

function LootRoller:Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00LootRoller:|r " .. msg)
end

function LootRoller:Debug(msg)
    if LootRoller_Settings and LootRoller_Settings.debug then
        DEFAULT_CHAT_FRAME:AddMessage("|cff888888LootRoller Debug:|r " .. msg)
    end
end
```

**Step 3: Commit**

```bash
git add LootRoller.toc LootRoller.lua
git commit -m "feat: create addon skeleton with TOC and main file"
```

---

## Task 2: Create Settings Module

**Files:**
- Create: `Settings.lua`

**Step 1: Create settings with defaults**

```lua
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
```

**Step 2: Commit**

```bash
git add Settings.lua
git commit -m "feat: add Settings module with defaults and persistence"
```

---

## Task 3: Create Detection Module - Chat Parsing

**Files:**
- Create: `Detection.lua`

**Step 1: Create detection module with chat event handling**

```lua
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
```

**Step 2: Commit**

```bash
git add Detection.lua
git commit -m "feat: add Detection module with chat parsing for item links"
```

---

## Task 4: Create Comparison Module - Slot Mapping

**Files:**
- Create: `Comparison.lua`

**Step 1: Create comparison module with slot identification**

```lua
-- Comparison.lua
-- Item stat extraction and diff calculation

LootRoller.Comparison = {}

-- Map WoW equip locations to inventory slot IDs
local EQUIP_LOC_TO_SLOTS = {
    INVTYPE_HEAD = {1},
    INVTYPE_NECK = {2},
    INVTYPE_SHOULDER = {3},
    INVTYPE_BODY = {4},  -- shirt
    INVTYPE_CHEST = {5},
    INVTYPE_ROBE = {5},
    INVTYPE_WAIST = {6},
    INVTYPE_LEGS = {7},
    INVTYPE_FEET = {8},
    INVTYPE_WRIST = {9},
    INVTYPE_HAND = {10},
    INVTYPE_FINGER = {11, 12},  -- both ring slots
    INVTYPE_TRINKET = {13, 14},  -- both trinket slots
    INVTYPE_CLOAK = {15},
    INVTYPE_2HWEAPON = {16, 17},  -- replaces both weapon slots
    INVTYPE_WEAPON = {16, 17},  -- can go in either hand
    INVTYPE_WEAPONMAINHAND = {16},
    INVTYPE_WEAPONOFFHAND = {17},
    INVTYPE_HOLDABLE = {17},  -- off-hand items
    INVTYPE_SHIELD = {17},
    INVTYPE_RANGED = {18},
    INVTYPE_RANGEDRIGHT = {18},
    INVTYPE_THROWN = {18},
    INVTYPE_RELIC = {18},
}

function LootRoller.Comparison:GetSlotsForItem(itemLink)
    local _, _, _, _, _, _, _, _, equipLoc = GetItemInfo(itemLink)

    if not equipLoc or equipLoc == "" then
        return nil
    end

    return EQUIP_LOC_TO_SLOTS[equipLoc]
end

function LootRoller.Comparison:GetEquippedItemLink(slotId)
    return GetInventoryItemLink("player", slotId)
end

function LootRoller.Comparison:GetEquippedItems(itemLink)
    local slots = self:GetSlotsForItem(itemLink)
    if not slots then
        return {}
    end

    local equipped = {}
    for _, slotId in ipairs(slots) do
        local equippedLink = self:GetEquippedItemLink(slotId)
        table.insert(equipped, {
            slotId = slotId,
            itemLink = equippedLink,  -- can be nil if slot empty
        })
    end

    return equipped
end
```

**Step 2: Commit**

```bash
git add Comparison.lua
git commit -m "feat: add Comparison module with slot identification"
```

---

## Task 5: Add Stat Extraction to Comparison Module

**Files:**
- Modify: `Comparison.lua`

**Step 1: Add tooltip scanning for stat extraction**

Append to `Comparison.lua`:

```lua
-- Tooltip for scanning item stats
local scanTooltip = CreateFrame("GameTooltip", "LootRollerScanTooltip", nil, "GameTooltipTemplate")
scanTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")

-- Stat patterns to look for in tooltip
local STAT_PATTERNS = {
    -- Primary stats
    {pattern = "%+(%d+) Strength", stat = "Strength"},
    {pattern = "%+(%d+) Agility", stat = "Agility"},
    {pattern = "%+(%d+) Stamina", stat = "Stamina"},
    {pattern = "%+(%d+) Intellect", stat = "Intellect"},
    {pattern = "%+(%d+) Spirit", stat = "Spirit"},

    -- Secondary stats
    {pattern = "%+(%d+) Attack Power", stat = "Attack Power"},
    {pattern = "%+(%d+) Spell Damage", stat = "Spell Damage"},
    {pattern = "Increases damage and healing done by magical spells and effects by up to (%d+)", stat = "Spell Power"},
    {pattern = "%+(%d+) Healing Spells", stat = "Healing"},
    {pattern = "Increases healing done by spells and effects by up to (%d+)", stat = "Healing"},
    {pattern = "%+(%d+)%% Critical Strike", stat = "Crit %"},
    {pattern = "Improves your chance to get a critical strike by (%d+)%%", stat = "Crit %"},
    {pattern = "Improves your chance to hit by (%d+)%%", stat = "Hit %"},
    {pattern = "%+(%d+) Defense", stat = "Defense"},
    {pattern = "Increased Defense %+(%d+)", stat = "Defense"},

    -- Resistances
    {pattern = "%+(%d+) Fire Resistance", stat = "Fire Resist"},
    {pattern = "%+(%d+) Nature Resistance", stat = "Nature Resist"},
    {pattern = "%+(%d+) Frost Resistance", stat = "Frost Resist"},
    {pattern = "%+(%d+) Shadow Resistance", stat = "Shadow Resist"},
    {pattern = "%+(%d+) Arcane Resistance", stat = "Arcane Resist"},

    -- Other
    {pattern = "(%d+) Armor", stat = "Armor"},
}

function LootRoller.Comparison:ExtractStats(itemLink)
    if not itemLink then
        return {}
    end

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(itemLink)

    local stats = {}
    local numLines = scanTooltip:NumLines()

    for i = 1, numLines do
        local leftText = getglobal("LootRollerScanTooltipTextLeft" .. i)
        if leftText then
            local text = leftText:GetText()
            if text then
                for _, patternInfo in ipairs(STAT_PATTERNS) do
                    local value = string.match(text, patternInfo.pattern)
                    if value then
                        stats[patternInfo.stat] = (stats[patternInfo.stat] or 0) + tonumber(value)
                    end
                end
            end
        end
    end

    return stats
end

function LootRoller.Comparison:CalculateDiff(announcedStats, equippedStats)
    local diff = {}

    -- All stats from announced item
    for stat, value in pairs(announcedStats) do
        local equippedValue = equippedStats[stat] or 0
        local change = value - equippedValue
        if change ~= 0 then
            table.insert(diff, {
                stat = stat,
                value = change,
                isGain = change > 0,
            })
        end
    end

    -- Stats only on equipped item (losing them)
    for stat, value in pairs(equippedStats) do
        if not announcedStats[stat] then
            table.insert(diff, {
                stat = stat,
                value = -value,
                isGain = false,
            })
        end
    end

    -- Sort: gains first, then losses
    table.sort(diff, function(a, b)
        if a.isGain ~= b.isGain then
            return a.isGain
        end
        return math.abs(a.value) > math.abs(b.value)
    end)

    return diff
end

function LootRoller.Comparison:CompareItems(announcedLink)
    local equippedItems = self:GetEquippedItems(announcedLink)
    local announcedStats = self:ExtractStats(announcedLink)

    local comparisons = {}

    for i, equipped in ipairs(equippedItems) do
        local equippedStats = self:ExtractStats(equipped.itemLink)
        local diff = self:CalculateDiff(announcedStats, equippedStats)

        table.insert(comparisons, {
            slotId = equipped.slotId,
            equippedLink = equipped.itemLink,
            diff = diff,
            isEmpty = equipped.itemLink == nil,
        })
    end

    return comparisons
end
```

**Step 2: Commit**

```bash
git add Comparison.lua
git commit -m "feat: add stat extraction and diff calculation to Comparison module"
```

---

## Task 6: Create UI Module - Basic Frame

**Files:**
- Create: `UI.lua`

**Step 1: Create UI module with basic popup frame**

```lua
-- UI.lua
-- Popup frame and display

LootRoller.UI = {}

local activePopups = {}  -- track active popups
local MAX_STACKED_POPUPS = 4

-- Colors
local COLOR_GAIN = {0, 1, 0}      -- green
local COLOR_LOSS = {1, 0, 0}      -- red
local COLOR_NEUTRAL = {0.5, 0.5, 0.5}  -- gray

-- Quality colors (same as WoW item quality)
local QUALITY_COLORS = {
    [0] = {0.6, 0.6, 0.6},  -- Poor (gray)
    [1] = {1, 1, 1},        -- Common (white)
    [2] = {0.12, 1, 0},     -- Uncommon (green)
    [3] = {0, 0.44, 0.87},  -- Rare (blue)
    [4] = {0.64, 0.21, 0.93}, -- Epic (purple)
    [5] = {1, 0.5, 0},      -- Legendary (orange)
}

function LootRoller.UI:CreatePopupFrame()
    local frame = CreateFrame("Frame", "LootRollerPopup" .. (table.getn(activePopups) + 1), UIParent)
    frame:SetWidth(280)
    frame:SetHeight(200)
    frame:SetPoint("CENTER", 0, 100)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)

    -- Background
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Make draggable
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function()
        this:StartMoving()
    end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        LootRoller.UI:SaveFramePosition(this)
    end)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function()
        LootRoller.UI:HidePopup(frame)
    end)

    -- Item icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(37)
    icon:SetHeight(37)
    icon:SetPoint("TOPLEFT", 15, -15)
    frame.icon = icon

    -- Item name
    local itemName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    itemName:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 0)
    itemName:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)
    itemName:SetJustifyH("LEFT")
    frame.itemName = itemName

    -- Item subtext (type/slot)
    local itemSubtext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    itemSubtext:SetPoint("TOPLEFT", itemName, "BOTTOMLEFT", 0, -2)
    itemSubtext:SetTextColor(0.7, 0.7, 0.7)
    frame.itemSubtext = itemSubtext

    -- Stat diff container
    local statFrame = CreateFrame("Frame", nil, frame)
    statFrame:SetPoint("TOPLEFT", 15, -65)
    statFrame:SetPoint("TOPRIGHT", -15, -65)
    statFrame:SetHeight(90)
    frame.statFrame = statFrame

    -- Button container
    local buttonFrame = CreateFrame("Frame", nil, frame)
    buttonFrame:SetPoint("BOTTOMLEFT", 15, 15)
    buttonFrame:SetPoint("BOTTOMRIGHT", -15, 15)
    buttonFrame:SetHeight(30)
    frame.buttonFrame = buttonFrame

    -- MS Button
    local msBtn = self:CreateRollButton(buttonFrame, "MS", function()
        LootRoller.UI:DoRoll(frame, "ms")
    end)
    msBtn:SetPoint("LEFT", 0, 0)
    frame.msBtn = msBtn

    -- OS Button
    local osBtn = self:CreateRollButton(buttonFrame, "OS", function()
        LootRoller.UI:DoRoll(frame, "os")
    end)
    osBtn:SetPoint("CENTER", 0, 0)
    frame.osBtn = osBtn

    -- TMOG Button
    local tmogBtn = self:CreateRollButton(buttonFrame, "TMOG", function()
        LootRoller.UI:DoRoll(frame, "tmog")
    end)
    tmogBtn:SetPoint("RIGHT", 0, 0)
    frame.tmogBtn = tmogBtn

    frame:Hide()
    return frame
end

function LootRoller.UI:CreateRollButton(parent, text, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetWidth(75)
    btn:SetHeight(25)
    btn:SetText(text)
    btn:SetScript("OnClick", onClick)
    return btn
end

function LootRoller.UI:SaveFramePosition(frame)
    local point, _, _, x, y = frame:GetPoint()
    LootRoller.Settings:Set("framePosition", {point = point, x = x, y = y})
end

function LootRoller.UI:RestoreFramePosition(frame)
    local pos = LootRoller.Settings:Get("framePosition")
    if pos then
        frame:ClearAllPoints()
        frame:SetPoint(pos.point, pos.x, pos.y)
    end
end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: add UI module with basic popup frame structure"
```

---

## Task 7: Add Item Display and Stat Rendering to UI

**Files:**
- Modify: `UI.lua`

**Step 1: Add ShowItem and stat display functions**

Append to `UI.lua`:

```lua
function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end

    local name, link, quality, _, _, itemType, itemSubType, _, equipLoc, texture = GetItemInfo(itemLink)

    -- Handle item not cached
    if not name then
        LootRoller:Debug("Item not cached, retrying...")
        -- Retry after short delay
        local retryFrame = CreateFrame("Frame")
        retryFrame.elapsed = 0
        retryFrame.itemLink = itemLink
        retryFrame:SetScript("OnUpdate", function()
            this.elapsed = this.elapsed + arg1
            if this.elapsed > 1.5 then
                LootRoller.UI:ShowItem(this.itemLink)
                this:SetScript("OnUpdate", nil)
            end
        end)
        return
    end

    -- Handle multi-item mode
    local mode = LootRoller.Settings:Get("multiItemMode")
    local popup

    if mode == "replace" then
        -- Close existing popups
        for _, p in ipairs(activePopups) do
            p:Hide()
        end
        activePopups = {}
        popup = self:GetOrCreatePopup()
    else -- stack
        if table.getn(activePopups) >= MAX_STACKED_POPUPS then
            -- Remove oldest
            local oldest = table.remove(activePopups, 1)
            oldest:Hide()
        end
        popup = self:GetOrCreatePopup()
    end

    -- Store item data on frame
    popup.itemLink = itemLink
    popup.itemName:SetText(name)

    -- Set quality color
    local qc = QUALITY_COLORS[quality] or QUALITY_COLORS[1]
    popup.itemName:SetTextColor(qc[1], qc[2], qc[3])

    -- Set icon
    popup.icon:SetTexture(texture)

    -- Set subtext
    popup.itemSubtext:SetText(itemType .. " - " .. (itemSubType or ""))

    -- Calculate and display stat comparisons
    local comparisons = LootRoller.Comparison:CompareItems(itemLink)
    self:DisplayStats(popup, comparisons)

    -- Position for stacking
    self:PositionPopup(popup)

    -- Restore saved position (only first popup)
    if table.getn(activePopups) == 0 then
        self:RestoreFramePosition(popup)
    end

    table.insert(activePopups, popup)
    popup:Show()

    -- Play sound if enabled
    if LootRoller.Settings:Get("soundEnabled") then
        PlaySound("igMainMenuOpen")
    end

    -- Start auto-hide timer if configured
    local timeout = LootRoller.Settings:Get("autoHideTimeout")
    if timeout and timeout > 0 then
        self:StartAutoHideTimer(popup, timeout)
    end
end

function LootRoller.UI:GetOrCreatePopup()
    -- Reuse hidden popup or create new
    for _, popup in ipairs(activePopups) do
        if not popup:IsShown() then
            return popup
        end
    end
    return self:CreatePopupFrame()
end

function LootRoller.UI:PositionPopup(popup)
    local numActive = table.getn(activePopups)
    if numActive > 0 then
        local lastPopup = activePopups[numActive]
        popup:ClearAllPoints()
        popup:SetPoint("TOP", lastPopup, "BOTTOM", 0, -10)
    end
end

function LootRoller.UI:DisplayStats(popup, comparisons)
    -- Clear existing stat lines
    if popup.statLines then
        for _, line in ipairs(popup.statLines) do
            line:Hide()
        end
    end
    popup.statLines = {}

    local yOffset = 0
    local columnWidth = 130

    for i, comparison in ipairs(comparisons) do
        -- Column header (vs Equipped 1, vs Equipped 2, or vs Empty)
        local headerText
        if comparison.isEmpty then
            headerText = "vs Empty Slot"
        elseif table.getn(comparisons) > 1 then
            headerText = "vs Slot " .. i
        else
            headerText = "vs Equipped"
        end

        local xOffset = (i - 1) * columnWidth

        local header = popup.statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetPoint("TOPLEFT", xOffset, yOffset)
        header:SetText(headerText)
        header:SetTextColor(1, 0.82, 0)
        table.insert(popup.statLines, header)

        yOffset = yOffset - 14

        -- Stat diff lines
        for _, statDiff in ipairs(comparison.diff) do
            local line = popup.statFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            line:SetPoint("TOPLEFT", xOffset, yOffset)

            local prefix = statDiff.value > 0 and "+" or ""
            line:SetText(prefix .. statDiff.value .. " " .. statDiff.stat)

            if statDiff.isGain then
                line:SetTextColor(COLOR_GAIN[1], COLOR_GAIN[2], COLOR_GAIN[3])
            else
                line:SetTextColor(COLOR_LOSS[1], COLOR_LOSS[2], COLOR_LOSS[3])
            end

            table.insert(popup.statLines, line)
            yOffset = yOffset - 12
        end

        -- Reset yOffset for next column
        if i < table.getn(comparisons) then
            yOffset = 0
        end
    end

    -- Adjust frame height based on content
    local contentHeight = math.max(80, -yOffset + 20)
    popup:SetHeight(contentHeight + 110)  -- add space for header and buttons
end

function LootRoller.UI:StartAutoHideTimer(popup, seconds)
    if popup.autoHideTimer then
        popup.autoHideTimer:SetScript("OnUpdate", nil)
    end

    local timer = CreateFrame("Frame")
    timer.elapsed = 0
    timer.duration = seconds
    timer.popup = popup
    timer:SetScript("OnUpdate", function()
        this.elapsed = this.elapsed + arg1
        if this.elapsed >= this.duration then
            LootRoller.UI:HidePopup(this.popup)
            this:SetScript("OnUpdate", nil)
        end
    end)
    popup.autoHideTimer = timer
end

function LootRoller.UI:HidePopup(popup)
    popup:Hide()

    -- Remove from active list
    for i, p in ipairs(activePopups) do
        if p == popup then
            table.remove(activePopups, i)
            break
        end
    end

    -- Cancel auto-hide timer
    if popup.autoHideTimer then
        popup.autoHideTimer:SetScript("OnUpdate", nil)
        popup.autoHideTimer = nil
    end
end

function LootRoller.UI:HideAllPopups()
    for _, popup in ipairs(activePopups) do
        popup:Hide()
        if popup.autoHideTimer then
            popup.autoHideTimer:SetScript("OnUpdate", nil)
        end
    end
    activePopups = {}
end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: add item display and stat rendering to UI"
```

---

## Task 8: Add Roll Functionality to UI

**Files:**
- Modify: `UI.lua`

**Step 1: Add roll execution function**

Append to `UI.lua`:

```lua
function LootRoller.UI:DoRoll(popup, rollType)
    local rollValue

    if rollType == "ms" then
        rollValue = LootRoller.Settings:Get("msRoll")
    elseif rollType == "os" then
        rollValue = LootRoller.Settings:Get("osRoll")
    elseif rollType == "tmog" then
        rollValue = LootRoller.Settings:Get("tmogRoll")
    end

    if rollValue then
        RandomRoll(1, rollValue)
        LootRoller:Debug("Rolling 1-" .. rollValue .. " for " .. rollType)
    end

    -- Hide popup after rolling
    self:HidePopup(popup)
end

-- Update button tooltips with current roll values
function LootRoller.UI:UpdateButtonTooltips(popup)
    local function SetTooltip(btn, rollType, rollValue)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(this, "ANCHOR_RIGHT")
            GameTooltip:SetText(rollType .. " Roll")
            GameTooltip:AddLine("Roll 1-" .. rollValue, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end

    SetTooltip(popup.msBtn, "Main Spec", LootRoller.Settings:Get("msRoll"))
    SetTooltip(popup.osBtn, "Off Spec", LootRoller.Settings:Get("osRoll"))
    SetTooltip(popup.tmogBtn, "Transmog", LootRoller.Settings:Get("tmogRoll"))
end
```

**Step 2: Update CreatePopupFrame to call UpdateButtonTooltips**

In `LootRoller.UI:CreatePopupFrame()`, add this line before `frame:Hide()`:

```lua
    self:UpdateButtonTooltips(frame)
```

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add roll functionality with configurable values"
```

---

## Task 9: Create Options Module - Slash Commands

**Files:**
- Create: `Options.lua`

**Step 1: Create options module with slash commands**

```lua
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
```

**Step 2: Commit**

```bash
git add Options.lua
git commit -m "feat: add Options module with slash commands"
```

---

## Task 10: Add Settings Panel UI

**Files:**
- Modify: `Options.lua`

**Step 1: Add settings panel creation**

Append to `Options.lua`:

```lua
local optionsPanel = nil

function LootRoller.Options:CreateOptionsPanel()
    if optionsPanel then return optionsPanel end

    local panel = CreateFrame("Frame", "LootRollerOptionsPanel", UIParent)
    panel:SetWidth(350)
    panel:SetHeight(400)
    panel:SetPoint("CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetClampedToScreen(true)

    -- Background
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = {left = 11, right = 12, top = 12, bottom = 11}
    })

    -- Make draggable
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function() this:StartMoving() end)
    panel:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)

    -- Title
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("LootRoller Settings")

    -- Close button
    local closeBtn = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -5, -5)
    closeBtn:SetScript("OnClick", function() panel:Hide() end)

    local yOffset = -50

    -- Enable checkbox
    local enableCB = self:CreateCheckbox(panel, "Enable LootRoller", 20, yOffset,
        function() return LootRoller.Settings:Get("enabled") end,
        function(value) LootRoller.Settings:Set("enabled", value) end
    )
    yOffset = yOffset - 30

    -- Sound checkbox
    local soundCB = self:CreateCheckbox(panel, "Play sound on item announce", 20, yOffset,
        function() return LootRoller.Settings:Get("soundEnabled") end,
        function(value) LootRoller.Settings:Set("soundEnabled", value) end
    )
    yOffset = yOffset - 40

    -- Roll values section
    local rollLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    rollLabel:SetPoint("TOPLEFT", 20, yOffset)
    rollLabel:SetText("Roll Values:")
    yOffset = yOffset - 25

    -- MS Roll
    local msSlider = self:CreateSlider(panel, "Main Spec (MS)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("msRoll") end,
        function(value) LootRoller.Settings:Set("msRoll", value) end
    )
    yOffset = yOffset - 50

    -- OS Roll
    local osSlider = self:CreateSlider(panel, "Off Spec (OS)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("osRoll") end,
        function(value) LootRoller.Settings:Set("osRoll", value) end
    )
    yOffset = yOffset - 50

    -- TMOG Roll
    local tmogSlider = self:CreateSlider(panel, "Transmog (TMOG)", 30, yOffset, 1, 100,
        function() return LootRoller.Settings:Get("tmogRoll") end,
        function(value) LootRoller.Settings:Set("tmogRoll", value) end
    )
    yOffset = yOffset - 50

    -- Auto-hide timeout
    local timeoutSlider = self:CreateSlider(panel, "Auto-hide timeout (0 = disabled)", 30, yOffset, 0, 120,
        function() return LootRoller.Settings:Get("autoHideTimeout") end,
        function(value) LootRoller.Settings:Set("autoHideTimeout", value) end
    )
    yOffset = yOffset - 50

    -- Multi-item mode dropdown
    local modeLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    modeLabel:SetPoint("TOPLEFT", 20, yOffset)
    modeLabel:SetText("Multiple Items:")

    local modeDropdown = self:CreateDropdown(panel, 150, yOffset - 5,
        {
            {text = "Replace previous", value = "replace"},
            {text = "Stack popups", value = "stack"},
        },
        function() return LootRoller.Settings:Get("multiItemMode") end,
        function(value) LootRoller.Settings:Set("multiItemMode", value) end
    )

    panel:Hide()
    optionsPanel = panel

    -- Register with Interface Options
    self:RegisterInterfaceOptions()

    return panel
end

function LootRoller.Options:CreateCheckbox(parent, label, x, y, getValue, setValue)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetWidth(24)
    cb:SetHeight(24)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", cb, "RIGHT", 5, 0)
    text:SetText(label)

    cb:SetScript("OnShow", function()
        this:SetChecked(getValue())
    end)

    cb:SetScript("OnClick", function()
        setValue(this:GetChecked() == 1)
    end)

    return cb
end

function LootRoller.Options:CreateSlider(parent, label, x, y, minVal, maxVal, getValue, setValue)
    local slider = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", x, y)
    slider:SetWidth(200)
    slider:SetHeight(17)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(1)

    local labelText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    labelText:SetPoint("BOTTOM", slider, "TOP", 0, 3)
    labelText:SetText(label)

    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("TOP", slider, "BOTTOM", 0, -2)

    slider:SetScript("OnShow", function()
        local val = getValue()
        this:SetValue(val)
        valueText:SetText(val)
    end)

    slider:SetScript("OnValueChanged", function()
        local val = math.floor(this:GetValue())
        setValue(val)
        valueText:SetText(val)
    end)

    return slider
end

function LootRoller.Options:CreateDropdown(parent, x, y, options, getValue, setValue)
    local dropdown = CreateFrame("Frame", "LootRollerModeDropdown", parent, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", x, y)

    local function Initialize()
        local currentValue = getValue()
        for _, option in ipairs(options) do
            local info = {}
            info.text = option.text
            info.value = option.value
            info.checked = (currentValue == option.value)
            info.func = function()
                setValue(this.value)
                UIDropDownMenu_SetText(option.text, dropdown)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(dropdown, Initialize)
    UIDropDownMenu_SetWidth(120, dropdown)

    -- Set initial text
    local currentValue = getValue()
    for _, option in ipairs(options) do
        if option.value == currentValue then
            UIDropDownMenu_SetText(option.text, dropdown)
            break
        end
    end

    return dropdown
end

function LootRoller.Options:ToggleOptionsPanel()
    local panel = self:CreateOptionsPanel()
    if panel:IsShown() then
        panel:Hide()
    else
        panel:Show()
    end
end

function LootRoller.Options:RegisterInterfaceOptions()
    -- Create a simple panel for Interface Options
    local interfacePanel = CreateFrame("Frame", "LootRollerInterfacePanel")
    interfacePanel.name = "LootRoller"

    local text = interfacePanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    text:SetPoint("TOPLEFT", 16, -16)
    text:SetText("LootRoller")

    local desc = interfacePanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    desc:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
    desc:SetText("Type /lr or /lootroller to open settings.")

    local openBtn = CreateFrame("Button", nil, interfacePanel, "UIPanelButtonTemplate")
    openBtn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -20)
    openBtn:SetWidth(120)
    openBtn:SetHeight(25)
    openBtn:SetText("Open Settings")
    openBtn:SetScript("OnClick", function()
        LootRoller.Options:ToggleOptionsPanel()
    end)

    -- WoW 1.12.1 way to add to interface options
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(interfacePanel)
    end
end
```

**Step 2: Commit**

```bash
git add Options.lua
git commit -m "feat: add settings panel UI with sliders and checkboxes"
```

---

## Task 11: Add Roll Resolution Detection

**Files:**
- Modify: `Detection.lua`

**Step 1: Add roll result parsing to close popups**

Update the `ParseRollResult` function in `Detection.lua`:

```lua
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
```

**Step 2: Commit**

```bash
git add Detection.lua
git commit -m "feat: add roll result detection and cleanup"
```

---

## Task 12: Add RollFor Addon Message Integration

**Files:**
- Modify: `Detection.lua`

**Step 1: Update ParseAddonMessage for RollFor integration**

Update the `ParseAddonMessage` function in `Detection.lua`:

```lua
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
```

**Step 2: Commit**

```bash
git add Detection.lua
git commit -m "feat: add RollFor addon message integration"
```

---

## Task 13: Final Polish and Testing Setup

**Files:**
- Modify: `LootRoller.lua`
- Modify: `README.md`

**Step 1: Update main file to initialize UI tooltips**

In `LootRoller.lua`, update `OnPlayerLogin`:

```lua
function LootRoller:OnPlayerLogin()
    -- Register detection events after login
    LootRoller.Detection:RegisterEvents()

    -- Pre-create options panel for Interface Options
    LootRoller.Options:CreateOptionsPanel()
end
```

**Step 2: Update README with usage info**

```markdown
# LootRoller

A companion addon for [RollFor](https://github.com/sica42/RollFor) (Turtle WoW / WoW 1.12.1).

## Features

- Detects item announcements from Loot Master (via chat or RollFor addon messages)
- Shows popup with announced item and stat comparison to your equipped gear
- Green stats = upgrade, Red stats = downgrade
- One-click buttons for MS, OS, and TMOG rolls
- Configurable roll values (default: MS=100, OS=99, TMOG=98)
- Auto-hides when roll resolves or after timeout

## Installation

1. Download and extract to `Interface/AddOns/LootRoller`
2. Restart WoW or `/reload`

## Commands

- `/lr` or `/lootroller` - Open settings
- `/lr toggle` - Enable/disable addon
- `/lr test` - Show test popup
- `/lr debug` - Toggle debug mode
- `/lr reset` - Reset to defaults

## Configuration

- **Roll Values**: Customize MS/OS/TMOG roll ranges
- **Sound**: Toggle sound on item announce
- **Auto-hide**: Set timeout (0 = disabled)
- **Multiple Items**: Replace previous popup or stack them

## Compatibility

- WoW 1.12.1 (Turtle WoW)
- Works with or without RollFor installed
```

**Step 3: Commit**

```bash
git add LootRoller.lua README.md
git commit -m "docs: add README and finalize initialization"
```

---

## Summary

After completing all tasks, the addon will have:

1. **Addon skeleton** with proper TOC and namespace
2. **Settings module** with defaults and persistence
3. **Detection module** with chat parsing and RollFor integration
4. **Comparison module** with slot mapping and stat extraction
5. **UI module** with popup, stat display, and roll buttons
6. **Options module** with slash commands and settings panel

**Testing in-game:**
1. Copy addon to `Interface/AddOns/LootRoller`
2. Use `/lr test` to verify popup works
3. Join a raid and have someone link an item in raid chat
4. Verify stat comparison and roll buttons work
