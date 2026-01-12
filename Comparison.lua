-- Comparison.lua
-- Item stat extraction and diff calculation

LootRoller.Comparison = {}

-- Helper: Extract hyperlink portion from item link (for SetHyperlink)
local function ExtractHyperlink(itemLink)
    if not itemLink then return nil end
    local _, _, hyperlink = string.find(itemLink, "|H(item:%d+[^|]*)|h")
    return hyperlink or itemLink
end

-- Helper: Pattern match for Lua 5.0 (returns first capture)
local function PatternMatch(text, pattern)
    local _, _, capture = string.find(text, pattern)
    return capture
end

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
    local _, _, id = string.find(itemLink, "item:(%d+)")
    if not id then return nil end

    local name, link, quality, itemLevel, minLevel, itemType, itemSubType, stackCount, itemTexture, equipLoc = GetItemInfo(tonumber(id))

    LootRoller:Debug("GetItemInfo for " .. id .. ": equipLoc=" .. (equipLoc or "nil") .. ", type=" .. (itemType or "nil"))

    if not equipLoc or equipLoc == "" then
        return nil
    end

    local slots = EQUIP_LOC_TO_SLOTS[equipLoc]
    LootRoller:Debug("EQUIP_LOC_TO_SLOTS[" .. equipLoc .. "] = " .. (slots and slots[1] or "nil"))
    return slots
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

    -- Extract the hyperlink portion for SetHyperlink
    local hyperlink = ExtractHyperlink(itemLink)
    if not hyperlink then
        return {}
    end

    scanTooltip:ClearLines()
    scanTooltip:SetHyperlink(hyperlink)

    local stats = {}
    local numLines = scanTooltip:NumLines()

    for i = 1, numLines do
        local leftText = getglobal("LootRollerScanTooltipTextLeft" .. i)
        if leftText then
            local text = leftText:GetText()
            if text then
                for _, patternInfo in ipairs(STAT_PATTERNS) do
                    local value = PatternMatch(text, patternInfo.pattern)
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
