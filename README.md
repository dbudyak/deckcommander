# DeckCommander

A dual-panel file manager designed for Steam Deck and gaming handhelds, optimized for gamepad controls.

## Features

### Core Features

- **Dual-panel layout** - Classic Norton Commander / Midnight Commander style
- **Full gamepad support** - All operations accessible via controller
- **Keyboard support** - Traditional file manager shortcuts
- **Cross-platform** - Works on Linux, macOS, and Windows

### File Operations

- Browse directories with file sizes displayed
- Copy files and folders (recursive)
- Move files and folders
- Delete files and folders (with confirmation)
- Rename files and folders
- Create new directories
- Multi-select files for batch operations

### UI Features

- Visual panel focus indication (active/inactive dimming)
- Selection highlighting (green text)
- File size display for files
- Toggle hidden files visibility
- Status bar with operation feedback
- Keyboard shortcut hints

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
| Enter | Open folder |
| Backspace / ESC | Go up one directory |
| Tab | Switch between panels |
| Insert | Toggle file selection |
| Ctrl+A | Select all files |
| Ctrl+H | Toggle hidden files |
| F2 | Rename file/folder |
| F5 | Copy to other panel |
| F6 | Move to other panel |
| F7 | Create new directory |
| F8 / Delete | Delete selected |
| Ctrl+R | Refresh panels |

### Gamepad (Steam Deck)

| Button | Action |
|--------|--------|
| D-Pad / Left Stick | Navigate files |
| A (South) | Open folder / Confirm |
| B (East) | Go up / Cancel |
| X (West) | Toggle file selection |
| Y (North) | Copy files |
| L1 | Select all |
| R1 | Refresh |
| L2 | Rename |
| R2 | Create directory |
| L3 | Toggle hidden files |
| Start | Move files |
| Select | Delete files |

## Building

### Requirements

- Godot 4.4+

### Running from Editor

1. Open project in Godot
2. Press F5 or click Play

### Export

1. Open project in Godot
2. Go to Project > Export
3. Select your platform preset
4. Click "Export Project"

The export preset is pre-configured for Linux x86_64.

## Architecture

```
scenes/
├── main.tscn          # Main application with dual panels
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

## Technical Details

- **Engine**: Godot 4.4 with GL Compatibility renderer
- **Resolution**: 1280x800 (optimized for Steam Deck)
- **Frame Rate**: 90 FPS max
- **Input**: Full gamepad and keyboard support

## License

See [LICENSE](LICENSE) file.
