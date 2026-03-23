# Scrollable Comparison UI Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current line-by-line comparison with a scrollable, stat-aligned comparison UI.

**Architecture:** Modify UI.lua to use a ScrollFrame containing both columns. Add line classification and alignment logic. Color lines based on stat comparison.

**Tech Stack:** WoW 1.12.1 Lua API, ScrollFrame

**Design Doc:** `docs/plans/2026-01-11-scrollable-comparison-ui-design.md`

---

### Task 1: Add STAT_PATTERNS Reference to UI.lua

**Files:**
- Modify: `UI.lua` (lines 9-12, after color constants)

**Step 1: Add STAT_PATTERNS table**

Add after line 21 (after QUALITY_COLORS):

```lua
-- Stat patterns for line classification (matches Comparison.lua)
local STAT_PATTERNS = {
    {pattern = "%+(%d+) Strength", stat = "Strength"},
    {pattern = "%+(%d+) Agility", stat = "Agility"},
    {pattern = "%+(%d+) Stamina", stat = "Stamina"},
    {pattern = "%+(%d+) Intellect", stat = "Intellect"},
    {pattern = "%+(%d+) Spirit", stat = "Spirit"},
    {pattern = "%+(%d+) Attack Power", stat = "Attack Power"},
    {pattern = "%+(%d+) Spell Damage", stat = "Spell Damage"},
    {pattern = "Increases damage and healing done by magical spells and effects by up to (%d+)", stat = "Spell Power"},
    {pattern = "%+(%d+) Healing Spells", stat = "Healing"},
    {pattern = "Increases healing done by spells and effects by up to (%d+)", stat = "Healing"},
    {pattern = "%+(%d+)%% Critical Strike", stat = "Crit"},
    {pattern = "Improves your chance to get a critical strike by (%d+)%%", stat = "Crit"},
    {pattern = "Improves your chance to hit by (%d+)%%", stat = "Hit"},
    {pattern = "%+(%d+) Defense", stat = "Defense"},
    {pattern = "Increased Defense %+(%d+)", stat = "Defense"},
    {pattern = "%+(%d+) Fire Resistance", stat = "Fire Resist"},
    {pattern = "%+(%d+) Nature Resistance", stat = "Nature Resist"},
    {pattern = "%+(%d+) Frost Resistance", stat = "Frost Resist"},
    {pattern = "%+(%d+) Shadow Resistance", stat = "Shadow Resist"},
    {pattern = "%+(%d+) Arcane Resistance", stat = "Arcane Resist"},
    {pattern = "(%d+) Armor", stat = "Armor"},
}
```

**Step 2: Verify addition**

Run: `grep -A 5 "STAT_PATTERNS" UI.lua`
Expected: Pattern table appears

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add STAT_PATTERNS to UI.lua for line classification"
```

---

### Task 2: Add ClassifyLine Helper Function

**Files:**
- Modify: `UI.lua` (after STAT_PATTERNS, before GetItemId)

**Step 1: Add ClassifyLine function**

```lua
-- Classify a tooltip line: identify stat type and value if applicable
local function ClassifyLine(lineData)
    local text = lineData.text or ""
    for _, patternInfo in ipairs(STAT_PATTERNS) do
        local _, _, value = string.find(text, patternInfo.pattern)
        if value then
            return {
                text = text,
                rightText = lineData.rightText,
                r = lineData.r,
                g = lineData.g,
                b = lineData.b,
                statType = patternInfo.stat,
                value = tonumber(value)
            }
        end
    end
    -- Non-stat line
    return {
        text = text,
        rightText = lineData.rightText,
        r = lineData.r,
        g = lineData.g,
        b = lineData.b,
        statType = nil,
        value = nil
    }
end
```

**Step 2: Verify addition**

Run: `grep -A 20 "ClassifyLine" UI.lua`
Expected: Function appears

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add ClassifyLine helper for stat identification"
```

---

### Task 3: Add AlignTooltipLines Function

**Files:**
- Modify: `UI.lua` (after ClassifyLine)

**Step 1: Add alignment function**

