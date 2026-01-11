# Scrollable Comparison UI Design

**Date:** 2026-01-11
**Status:** Approved

## Overview

Improve the LootRoller item comparison popup with a scrollable frame and properly aligned tooltip lines with color-coded stat comparisons.

## Requirements

1. Single scroll frame containing both left (loot) and right (equipped) columns that scroll together
2. Full tooltip text display with stat-type alignment
3. Insert blank lines when one item has a stat the other doesn't
4. Color coding based on stat comparison
5. Preserve natural tooltip order for non-stat lines

## Frame Structure

```
LootRollerPopup (520x380)
├── Header area (icons, names, close button)
├── ScrollFrame (replaces leftStats/rightStats)
│   └── ScrollChild (content frame, expands with content)
│       ├── Left column (230px wide)
│       ├── Divider line
│       └── Right column (230px wide)
└── Button bar (MS/OS/TMOG)
```

**Dimensions:**
- ScrollFrame: ~480px wide, ~250px visible height
- ScrollChild: ~480px wide, height expands with content
- Each column: ~230px wide
- Line height: 13px (GameFontNormalSmall)

Scroll bar appears only when content exceeds visible area.

## Line Alignment Algorithm

### Step 1: Parse Tooltips

Extract lines from each tooltip using existing `GetTooltipLines()`. Each line has: `{text, rightText, r, g, b}`.

### Step 2: Classify Lines

For each line, check against `STAT_PATTERNS` from Comparison.lua. Tag stat lines with type and value:

```lua
{text = "+15 Agility", statType = "Agility", value = 15}
{text = "Soulbound", statType = nil}  -- non-stat line
```

### Step 3: Build Aligned Pairs

Walk through both tooltip line lists:
- Both non-stat: pair them (natural alignment)
- Both same stat type: pair them
- One has stat, other doesn't: pair stat with blank
- Stat types differ: insert blank to align

### Step 4: Output

List of `{leftLine, rightLine}` pairs where either side can be nil (blank).

## Color Logic

### Case 1: Both Same Stat Type

Extract numeric values, compare:
- **Left column:** green if leftValue > rightValue, red if <, neutral if =
- **Right column:** inverse (green if rightValue > leftValue, red if <, neutral if =)

### Case 2: Left Has Stat, Right Blank

- Left: green (gaining this stat)
- Right: blank

### Case 3: Left Blank, Right Has Stat

- Left: blank
- Right: green (equipped has stat loot item lacks)

### Case 4: Both Non-Stat Lines

Use original tooltip colors (preserved from scan).

## Data Flow

```
DisplayItemComparison(popup, newItemLink, equippedItemLink):
  1. GetTooltipLines() for both items
  2. ClassifyLine() each line - identify stat type using STAT_PATTERNS
  3. AlignTooltipLines() - build aligned pairs with blanks
  4. GetComparisonColor() - determine colors for each pair
  5. Render lines into ScrollChild
     - Create left/right FontStrings for each pair
     - Position at yOffset, decrement by 13px
     - Apply colors
  6. Set ScrollChild height to total content height
  7. Update scroll frame
```

## New Helper Functions

- `ClassifyLine(lineData)` - returns `{text, statType, value}` or `{text, statType = nil}`
- `AlignTooltipLines(leftLines, rightLines)` - returns list of `{left, right}` pairs
- `GetComparisonColor(leftValue, rightValue, side)` - returns RGB color table

## Edge Cases

**Empty slot:** Right shows "(Empty Slot)" header, all loot stats green (pure gain)

**Item not cached:** Existing retry logic handles this (1.5 second delay)

**Very long tooltips:** Scroll frame handles naturally, scroll bar appears

**No matching stats:** Both show full tooltips, non-stat lines use original colors

**Dual-slot items:** Compare against first slot only (future enhancement)

**Weapon damage/DPS:** Neutral coloring, relies on natural tooltip alignment (future: parse and color)

## Files to Modify

- `UI.lua` - Primary changes (scroll frame, alignment, coloring)
- May reference `STAT_PATTERNS` from `Comparison.lua`

## Future Enhancements

- Weapon DPS parsing and coloring
- Dual-slot comparison (show both ring/trinket comparisons)
