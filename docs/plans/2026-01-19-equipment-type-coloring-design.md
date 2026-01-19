# Equipment Type Coloring Design

## Overview

Color equipment types (armor and weapons) in the loot popup based on whether the character can equip them and whether they're optimal for the class.

## Color Scheme

| Color | Meaning | Example |
|-------|---------|---------|
| White (normal) | Equippable and preferred | Plate on Warrior |
| Yellow | Equippable but not optimal | Leather on Warrior |
| Red | Cannot equip | Plate on Mage |

## Rendering Behavior

**Armor lines:** Split slot from armor type, only color the type.
- "Legs Cloth" → "Legs " (white) + "Cloth" (colored based on usability)

**Weapon lines:** Color the entire weapon type string.
- "Main Hand Two-Handed Axe" → "Main Hand " (white) + "Two-Handed Axe" (colored)

**Shield:** Treated like weapons (entire word colored if unusable).

## Data Structures

### Class Proficiency Table

What each class can use:

```lua
local CLASS_PROFICIENCY = {
    WARRIOR = {
        Cloth = true, Leather = true, Mail = true, Plate = true,
        ["One-Handed Axe"] = true, ["Two-Handed Axe"] = true,
        ["One-Handed Sword"] = true, ["Two-Handed Sword"] = true,
        ["One-Handed Mace"] = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
        Bow = true, Crossbow = true, Gun = true, Thrown = true,
        Shield = true,
    },
    PALADIN = {
        Cloth = true, Leather = true, Mail = true, Plate = true,
        ["One-Handed Axe"] = true, ["Two-Handed Axe"] = true,
        ["One-Handed Sword"] = true, ["Two-Handed Sword"] = true,
        ["One-Handed Mace"] = true, ["Two-Handed Mace"] = true,
        Polearm = true,
        Shield = true,
    },
    HUNTER = {
        Cloth = true, Leather = true, Mail = true,
        ["One-Handed Axe"] = true, ["Two-Handed Axe"] = true,
        ["One-Handed Sword"] = true, ["Two-Handed Sword"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
        Bow = true, Crossbow = true, Gun = true,
    },
    SHAMAN = {
        Cloth = true, Leather = true, Mail = true,
        ["One-Handed Axe"] = true, ["Two-Handed Axe"] = true,
        ["One-Handed Mace"] = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Staff = true,
        Shield = true,
    },
    ROGUE = {
        Cloth = true, Leather = true,
        ["One-Handed Axe"] = true,
        ["One-Handed Sword"] = true,
        ["One-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true,
        Bow = true, Crossbow = true, Gun = true, Thrown = true,
    },
    DRUID = {
        Cloth = true, Leather = true,
        ["One-Handed Mace"] = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
    },
    MAGE = {
        Cloth = true,
        ["One-Handed Sword"] = true,
        Dagger = true, Staff = true, Wand = true,
    },
    WARLOCK = {
        Cloth = true,
        ["One-Handed Sword"] = true,
        Dagger = true, Staff = true, Wand = true,
    },
    PRIEST = {
        Cloth = true,
        ["One-Handed Mace"] = true,
        Dagger = true, Staff = true, Wand = true,
    },
}
```

### Preferred Armor Table

Optimal armor type per class:

```lua
local CLASS_PREFERRED_ARMOR = {
    WARRIOR = "Plate",
    PALADIN = "Plate",
    HUNTER = "Mail",
    SHAMAN = "Mail",
    ROGUE = "Leather",
    DRUID = "Leather",
    MAGE = "Cloth",
    WARLOCK = "Cloth",
    PRIEST = "Cloth",
}
```

### Armor Types (for preferred check)

```lua
local ARMOR_TYPES = {
    Cloth = true,
    Leather = true,
    Mail = true,
    Plate = true,
}
```

## Helper Functions

```lua
-- Check if player can equip a given type
local function CanPlayerEquipType(equipType)
    local _, classToken = UnitClass("player")
    local proficiencies = CLASS_PROFICIENCY[classToken]
    if not proficiencies then return true end
    return proficiencies[equipType] == true
end

-- Check if armor type is preferred for player's class
local function IsPreferredArmorType(armorType)
    local _, classToken = UnitClass("player")
    return CLASS_PREFERRED_ARMOR[classToken] == armorType
end

-- Get color for equipment type
-- Returns: color table {r, g, b}
local function GetEquipTypeColor(equipType)
    if not CanPlayerEquipType(equipType) then
        return COLOR_WORSE  -- Red: cannot equip
    end
    if ARMOR_TYPES[equipType] and not IsPreferredArmorType(equipType) then
        return COLOR_SUBOPTIMAL  -- Yellow: usable but not preferred
    end
    return nil  -- Normal color
end
```

## Equipment Types to Match

**Armor types:**
- Cloth, Leather, Mail, Plate

**Weapon types (match as complete strings):**
- One-Handed Axe, Two-Handed Axe
- One-Handed Sword, Two-Handed Sword
- One-Handed Mace, Two-Handed Mace
- Dagger, Fist Weapon, Polearm, Staff
- Bow, Crossbow, Gun, Thrown, Wand
- Shield

## Implementation Location

All changes in `UI.lua`:
1. Add color constant `COLOR_SUBOPTIMAL = {1, 1, 0}` (yellow)
2. Add proficiency and preferred armor tables
3. Add helper functions
4. Modify tooltip line rendering to detect and split equipment type lines
