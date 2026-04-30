# src/ui/battle/battle_scene.gd
# 战斗主场景 UI 控制器（骨架，阶段 1 完整实现）
extends Control

@onready var hp_label: Label = $TopBar/HPLabel
@onready var speed_1x: Button = $TopBar/SpeedContainer/Speed1x
@onready var speed_2x: Button = $TopBar/SpeedContainer/Speed2x
@onready var speed_4x: Button = $TopBar/SpeedContainer/Speed4x
@onready var surrender_button: Button = $TopBar/SurrenderButton

func _ready() -> void:
	_update_texts()
	_setup_speed_buttons()
	surrender_button.pressed.connect(_on_surrender_pressed)
	EventBus.combatant_hp_changed.connect(_on_hp_changed)
	EventBus.language_changed.connect(func(_l): _update_texts())

func _update_texts() -> void:
	speed_1x.text = tr("battle.button.speed_1x")
	speed_2x.text = tr("battle.button.speed_2x")
	speed_4x.text = tr("battle.button.speed_4x")
	surrender_button.text = tr("battle.button.surrender")

func _setup_speed_buttons() -> void:
	speed_1x.pressed.connect(func(): _set_speed(1.0))
	speed_2x.pressed.connect(func(): _set_speed(2.0))
	speed_4x.pressed.connect(func(): _set_speed(4.0))

func _set_speed(mult: float) -> void:
	EventBus.speed_changed.emit(mult)

func _on_hp_changed(combatant_id: StringName, _old: int, new_hp: int) -> void:
	if combatant_id == &"sword":
		hp_label.text = "HP: %d" % new_hp

func _on_surrender_pressed() -> void:
	EventBus.battle_ended.emit(BattleContext.Winner.ENEMY)
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("surrender"):
		_on_surrender_pressed()
