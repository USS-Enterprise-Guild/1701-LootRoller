# Equipment Type Coloring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Color armor/weapon types in the loot popup based on character equipability - red for unusable, yellow for suboptimal, white for preferred.

**Architecture:** Add proficiency lookup tables and helper functions to UI.lua, then modify the tooltip line rendering to detect equipment type lines and split them into two FontStrings (slot + type) with appropriate coloring.

**Tech Stack:** Lua (WoW 1.12 API / Turtle WoW)

---

### Task 1: Add Color Constant and Proficiency Tables

**Files:**
- Modify: `UI.lua:9-21` (after existing color constants)

**Step 1: Add the suboptimal color constant**

After line 12 (`local COLOR_HEADER = {1, 0.82, 0}`), add:

```lua
local COLOR_SUBOPTIMAL = {1, 1, 0}  -- Yellow for usable but not preferred
```

**Step 2: Add proficiency tables**

After line 21 (closing brace of `QUALITY_COLORS`), add:

```lua
-- Equipment proficiency by class
local CLASS_PROFICIENCY = {
    WARRIOR = {
        Cloth = true, Leather = true, Mail = true, Plate = true,
        Axe = true, ["Two-Handed Axe"] = true,
        Sword = true, ["Two-Handed Sword"] = true,
        Mace = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
        Bow = true, Crossbow = true, Gun = true, Thrown = true,
        Shield = true,
    },
    PALADIN = {
        Cloth = true, Leather = true, Mail = true, Plate = true,
        Axe = true, ["Two-Handed Axe"] = true,
        Sword = true, ["Two-Handed Sword"] = true,
        Mace = true, ["Two-Handed Mace"] = true,
        Polearm = true,
        Shield = true,
    },
    HUNTER = {
        Cloth = true, Leather = true, Mail = true,
        Axe = true, ["Two-Handed Axe"] = true,
        Sword = true, ["Two-Handed Sword"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
        Bow = true, Crossbow = true, Gun = true,
    },
    SHAMAN = {
        Cloth = true, Leather = true, Mail = true,
        Axe = true, ["Two-Handed Axe"] = true,
        Mace = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Staff = true,
        Shield = true,
    },
    ROGUE = {
        Cloth = true, Leather = true,
        Axe = true,
        Sword = true,
        Mace = true,
        Dagger = true, ["Fist Weapon"] = true,
        Bow = true, Crossbow = true, Gun = true, Thrown = true,
    },
    DRUID = {
        Cloth = true, Leather = true,
        Mace = true, ["Two-Handed Mace"] = true,
        Dagger = true, ["Fist Weapon"] = true, Polearm = true, Staff = true,
    },
    MAGE = {
        Cloth = true,
        Sword = true,
        Dagger = true, Staff = true, Wand = true,
    },
    WARLOCK = {
        Cloth = true,
        Sword = true,
        Dagger = true, Staff = true, Wand = true,
    },
    PRIEST = {
        Cloth = true,
        Mace = true,
        Dagger = true, Staff = true, Wand = true,
    },
}

-- Preferred (optimal) armor type by class
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

-- Armor types (for checking if equipment type is armor)
local ARMOR_TYPES = {
    Cloth = true,
    Leather = true,
    Mail = true,
    Plate = true,
}

-- All equipment types we recognize (for pattern matching)
local EQUIPMENT_TYPES = {
    -- Armor
    "Cloth", "Leather", "Mail", "Plate",
    -- Weapons (order matters - longer patterns first)
    "Two-Handed Axe", "Two-Handed Sword", "Two-Handed Mace",
    "Fist Weapon", "Polearm", "Staff",
    "Axe", "Sword", "Mace", "Dagger",
    "Bow", "Crossbow", "Gun", "Thrown", "Wand",
    "Shield",
}
```

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add equipment proficiency tables for coloring"
```

---

### Task 2: Add Helper Functions

**Files:**
- Modify: `UI.lua` (after the tables from Task 1, before `GetTmogCollectionStatus`)

**Step 1: Add the helper functions**

Insert before line 48 (`-- Check if item appearance is in transmog collection`):

```lua
-- Check if player can equip a given equipment type
local function CanPlayerEquipType(equipType)
    local _, classToken = UnitClass("player")
    local proficiencies = CLASS_PROFICIENCY[classToken]
    if not proficiencies then return true end  -- Unknown class, assume can equip
    return proficiencies[equipType] == true
end

-- Check if armor type is the preferred type for player's class
local function IsPreferredArmorType(armorType)
    local _, classToken = UnitClass("player")
    return CLASS_PREFERRED_ARMOR[classToken] == armorType
end

-- Get the color for an equipment type based on player's class
-- Returns: color table {r, g, b} or nil for default color
local function GetEquipTypeColor(equipType)
    if not CanPlayerEquipType(equipType) then
        return COLOR_WORSE  -- Red: cannot equip
    end
    if ARMOR_TYPES[equipType] and not IsPreferredArmorType(equipType) then
        return COLOR_SUBOPTIMAL  -- Yellow: usable but not preferred
    end
    return nil  -- Default color (white)
end

-- Try to extract equipment type from a tooltip line
-- Returns: slotPart, equipType or nil, nil if not an equipment line
local function ParseEquipmentLine(text)
    if not text then return nil, nil end
    for _, equipType in ipairs(EQUIPMENT_TYPES) do
        -- Check if line ends with this equipment type
        local pattern = "(.+)%s+" .. string.gsub(equipType, "%-", "%%-") .. "$"
        local slotPart = string.match(text, pattern)
        if slotPart then
            return slotPart, equipType
        end
        -- Also check if line IS just the equipment type (e.g., "Shield")
        if text == equipType then
            return nil, equipType
        end
    end
    return nil, nil