```lua
-- Align two tooltip line lists by stat type, inserting blanks as needed
local function AlignTooltipLines(leftLines, rightLines)
    local result = {}
    local leftClassified = {}
    local rightClassified = {}

    -- Classify all lines
    for _, line in ipairs(leftLines) do
        table.insert(leftClassified, ClassifyLine(line))
    end
    for _, line in ipairs(rightLines) do
        table.insert(rightClassified, ClassifyLine(line))
    end

    -- Track which right lines have been matched
    local rightUsed = {}

    -- Process left lines, finding matches in right
    for i, leftLine in ipairs(leftClassified) do
        local matched = false
        if leftLine.statType then
            -- Look for matching stat in right (unused)
            for j, rightLine in ipairs(rightClassified) do
                if not rightUsed[j] and rightLine.statType == leftLine.statType then
                    table.insert(result, {left = leftLine, right = rightLine})
                    rightUsed[j] = true
                    matched = true
                    break
                end
            end
            if not matched then
                -- Left has stat, right doesn't
                table.insert(result, {left = leftLine, right = nil})
            end
        else
            -- Non-stat line: pair with corresponding position if exists and not a stat
            local rightLine = rightClassified[i]
            if rightLine and not rightLine.statType and not rightUsed[i] then
                table.insert(result, {left = leftLine, right = rightLine})
                rightUsed[i] = true
            else
                table.insert(result, {left = leftLine, right = nil})
            end
        end
    end

    -- Add any unmatched right lines
    for j, rightLine in ipairs(rightClassified) do
        if not rightUsed[j] then
            table.insert(result, {left = nil, right = rightLine})
        end
    end

    return result
end
```

**Step 2: Verify addition**

Run: `grep -A 10 "AlignTooltipLines" UI.lua`
Expected: Function appears

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add AlignTooltipLines for stat-aligned display"
```

---

### Task 4: Add GetComparisonColor Function

**Files:**
- Modify: `UI.lua` (after AlignTooltipLines)

**Step 1: Add color comparison function**

```lua
-- Get color for a line based on stat comparison
-- side: "left" (loot item) or "right" (equipped item)
local function GetComparisonColor(leftLine, rightLine, side)
    -- Both have same stat type - compare values
    if leftLine and rightLine and leftLine.statType and rightLine.statType then
        if leftLine.statType == rightLine.statType and leftLine.value and rightLine.value then
            if side == "left" then
                if leftLine.value > rightLine.value then return COLOR_BETTER
                elseif leftLine.value < rightLine.value then return COLOR_WORSE
                else return COLOR_NEUTRAL end
            else -- right side
                if rightLine.value > leftLine.value then return COLOR_BETTER
                elseif rightLine.value < leftLine.value then return COLOR_WORSE
                else return COLOR_NEUTRAL end
            end
        end
    end

    -- Left has stat, right is blank (gaining stat)
    if leftLine and leftLine.statType and not rightLine then
        if side == "left" then return COLOR_BETTER end
    end

    -- Right has stat, left is blank (equipped has stat loot lacks)
    if rightLine and rightLine.statType and not leftLine then
        if side == "right" then return COLOR_BETTER end
    end

    -- Non-stat lines or unmatched: use original color
    if side == "left" and leftLine then
        return {leftLine.r or 1, leftLine.g or 1, leftLine.b or 1}
    elseif side == "right" and rightLine then
        return {rightLine.r or 1, rightLine.g or 1, rightLine.b or 1}
    end

    return COLOR_NEUTRAL
end
```

**Step 2: Verify addition**

Run: `grep -A 10 "GetComparisonColor" UI.lua`
Expected: Function appears

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: add GetComparisonColor for stat-based coloring"
```

---

### Task 5: Replace Stat Panels with ScrollFrame in CreatePopupFrame

**Files:**
- Modify: `UI.lua` (CreatePopupFrame function, lines 148-158)

**Step 1: Replace leftStats/rightStats with ScrollFrame**

Find and replace the leftStats and rightStats creation (lines 148-158):

```lua
    local leftStats = CreateFrame("Frame", nil, frame)
    leftStats:SetPoint("TOPLEFT", 20, -80)
    leftStats:SetWidth(230)
    leftStats:SetHeight(250)
    frame.leftStats = leftStats

    local rightStats = CreateFrame("Frame", nil, frame)
    rightStats:SetPoint("TOPLEFT", divider, "TOPRIGHT", 15, -45)
    rightStats:SetWidth(230)
    rightStats:SetHeight(250)
    frame.rightStats = rightStats
```

With:

