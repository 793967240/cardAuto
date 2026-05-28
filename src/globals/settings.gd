# src/globals/settings.gd
# 玩家设置单例
# AutoLoad 为 "Settings"
extends Node

const SETTINGS_PATH := "user://settings.cfg"

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

var music_volume: float = 0.7
var sfx_volume: float = 0.8
var language: String = "zh_CN"
var fullscreen: bool = false
var resolution_index: int = 3
var speed_multiplier: float = 2.0

func _ready() -> void:
	load_settings()
	_apply_language(language)
	_apply_display()

func set_language(locale: String) -> void:
	language = locale
	_apply_language(locale)
	save_settings()
	EventBus.language_changed.emit(locale)

func set_fullscreen(enabled: bool) -> void:
	fullscreen = enabled
	_apply_display()
	save_settings()

func set_resolution_index(index: int) -> void:
	resolution_index = clampi(index, 0, RESOLUTIONS.size() - 1)
	_apply_display()
	save_settings()

func _apply_language(locale: String) -> void:
	TranslationServer.set_locale(locale)

func _apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var res := RESOLUTIONS[resolution_index] if resolution_index < RESOLUTIONS.size() else RESOLUTIONS[3]
	get_window().content_scale_size = res
	if OS.has_feature("editor"):
		return
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(res)
		var screen_size := DisplayServer.screen_get_size()
		var screen_pos := (screen_size - res) / 2
		DisplayServer.window_set_position(screen_pos)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_volume", music_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	cfg.set_value("display", "language", language)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("display", "resolution_index", resolution_index)
	cfg.set_value("gameplay", "speed_multiplier", speed_multiplier)
	cfg.save(SETTINGS_PATH)
	EventBus.settings_saved.emit()

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", 0.7)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 0.8)
	language = cfg.get_value("display", "language", "zh_CN")
	fullscreen = cfg.get_value("display", "fullscreen", false)
	resolution_index = cfg.get_value("display", "resolution_index", 3)
	speed_multiplier = cfg.get_value("gameplay", "speed_multiplier", 2.0)