end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: add equipment type detection and color helpers"
```

---

### Task 3: Modify AddStatLine to Support Split Coloring

**Files:**
- Modify: `UI.lua:540-560` (the `AddStatLine` function)

**Step 1: Create a new function for split-colored lines**

Add this function before `AddStatLine` (around line 539):

```lua
-- Add a stat line with optional split coloring for equipment type
-- If equipTypeColor is provided, the equipType portion uses that color
function LootRoller.UI:AddStatLineSplit(container, pool, count, slotText, equipType, yOffset, slotColor, equipTypeColor)
    local line
    -- Reuse existing FontString from pool if available
    if pool[count + 1] then
        line = pool[count + 1]
    else
        -- Create new FontString and add to pool
        line = container:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        line:SetWidth(220)
        line:SetJustifyH("LEFT")
        table.insert(pool, line)
    end
    -- Configure the line
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", 0, yOffset)

    -- Build the text with color codes
    local text = ""
    if slotText and slotText ~= "" then
        if slotColor then
            text = string.format("|cff%02x%02x%02x%s|r ",
                math.floor(slotColor[1] * 255),
                math.floor(slotColor[2] * 255),
                math.floor(slotColor[3] * 255),
                slotText)
        else
            text = slotText .. " "
        end
    end
    if equipType then
        if equipTypeColor then
            text = text .. string.format("|cff%02x%02x%02x%s|r",
                math.floor(equipTypeColor[1] * 255),
                math.floor(equipTypeColor[2] * 255),
                math.floor(equipTypeColor[3] * 255),
                equipType)
        else
            text = text .. equipType
        end
    end

    line:SetText(text)
    line:SetTextColor(1, 1, 1)  -- Base color white, actual colors via escape codes
    line:Show()
    return line:GetHeight()
end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: add AddStatLineSplit for equipment type coloring"
```

---

### Task 4: Modify the Rendering Loop to Use Split Coloring

**Files:**
- Modify: `UI.lua:633-667` (the rendering loop in `DisplayItemComparison`)

**Step 1: Update the rendering loop**

Replace the loop body (lines 633-667) with logic that detects equipment lines and uses split coloring:

```lua
    for _, pair in ipairs(alignedPairs) do
        local leftLine = pair.left
        local rightLine = pair.right

        -- Left side (new item)
        local leftText = ""
        local leftHeight = 13
        if leftLine then
            leftText = leftLine.text or ""
            if leftLine.rightText and leftLine.rightText ~= "" then
                leftText = leftText .. "  " .. leftLine.rightText
            end
        end

        -- Check if this is an equipment type line (left side)
        local leftSlot, leftEquipType = ParseEquipmentLine(leftText)
        if leftEquipType then
            local equipColor = GetEquipTypeColor(leftEquipType)
            leftHeight = self:AddStatLineSplit(popup.leftStats, popup.leftLinesPool, popup.leftLineCount, leftSlot, leftEquipType, yOffset, nil, equipColor)
        else
            local leftColor = GetComparisonColor(leftLine, rightLine, "left")
            leftHeight = self:AddStatLine(popup.leftStats, popup.leftLinesPool, popup.leftLineCount, leftText, yOffset, leftColor)
        end
        popup.leftLineCount = popup.leftLineCount + 1

        -- Right side (equipped item)
        local rightText = ""
        local rightHeight = 13
        if rightLine then
            rightText = rightLine.text or ""
            if rightLine.isEnchant then
                rightText = "Enchant: " .. rightText
            end
            if rightLine.rightText and rightLine.rightText ~= "" then
                rightText = rightText .. "  " .. rightLine.rightText
            end
        end

        -- Check if this is an equipment type line (right side)
        local rightSlot, rightEquipType = ParseEquipmentLine(rightText)
        if rightEquipType then
            local equipColor = GetEquipTypeColor(rightEquipType)
            rightHeight = self:AddStatLineSplit(popup.rightStats, popup.rightLinesPool, popup.rightLineCount, rightSlot, rightEquipType, yOffset, nil, equipColor)
        else
            local rightColor = GetComparisonColor(leftLine, rightLine, "right")
            rightHeight = self:AddStatLine(popup.rightStats, popup.rightLinesPool, popup.rightLineCount, rightText, yOffset, rightColor)
        end
        popup.rightLineCount = popup.rightLineCount + 1

        -- Use the taller of the two lines for row height
        local rowHeight = math.max(leftHeight or 13, rightHeight or 13)
        yOffset = yOffset - rowHeight - lineGap
    end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: color equipment types based on class proficiency"
```

---

### Task 5: Manual Testing

**Step 1: Test in-game**

1. Log into Turtle WoW with different character classes
2. Run `/lootroller test` to trigger test items
3. Verify:
   - Plate items show red armor type on cloth wearers (Mage/Warlock/Priest)
   - Cloth items show yellow armor type on plate wearers (Warrior/Paladin)
   - Preferred armor type shows white (default) color
   - Weapon types show red if class can't use them
   - Slot portion ("Legs", "Chest", etc.) always stays white

**Step 2: Test edge cases**

- Shield on Mage (should be red)
- Wand on Warrior (should be red)
- Items without equipment type line (rings, trinkets) should render normally

**Step 3: Final commit if any fixes needed**

```bash
git add UI.lua
git commit -m "fix: address equipment coloring edge cases"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add color constant and proficiency tables | UI.lua:9-100 |
| 2 | Add helper functions | UI.lua:100-150 |
| 3 | Add AddStatLineSplit function | UI.lua:539 |
| 4 | Modify rendering loop | UI.lua:633-667 |
| 5 | Manual testing | N/A |