```lua
    -- Scroll frame for stat comparison
    local scrollFrame = CreateFrame("ScrollFrame", frame:GetName() .. "ScrollFrame", frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -80)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 50)
    frame.scrollFrame = scrollFrame

    -- Scroll child (content container)
    local scrollChild = CreateFrame("Frame", frame:GetName() .. "ScrollChild", scrollFrame)
    scrollChild:SetWidth(scrollFrame:GetWidth())
    scrollChild:SetHeight(1) -- Will be set dynamically
    scrollFrame:SetScrollChild(scrollChild)
    frame.scrollChild = scrollChild

    -- Left column container
    local leftStats = CreateFrame("Frame", nil, scrollChild)
    leftStats:SetPoint("TOPLEFT", 5, 0)
    leftStats:SetWidth(220)
    leftStats:SetHeight(1)
    frame.leftStats = leftStats

    -- Right column container
    local rightStats = CreateFrame("Frame", nil, scrollChild)
    rightStats:SetPoint("TOPLEFT", 245, 0)
    rightStats:SetWidth(220)
    rightStats:SetHeight(1)
    frame.rightStats = rightStats

    -- Divider in scroll child
    local scrollDivider = scrollChild:CreateTexture(nil, "ARTWORK")
    scrollDivider:SetTexture(1, 1, 1, 0.3)
    scrollDivider:SetWidth(1)
    scrollDivider:SetPoint("TOPLEFT", 235, 0)
    scrollDivider:SetPoint("BOTTOMLEFT", 235, 0)
    frame.scrollDivider = scrollDivider
```

**Step 2: Move the main divider positioning**

The existing `divider` (line 117-122) is used for header positioning. Keep it but adjust:

```lua
    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetTexture(1, 1, 1, 0.3)
    divider:SetWidth(2)
    divider:SetHeight(40)  -- Just for header area now
    divider:SetPoint("TOP", 0, -35)
    frame.divider = divider
```

**Step 3: Verify changes**

Run: `grep -A 5 "scrollFrame" UI.lua`
Expected: ScrollFrame creation appears

**Step 4: Commit**

```bash
git add UI.lua
git commit -m "feat: replace stat panels with ScrollFrame structure"
```

---

### Task 6: Update ClearStatLines for New Structure

**Files:**
- Modify: `UI.lua` (ClearStatLines function, lines 192-197)

**Step 1: Update function to handle aligned lines**

Replace:

```lua
function LootRoller.UI:ClearStatLines(frame)
    for _, line in ipairs(frame.leftLines or {}) do line:Hide() end
    for _, line in ipairs(frame.rightLines or {}) do line:Hide() end
    frame.leftLines = {}
    frame.rightLines = {}
end
```

With:

```lua
function LootRoller.UI:ClearStatLines(frame)
    -- Hide and clear all line FontStrings
    for _, line in ipairs(frame.leftLines or {}) do
        line:Hide()
        line:SetText("")
    end
    for _, line in ipairs(frame.rightLines or {}) do
        line:Hide()
        line:SetText("")
    end
    frame.leftLines = {}
    frame.rightLines = {}

    -- Reset scroll child height
    if frame.scrollChild then
        frame.scrollChild:SetHeight(1)
    end
end
```

**Step 2: Commit**

```bash
git add UI.lua
git commit -m "refactor: update ClearStatLines for scroll structure"
```

---

### Task 7: Rewrite DisplayItemComparison with Alignment

**Files:**
- Modify: `UI.lua` (DisplayItemComparison function, lines 210-273)

**Step 1: Replace the entire DisplayItemComparison function**

```lua
function LootRoller.UI:DisplayItemComparison(popup, newItemLink, equippedItemLink)
    self:ClearStatLines(popup)

    -- Get item info for headers
    local newId = GetItemId(newItemLink)
    local newName, _, newQuality, _, _, _, _, _, _, newTexture
    if newId then newName, _, newQuality, _, _, _, _, _, _, newTexture = GetItemInfo(newId) end

    local eqId = GetItemId(equippedItemLink)
    local eqName, _, eqQuality, _, _, _, _, _, _, eqTexture
    if eqId then eqName, _, eqQuality, _, _, _, _, _, _, eqTexture = GetItemInfo(eqId) end

    -- Set icons and names
    if newTexture then popup.leftIcon:SetTexture(newTexture); popup.leftIcon:Show()
    else popup.leftIcon:Hide() end
    popup.leftName:SetText(newName or "Unknown Item")
    local newQC = QUALITY_COLORS[newQuality or 1] or QUALITY_COLORS[1]
    popup.leftName:SetTextColor(newQC[1], newQC[2], newQC[3])

    if eqTexture then popup.rightIcon:SetTexture(eqTexture); popup.rightIcon:Show()
    else popup.rightIcon:Hide() end
    if equippedItemLink then
        popup.rightName:SetText(eqName or "Unknown")
        local eqQC = QUALITY_COLORS[eqQuality or 1] or QUALITY_COLORS[1]
        popup.rightName:SetTextColor(eqQC[1], eqQC[2], eqQC[3])
    else
        popup.rightName:SetText("(Empty Slot)")
        popup.rightName:SetTextColor(0.5, 0.5, 0.5)
    end

    -- Get and align tooltip lines
    local newLines = GetTooltipLines(newItemLink)
    local eqLines = GetTooltipLines(equippedItemLink)

    -- Skip first line (item name) for comparison
    local newLinesNoName = {}
    local eqLinesNoName = {}
    for i = 2, table.getn(newLines) do table.insert(newLinesNoName, newLines[i]) end
    for i = 2, table.getn(eqLines) do table.insert(eqLinesNoName, eqLines[i]) end

    local alignedPairs = AlignTooltipLines(newLinesNoName, eqLinesNoName)

    -- Render aligned lines
    local yOffset = 0
    local lineHeight = 13

    for _, pair in ipairs(alignedPairs) do
        local leftLine = pair.left
        local rightLine = pair.right

        -- Left side
        local leftText = ""
        if leftLine then
            leftText = leftLine.text or ""
            if leftLine.rightText and leftLine.rightText ~= "" then
                leftText = leftText .. "  " .. leftLine.rightText
            end
        end
        local leftColor = GetComparisonColor(leftLine, rightLine, "left")
        self:AddStatLine(popup.leftStats, popup.leftLines, leftText, yOffset, leftColor)

        -- Right side
        local rightText = ""
        if rightLine then
            rightText = rightLine.text or ""
            if rightLine.rightText and rightLine.rightText ~= "" then
                rightText = rightText .. "  " .. rightLine.rightText
            end
        end
        local rightColor = GetComparisonColor(leftLine, rightLine, "right")
        self:AddStatLine(popup.rightStats, popup.rightLines, rightText, yOffset, rightColor)

        yOffset = yOffset - lineHeight
    end

    -- Update scroll child height
    local contentHeight = math.abs(yOffset) + 20
    popup.scrollChild:SetHeight(contentHeight)
    popup.leftStats:SetHeight(contentHeight)
    popup.rightStats:SetHeight(contentHeight)
    if popup.scrollDivider then
        popup.scrollDivider:SetHeight(contentHeight)
    end
end
```

