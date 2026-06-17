# src/ui/settings_panel.gd
# 设置面板
extends Control

signal back_pressed()

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var resolution_label: Label = $PanelContainer/MarginContainer/VBoxContainer/ResolutionRow/ResolutionLabel
@onready var resolution_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/ResolutionRow/ResolutionOption
@onready var fullscreen_check: CheckBox = $PanelContainer/MarginContainer/VBoxContainer/FullscreenCheck
@onready var music_label: Label = $PanelContainer/MarginContainer/VBoxContainer/MusicRow/MusicLabel
@onready var music_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/MusicRow/MusicSlider
@onready var sfx_label: Label = $PanelContainer/MarginContainer/VBoxContainer/SfxRow/SfxLabel
@onready var sfx_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/SfxRow/SfxSlider
@onready var language_label: Label = $PanelContainer/MarginContainer/VBoxContainer/LanguageRow/LanguageLabel
@onready var language_option: OptionButton = $PanelContainer/MarginContainer/VBoxContainer/LanguageRow/LanguageOption
@onready var back_button: Button = $PanelContainer/MarginContainer/VBoxContainer/BackButton

var _locales := ["zh_CN", "en"]
var _locale_names := ["中文", "English"]

func _ready() -> void:
	_build_resolution_options()
	_build_language_options()
	_load_from_settings()
	_connect_signals()
	_update_texts()
	EventBus.language_changed.connect(_on_language_changed)

func _build_resolution_options() -> void:
	resolution_option.clear()
	for res in Settings.RESOLUTIONS:
		resolution_option.add_item("%d × %d" % [res.x, res.y])

func _build_language_options() -> void:
	language_option.clear()
	for name in _locale_names:
		language_option.add_item(name)

func _load_from_settings() -> void:
	resolution_option.selected = Settings.resolution_index
	fullscreen_check.button_pressed = Settings.fullscreen
	music_slider.value = Settings.music_volume
	sfx_slider.value = Settings.sfx_volume
	var lang_idx := _locales.find(Settings.language)
	language_option.selected = lang_idx if lang_idx >= 0 else 0

func _connect_signals() -> void:
	resolution_option.item_selected.connect(_on_resolution_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	language_option.item_selected.connect(_on_language_option_selected)
	back_button.pressed.connect(_on_back_pressed)

func _on_resolution_changed(index: int) -> void:
	Settings.set_resolution_index(index)

func _on_fullscreen_toggled(pressed: bool) -> void:
	Settings.set_fullscreen(pressed)

func _on_music_changed(value: float) -> void:
	Settings.music_volume = value
	Settings.save_settings()

func _on_sfx_changed(value: float) -> void:
	Settings.sfx_volume = value
	Settings.save_settings()

func _on_language_option_selected(index: int) -> void:
	Settings.set_language(_locales[index])

func _on_back_pressed() -> void:
	back_pressed.emit()

func _on_language_changed(_locale: String) -> void:
	_update_texts()

func _update_texts() -> void:
	title_label.text = tr("menu.settings.title")
	resolution_label.text = tr("menu.settings.resolution")
	fullscreen_check.text = tr("menu.settings.fullscreen")
	music_label.text = tr("menu.settings.music_volume")
	sfx_label.text = tr("menu.settings.sfx_volume")
	language_label.text = tr("menu.settings.language")
	back_button.text = tr("menu.settings.back")
