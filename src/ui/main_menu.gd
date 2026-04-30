# src/ui/main_menu.gd
# 主菜单 UI 控制器
extends Control

@onready var start_button: Button = $CenterContainer/VBoxContainer/StartButton
@onready var continue_button: Button = $CenterContainer/VBoxContainer/ContinueButton
@onready var settings_button: Button = $CenterContainer/VBoxContainer/SettingsButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/Title

func _ready() -> void:
	_update_texts()
	_setup_buttons()
	_update_continue_visibility()
	EventBus.language_changed.connect(_on_language_changed)

func _update_texts() -> void:
	title_label.text = tr("menu.main.title") if TranslationServer.has_translation("menu.main.title") else "时序录"
	start_button.text = tr("menu.main.start")
	continue_button.text = tr("menu.main.continue")
	settings_button.text = tr("menu.main.settings")
	quit_button.text = tr("menu.main.quit")

func _setup_buttons() -> void:
	start_button.pressed.connect(_on_start_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _update_continue_visibility() -> void:
	var save_sys := SaveSystem.new()
	continue_button.visible = save_sys.has_active_run()

func _on_start_pressed() -> void:
	GameState.start_run(&"sword")
	get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")

func _on_settings_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_language_changed(_locale: String) -> void:
	_update_texts()

func _input(event: InputEvent) -> void:
	if GameState.is_smoke_test and event is InputEventMouseButton and event.pressed:
		_on_start_pressed()
