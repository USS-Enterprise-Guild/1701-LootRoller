# Gear Filter Configuration Design

## Overview

Add configuration options to filter which gear is displayed in the loot popup based on character equipability. Three filter modes:

- **Preferred Only** - Only shows preferred armor type + usable weapons, respects class restrictions
- **All Usable** (default) - Shows all equippable gear, respects class restrictions
- **Everything** - Shows all items regardless of class restrictions

## Filter Behavior

| Mode | Armor | Weapons | Class Restrictions |
|------|-------|---------|-------------------|
| Preferred Only | Only preferred type (e.g., Plate for Warrior) | All usable | Respected |
| All Usable | All equippable types | All usable | Respected |
| Everything | Show all | Show all | Ignored |

## Implementation

### Settings.lua

Add default setting:

```lua
gearFilter = "usable"
```

### UI.lua - Filter Functions

Add helper functions before `ShowItem()`:

```lua
-- Check if item passes class restriction (or has no restriction)
local function PassesClassRestriction(itemLink)
    local lines = GetTooltipLines(itemLink)
    for _, lineData in ipairs(lines) do
        local text = lineData.text or ""
        -- Look for "Classes: Mage" or "Classes: Mage, Warlock"
        if string.find(text, "^Classes:") then
            -- First return is localized class name for display
            local localizedClass = UnitClass("player")
            if not string.find(text, localizedClass) then
                return false
            end
        end
    end
    return true  -- No restriction found, or player's class is listed
end

-- Extract equipment type from item tooltip
local function GetItemEquipType(itemLink)
    local lines = GetTooltipLines(itemLink)
    for _, lineData in ipairs(lines) do
        local _, equipType = ParseEquipmentLine(lineData.text)
        if equipType then
            return equipType
        end
    end
    return nil
end

-- Determine if item should be shown based on filter settings
local function ShouldShowItem(itemLink)
    local filterMode = LootRoller.Settings:Get("gearFilter") or "usable"

    -- Everything mode shows all items
    if filterMode == "everything" then
        return true
    end

    -- Check class restrictions from tooltip (e.g., "Classes: Mage")
    if not PassesClassRestriction(itemLink) then
        return false
    end

    -- Check armor/weapon proficiency
    local equipType = GetItemEquipType(itemLink)
    if equipType then
        if not CanPlayerEquipType(equipType) then
            return false
        end
        -- For "preferred" mode, filter non-preferred armor types
        -- Weapons pass through (no "preferred" weapon concept)
        if filterMode == "preferred" and ARMOR_TYPES[equipType] then
            if not IsPreferredArmorType(equipType) then
                return false
            end
        end
    end

    return true
end
```

### UI.lua - ShowItem Modification

Add filter check at start of `ShowItem()`:

```lua
function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end

    -- Check gear filter
    if not ShouldShowItem(itemLink) then return end

    -- ... rest of existing function
end
```

### Options.lua - Dropdown UI

Add dropdown to options panel:

```lua
-- Gear Filter dropdown
local filterLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
filterLabel:SetPoint("TOPLEFT", previousElement, "BOTTOMLEFT", 0, -20)
filterLabel:SetText("Show Gear:")

local filterDropdown = CreateFrame("Frame", "LootRollerFilterDropdown", panel, "UIDropDownMenuTemplate")
filterDropdown:SetPoint("TOPLEFT", filterLabel, "BOTTOMLEFT", -16, -5)

local filterOptions = {
    {
        value = "preferred",
        text = "Preferred Only",
        tooltip = "Only shows your best armor type (e.g., Plate for Warriors) and usable weapons"
    },
    {
        value = "usable",
        text = "All Usable",
        tooltip = "Shows all gear your class can equip"
    },
    {
        value = "everything",
        text = "Everything",
        tooltip = "Shows all gear regardless of class restrictions"
    },
}

UIDropDownMenu_SetWidth(filterDropdown, 150)
UIDropDownMenu_Initialize(filterDropdown, function(self, level)
    for _, opt in ipairs(filterOptions) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = opt.text
        info.value = opt.value
        info.tooltipTitle = opt.text
        info.tooltipText = opt.tooltip
        info.tooltipOnButton = true
        info.func = function()
            LootRoller.Settings:Set("gearFilter", opt.value)
            UIDropDownMenu_SetText(filterDropdown, opt.text)
        end
        info.checked = (LootRoller.Settings:Get("gearFilter") == opt.value)
        UIDropDownMenu_AddButton(info)
    end
end)

-- Set initial text based on current setting
local currentFilter = LootRoller.Settings:Get("gearFilter") or "usable"
for _, opt in ipairs(filterOptions) do
    if opt.value == currentFilter then
        UIDropDownMenu_SetText(filterDropdown, opt.text)
        break
    end
end
```

## Files Changed

| File | Changes |
|------|---------|
| `Settings.lua` | Add `gearFilter = "usable"` default |
| `UI.lua` | Add `ShouldShowItem()`, `PassesClassRestriction()`, `GetItemEquipType()`; modify `ShowItem()` |
| `Options.lua` | Add gear filter dropdown with tooltips |
