# DeckCommander

A dual-panel file manager designed for Steam Deck and gaming handhelds, optimized for gamepad controls.

![DeckCommander](assets/icons/icon.svg)

## Features

### MVP (Complete)

- **Dual-panel layout** - Classic Norton Commander style interface
- **Full gamepad support** - All operations accessible via controller
- **Keyboard support** - Traditional file manager shortcuts
- **File operations**:
  - Browse directories
  - Copy files/folders
  - Move files/folders
  - Delete files/folders (with confirmation)
  - Multi-select files
- **Visual feedback** - Active panel highlighting, selection indicators
- **Status bar** - Shows current selection and operation results

### Planned Features

- Network plugins (SMB, FTP, SFTP)
- IoT integration
- Custom skins/themes
- Retro game emulator launcher

## Controls

### Keyboard

| Key | Action |
|-----|--------|
| Arrow Keys | Navigate files |
| Enter | Open folder / Select file |
| Backspace / ESC | Go up one directory |
| Tab | Switch between panels |
| Insert | Toggle file selection |
| Ctrl+A | Select all files |
| F2 | Refresh panels |
| F5 | Copy selected to other panel |
| F6 | Move selected to other panel |
| F8 / Delete | Delete selected files |

### Gamepad (Steam Deck)

| Button | Action |
|--------|--------|
| D-Pad / Left Stick | Navigate files |
| A (South) | Open folder / Confirm |
| B (East) | Go up / Cancel |
| X (West) | Toggle file selection |
| Y (North) | Copy files |
| L1 / R1 | Switch panels |
| L2 | Select all |
| R2 | Refresh |
| Start | Move files |
| Select | Delete files |

## Building

### Requirements

- Godot 4.4+

### Export

1. Open project in Godot
2. Go to Project > Export
3. Select "Linux" preset
4. Click "Export Project"

The export preset is pre-configured for Linux x86_64.

## Architecture

```
scenes/
├── main.tscn          # Main application scene with dual panels
└── file_panel.tscn    # Reusable file panel component

scripts/
├── main.gd            # Application controller, file operations
└── file_panel.gd      # File listing, selection, navigation

themes/
└── dark_theme.tres    # Dark UI theme

assets/
├── icons/             # Application icons
└── fonts/             # Roboto font
```

## License

See [LICENSE](LICENSE) file.