**Step 2: Verify function replaced**

Run: `grep -A 10 "alignedPairs" UI.lua`
Expected: New alignment logic appears

**Step 3: Commit**

```bash
git add UI.lua
git commit -m "feat: rewrite DisplayItemComparison with stat alignment"
```

---

### Task 8: Remove Old Comparison Functions

**Files:**
- Modify: `UI.lua`

**Step 1: Remove ParseStatValue function (lines 60-69)**

This function is no longer needed - delete it:

```lua
local function ParseStatValue(text)
    if not text then return nil end
    local _, _, value = string.find(text, "%+(%d+)")
    if value then return tonumber(value) end
    local _, _, value2 = string.find(text, "(%d+)%%")
    if value2 then return tonumber(value2) end
    local _, _, value3 = string.find(text, "by (%d+)")
    if value3 then return tonumber(value3) end
    return nil
end
```

**Step 2: Remove CompareStatLines function (lines 71-79)**

This function is no longer needed - delete it:

```lua
local function CompareStatLines(line1, line2)
    local val1 = ParseStatValue(line1 or "")
    local val2 = ParseStatValue(line2 or "")
    if val1 and val2 then
        if val1 > val2 then return COLOR_BETTER, COLOR_WORSE
        elseif val1 < val2 then return COLOR_WORSE, COLOR_BETTER end
    end
    return COLOR_NEUTRAL, COLOR_NEUTRAL
end
```

**Step 3: Verify removal**

Run: `grep "ParseStatValue\|CompareStatLines" UI.lua`
Expected: No matches (functions removed)

**Step 4: Commit**

```bash
git add UI.lua
git commit -m "refactor: remove old comparison functions"
```

---

### Task 9: Manual Testing

**Files:**
- None (testing only)

**Step 1: Load addon in WoW**

Copy addon folder to WoW AddOns directory, reload UI.

**Step 2: Test with /lr test**

1. Type `/lr test` in chat
2. Verify popup appears with scroll frame
3. Check that stats are aligned (matching stats on same row)
4. Check colors: green for better, red for worse
5. If tooltip is long, verify scrolling works

**Step 3: Test with different item types**

1. Test armor items (multiple stats)
2. Test weapons (damage lines)
3. Test rings/trinkets (may have empty slot)
4. Test items with very different stats (lots of blanks)

**Step 4: Document any issues**

If issues found, create fix commits as needed.

---

## Summary

| Task | Description |
|------|-------------|
| 1 | Add STAT_PATTERNS to UI.lua |
| 2 | Add ClassifyLine helper |
| 3 | Add AlignTooltipLines function |
| 4 | Add GetComparisonColor function |
| 5 | Replace stat panels with ScrollFrame |
| 6 | Update ClearStatLines |
| 7 | Rewrite DisplayItemComparison |
| 8 | Remove old comparison functions |
| 9 | Manual testing |

Total: 9 tasks, ~8 commits
