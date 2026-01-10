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
