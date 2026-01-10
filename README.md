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
