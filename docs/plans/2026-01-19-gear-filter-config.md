# Gear Filter Configuration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add configuration to filter which gear is shown based on class equipability (Preferred Only, All Usable, Everything).

**Architecture:** Add setting with default "usable", add filter helper functions to UI.lua that check class restrictions and equipment proficiency, modify ShowItem() to check filter before displaying, add dropdown to Options.lua.

**Tech Stack:** Lua (WoW 1.12 API / Turtle WoW)

---

### Task 1: Add Default Setting

**Files:**
- Modify: `Settings.lua:6-16` (defaults table)

**Step 1: Add gearFilter default**

In the `defaults` table, add after line 13 (`multiItemMode = "replace",`):

```lua
    gearFilter = "usable",  -- "preferred", "usable", or "everything"
```

**Step 2: Commit**

```bash
git add Settings.lua
git commit -m "feat: add gearFilter setting with 'usable' default"
```

---

### Task 2: Add Filter Helper Functions to UI.lua

**Files:**
- Modify: `UI.lua` (add functions before `ShowItem` at line 938)

**Step 1: Add helper functions**

Insert before `function LootRoller.UI:ShowItem(itemLink)` (around line 936):

```lua
-- Check if item passes class restriction (or has no restriction)
-- Looks for "Classes: Mage" or "Classes: Mage, Warlock" in tooltip
local function PassesClassRestriction(itemLink)
    local lines = GetTooltipLines(itemLink)
    for _, lineData in ipairs(lines) do
        local text = lineData.text or ""
        if string.find(text, "^Classes:") then
            -- First return of UnitClass is localized display name
            local localizedClass = UnitClass("player")
            if not string.find(text, localizedClass) then
                return false
            end
        end
    end
    return true  -- No restriction, or player's class is listed
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

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: add gear filter helper functions"
```

---

### Task 3: Modify ShowItem to Use Filter

**Files:**
- Modify: `UI.lua:938` (ShowItem function)

**Step 1: Add filter check at start of ShowItem**

Find the `ShowItem` function and add the filter check after the enabled check. The function currently starts:

```lua
function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end
```

Change it to:

```lua
function LootRoller.UI:ShowItem(itemLink)
    if not LootRoller.Settings:Get("enabled") then return end

    -- Check gear filter
    if not ShouldShowItem(itemLink) then return end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "feat: filter items in ShowItem based on gearFilter setting"
```

---

### Task 4: Add Dropdown to Options Panel

**Files:**
- Modify: `Options.lua:130-145` (after timeout slider, before/alongside multi-item mode)

**Step 1: Add gear filter dropdown**

Find the "Multi-item mode dropdown" section (around line 132). Insert the gear filter dropdown BEFORE it:

```lua
    -- Gear Filter dropdown
    local filterLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    filterLabel:SetPoint("TOPLEFT", 20, yOffset)
    filterLabel:SetText("Show Gear:")

    local filterOptions = {
        {
            text = "Preferred Only",
            value = "preferred",
            tooltip = "Only shows your best armor type (e.g., Plate for Warriors) and usable weapons"
        },
        {
            text = "All Usable",
            value = "usable",
            tooltip = "Shows all gear your class can equip"
        },
        {
            text = "Everything",
            value = "everything",
            tooltip = "Shows all gear regardless of class restrictions"
        },
    }

    local filterDropdown = CreateFrame("Frame", "LootRollerFilterDropdown", panel, "UIDropDownMenuTemplate")
    filterDropdown:SetPoint("TOPLEFT", 140, yOffset + 5)

    local function InitializeFilterDropdown()
        local currentValue = LootRoller.Settings:Get("gearFilter") or "usable"
        for _, option in ipairs(filterOptions) do
            local info = {}
            info.text = option.text
            info.value = option.value
            info.checked = (currentValue == option.value)
            info.tooltipTitle = option.text
            info.tooltipText = option.tooltip
            info.tooltipOnButton = true
            info.func = function()
                LootRoller.Settings:Set("gearFilter", this.value)
                UIDropDownMenu_SetText(option.text, filterDropdown)
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    UIDropDownMenu_Initialize(filterDropdown, InitializeFilterDropdown)
    UIDropDownMenu_SetWidth(120, filterDropdown)

    -- Set initial text
    local currentFilter = LootRoller.Settings:Get("gearFilter") or "usable"
    for _, option in ipairs(filterOptions) do
        if option.value == currentFilter then
            UIDropDownMenu_SetText(option.text, filterDropdown)
            break
        end
    end

    yOffset = yOffset - 35
```

**Step 2: Commit**

```bash
git add Options.lua
git commit -m "feat: add gear filter dropdown to options panel"
```

---

### Task 5: Manual Testing

**Step 1: Test filter modes in-game**

1. Log into Turtle WoW
2. Open options with `/lr`
3. Verify dropdown shows "All Usable" by default
4. Change to "Preferred Only" and test with `/lr test`
5. Change to "Everything" and test
6. Verify tooltips appear on dropdown options

**Step 2: Test filtering behavior**

| Mode | Expected Behavior |
|------|------------------|
| Preferred Only | Only shows preferred armor + usable weapons |
| All Usable | Shows all equippable gear |
| Everything | Shows all items |

**Step 3: Final commit if fixes needed**

```bash
git add -A
git commit -m "fix: address gear filter edge cases"
```

---

## Summary

| Task | Description | Files |
|------|-------------|-------|
| 1 | Add gearFilter default setting | Settings.lua |
| 2 | Add filter helper functions | UI.lua |
| 3 | Modify ShowItem to use filter | UI.lua |
| 4 | Add dropdown to options panel | Options.lua |
| 5 | Manual testing | N/A |
