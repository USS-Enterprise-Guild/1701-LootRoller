# LootRoller Design

A companion addon for RollFor (Turtle WoW / WoW 1.12.1) that displays item announcements with stat comparison and quick-roll buttons.

## Overview

When a Loot Master announces an item, LootRoller shows a popup displaying:
- The announced item with stats
- Stat differences compared to equipped item(s) (green = upgrade, red = downgrade)
- One-click buttons for MS, OS, and TMOG rolls

## Core Architecture

### Addon Structure

```
LootRoller/
├── LootRoller.toc      # Addon manifest
├── LootRoller.lua      # Main file, initialization, event handling
├── Detection.lua       # Item announcement detection
├── Comparison.lua      # Stat extraction and diff calculation
├── UI.lua              # Popup frame and display
├── Settings.lua        # Configuration state and persistence
└── Options.lua         # Settings UI (slash command + Interface panel)
```

### Event Flow

1. RollFor (or loot master) announces item via raid chat or addon message
2. Detection module captures item link, extracts item ID
3. Comparison module identifies equipment slot, fetches equipped item(s), calculates stat diffs
4. UI module displays popup with item, stat overlay, and MS/OS/TMOG buttons
5. Player clicks button → addon executes appropriate `/roll` command
6. Detection module hears roll resolution → UI closes popup

### SavedVariables

Settings persist in `LootRoller_Settings` (account-wide).

## Detection Mechanism

### Chat Parsing

Register for events:
- `CHAT_MSG_RAID` - Normal raid chat
- `CHAT_MSG_RAID_LEADER` - Raid leader messages
- `CHAT_MSG_RAID_WARNING` - Raid warnings

Parse messages for item links using pattern:
```
|cffxxxxxx|Hitem:itemId:enchant:suffix:...|h[Item Name]|h|r
```

### Addon Message Integration

Register for `CHAT_MSG_ADDON` events. Listen for RollFor's addon prefix.

Addon messages take priority. Deduplicate if both addon message and chat message arrive for same item within 1-2 seconds.

### Roll Resolution Detection

Listen for roll results to close popup:
- `CHAT_MSG_SYSTEM` - Captures "/roll" results
- RollFor addon messages announcing winners

Track current item being rolled. Close popup when winner announced or new item starts (in replace mode).

## Item Comparison

### Slot Identification

Use `GetItemInfo(itemId)` to get `equipLoc`. Map to inventory slots:
- `INVTYPE_FINGER` → slots 11, 12 (both rings)
- `INVTYPE_TRINKET` → slots 13, 14 (both trinkets)
- `INVTYPE_WEAPON`, `INVTYPE_WEAPONMAINHAND` → slot 16
- `INVTYPE_HOLDABLE`, `INVTYPE_SHIELD`, `INVTYPE_WEAPONOFFHAND` → slot 17
- Etc.

### Stat Extraction

Tooltip scanning approach:
1. Create hidden `GameTooltip`
2. Call `SetHyperlink(itemLink)`
3. Parse tooltip text for stat patterns: `"+X Strength"`, `"Equip: ..."`, armor, DPS

Build stat table for announced item and equipped item(s).

### Diff Calculation

For each stat: `announced_value - equipped_value`
- Positive = green (upgrade)
- Negative = red (downgrade)
- Zero/missing = omit or gray

For dual-slot items (rings, trinkets), calculate and display diffs against both equipped items, labeled "vs Ring 1" / "vs Ring 2".

## UI Layout

### Popup Frame

Draggable frame with saved position:

```
┌─────────────────────────────────────────┐
│ [Item Icon]  [Item Name]            [X] │
│              Epic Leather Chest         │
├─────────────────────────────────────────┤
│  +15 Agility          vs Equipped 1     │
│  +10 Stamina          ─────────────     │
│  -5 Intellect         vs Equipped 2     │
│  +22 Attack Power     (if dual-slot)    │
├─────────────────────────────────────────┤
│  [ MS ]    [ OS ]    [ TMOG ]           │
└─────────────────────────────────────────┘
```

### Elements

- **Header**: Item icon (clickable to link), item name with quality color, close button
- **Stat Panel**: Stat diffs with color coding. Dual-slot items show second comparison
- **Button Bar**: Three buttons, hover shows roll range tooltip

### Multi-Item Mode (Stack)

When stacking enabled, additional popups offset below first. Each tracks independently. Max 3-4 visible.

### Sound

Play alert sound via `PlaySound()` when popup appears (if enabled).

## Settings & Configuration

### Default Values

```lua
LootRoller_Defaults = {
    enabled = true,
    msRoll = 100,           -- /roll 100 (1-100)
    osRoll = 99,            -- /roll 99 (1-99)
    tmogRoll = 98,          -- /roll 98 (1-98)
    soundEnabled = true,
    autoHideTimeout = 60,   -- seconds, 0 = disabled
    multiItemMode = "replace",  -- "replace" or "stack"
}
```

### Slash Commands

- `/lootroller` or `/lr` - Opens settings panel
- `/lr toggle` - Quick enable/disable
- `/lr test` - Show test popup with random item

### Settings Panel

Vertical layout:
- **Enable LootRoller** - Checkbox
- **Roll Values** - Three input boxes (MS/OS/TMOG), range 1-100
- **Play Sound** - Checkbox
- **Auto-hide Timeout** - Slider (0-120 seconds, 0 = disabled)
- **Multiple Items** - Dropdown: "Replace previous" / "Stack popups"

### Interface Options Integration

Register via `InterfaceOptions_AddCategory()`. Same frame for slash command and Interface panel.

## Edge Cases

### Error Handling

- **Item not cached**: Queue retry after 1-2 seconds, show "Loading..." until data arrives
- **No equipped item**: Show all stats as green, display "vs Empty Slot"
- **Unrecognized slot**: Silently ignore or show without comparison

### Anti-Spam

- Debounce duplicate announcements within 3-second window

### Testing

- `/lr test` spawns popup with known item for UI testing
- `/lr debug` prints detection events to chat

### Localization

Stat parsing patterns for English client. Non-English requires localized patterns (future enhancement).

## Future Considerations

- Localization support for non-English clients
- Integration with other loot addons beyond RollFor
- Class/spec appropriate item highlighting
