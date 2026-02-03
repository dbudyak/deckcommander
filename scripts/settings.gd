extends Node
## Global settings and constants for DeckCommander.
##
## This autoload provides centralized access to application settings
## and visual constants used throughout the application.


# =============================================================================
# Visual Constants
# =============================================================================

## Color for the active/focused panel
const PANEL_ACTIVE_COLOR := Color(1.0, 1.0, 1.0)

## Color for the inactive panel
const PANEL_INACTIVE_COLOR := Color(0.5, 0.5, 0.6)

## Primary accent color (cyan)
const ACCENT_PRIMARY := Color(0.0, 0.85, 1.0)

## Secondary accent color (magenta)
const ACCENT_SECONDARY := Color(1.0, 0.4, 0.7)

## Color for selected files
const SELECTION_COLOR := Color(0.2, 1.0, 0.4)

## Color for selected files when focused
const SELECTION_FOCUS_COLOR := Color(0.4, 1.0, 0.6)


# =============================================================================
# Navigation Constants
# =============================================================================

## Initial delay before key repeat starts (seconds)
const NAV_REPEAT_DELAY := 0.4

## Time between repeated key presses (seconds)
const NAV_REPEAT_RATE := 0.08


# =============================================================================
# Status Message Icons
# =============================================================================

const ICON_READY := "🎮"
const ICON_SELECTED := "✨"
const ICON_POINTER := "►"
const ICON_COPY := "✅"
const ICON_MOVE := "📦"
const ICON_DELETE := "🗑️"
const ICON_RENAME := "✏️"
const ICON_MKDIR := "📁"
const ICON_REFRESH := "🔄"
const ICON_WARNING := "⚠"
const ICON_ERROR := "❌"


# =============================================================================
# User Preferences (persisted)
# =============================================================================

## Whether to show hidden files (files starting with .)
var show_hidden_files := false

## Last used directory for left panel
var last_path_left := ""

## Last used directory for right panel
var last_path_right := ""


# =============================================================================
# Hints Text
# =============================================================================

const HINTS_KEYBOARD := "Ins:Sel  F2:Ren  F5:Copy  F6:Move  F7:Mkdir  F8:Del  Tab:Switch"
const HINTS_GAMEPAD := "Ⓧ Sel  Ⓨ Copy  ☰ Move  ⊞ Del  LB/RB Switch"


# =============================================================================
# Methods
# =============================================================================

func _ready() -> void:
	_load_settings()


## Saves user settings to disk.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("display", "show_hidden_files", show_hidden_files)
	config.set_value("paths", "last_path_left", last_path_left)
	config.set_value("paths", "last_path_right", last_path_right)

	var err := config.save("user://settings.cfg")
	if err != OK:
		push_error("Settings: Failed to save settings")


## Loads user settings from disk.
func _load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")

	if err == OK:
		show_hidden_files = config.get_value("display", "show_hidden_files", false)
		last_path_left = config.get_value("paths", "last_path_left", "")
		last_path_right = config.get_value("paths", "last_path_right", "")
