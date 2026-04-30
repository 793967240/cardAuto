# src/globals/settings.gd
# 玩家设置单例
# AutoLoad 为 "Settings"
extends Node

const SETTINGS_PATH := "user://settings.cfg"

var music_volume: float = 0.7
var sfx_volume: float = 0.8
var language: String = "zh_CN"
var fullscreen: bool = false
var resolution_index: int = 0
var speed_multiplier: float = 2.0   # 默认 2x

func _ready() -> void:
	load_settings()
	_apply_language(language)

## 切换语言
func set_language(locale: String) -> void:
	language = locale
	_apply_language(locale)
	save_settings()
	EventBus.language_changed.emit(locale)

func _apply_language(locale: String) -> void:
	TranslationServer.set_locale(locale)

## 保存设置
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

## 加载设置
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	music_volume = cfg.get_value("audio", "music_volume", 0.7)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 0.8)
	language = cfg.get_value("display", "language", "zh_CN")
	fullscreen = cfg.get_value("display", "fullscreen", false)
	resolution_index = cfg.get_value("display", "resolution_index", 0)
	speed_multiplier = cfg.get_value("gameplay", "speed_multiplier", 2.0)
