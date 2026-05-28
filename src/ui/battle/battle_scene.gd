class_name BattleScene extends Control

@onready var battle_controller: BattleController = $BattleController
@onready var player_hp_label: Label = $VBox/TopBarPanel/TopBarMargin/TopBar/PlayerHpLabel
@onready var player_hp_bar: ProgressBar = $VBox/TopBarPanel/TopBarMargin/TopBar/HpBar
@onready var build_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/BuildBtn
@onready var start_battle_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/StartBattleBtn
@onready var speed_1x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed1xBtn
@onready var speed_2x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed2xBtn
@onready var speed_4x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed4xBtn
@onready var surrender_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/SurrenderBtn
@onready var enemy_container: HBoxContainer = $VBox/Center/EnemyContainer
@onready var timeline_scroll_view: TimelineScrollView = $VBox/Bottom/TimelineScrollView

const ENEMY_VIEW_SCENE = preload("res://scenes/battle/enemy_view.tscn")

var _player_max_hp: int = 80

func _ready() -> void:
	var speed_group := ButtonGroup.new()
	speed_1x_btn.button_group = speed_group
	speed_2x_btn.button_group = speed_group
	speed_4x_btn.button_group = speed_group
	speed_1x_btn.button_pressed = true

	build_btn.pressed.connect(_on_build_pressed)
	start_battle_btn.pressed.connect(_on_start_battle_pressed)
	speed_1x_btn.pressed.connect(func(): EventBus.speed_changed.emit(1.0))
	speed_2x_btn.pressed.connect(func(): EventBus.speed_changed.emit(2.0))
	speed_4x_btn.pressed.connect(func(): EventBus.speed_changed.emit(4.0))
	surrender_btn.pressed.connect(func(): battle_controller.surrender())

	build_btn.text = tr("battle.button.adjust_chain")
	start_battle_btn.text = tr("battle.button.start_battle")
	surrender_btn.text = tr("battle.button.surrender")

	EventBus.combatant_hp_changed.connect(_on_hp_changed)
	EventBus.battle_ended.connect(_on_battle_ended)

	_init_battle()

func _init_battle() -> void:
	var run := GameState.current_run
	if run:
		_player_max_hp = run.max_hp

	var player := Combatant.new(&"player", tr("player.name"), _player_max_hp)
	if run:
		player.hp = run.hp
	player.tags.append(&"sword")

	var used_layout := false
	if run and not run.bases.is_empty():
		var spec := ChainComposer.Spec.new()
		spec.bases = run.bases.duplicate()
		spec.base_cards = run.base_cards.duplicate()
		spec.base_gems = run.base_gems.duplicate()
		var result := ChainComposer.compose(spec)
		if result.errors.is_empty() and not result.layout.is_empty():
			player.chain.set_layout(result.layout)
			used_layout = true
		else:
			if not result.errors.is_empty():
				push_warning("BattleScene: ChainComposer errors %s, fall back to chain_cards" % str(result.errors))
	if not used_layout:
		var player_cards: Array[CardRuntime] = []
		if run and not run.chain_cards.is_empty():
			for c in run.chain_cards:
				if c != null:
					player_cards.append(CardRuntime.new(c))
		if player_cards.is_empty():
			var default_paths := [
				"res://data/cards/sword/zhan.tres",
				"res://data/cards/sword/xu_shi.tres",
				"res://data/cards/sword/qiang_pi.tres",
				"res://data/cards/sword/yu_jian_dun.tres",
				"res://data/cards/sword/hui_xiang_jian.tres"
			]
			for path in default_paths:
				var cdata := load(path) as CardData
				if cdata:
					player_cards.append(CardRuntime.new(cdata))
		player.chain.set_slots(player_cards)

	var enemy_id := GameState.next_battle_enemy_id if GameState.next_battle_enemy_id != "" else "slime"
	var enemy_path := "res://data/enemies/%s.tres" % enemy_id
	var enemy_data := load(enemy_path) as EnemyData
	if enemy_data == null:
		enemy_data = load("res://data/enemies/slime.tres") as EnemyData

	var enemy := Combatant.new(enemy_data.id, tr(enemy_data.display_name_key), enemy_data.max_hp)
	enemy.tags.append_array(enemy_data.tags)
	var enemy_cards: Array[CardRuntime] = []
	for c in enemy_data.deck:
		enemy_cards.append(CardRuntime.new(c))
	enemy.chain.set_slots(enemy_cards)

	player_hp_bar.max_value = _player_max_hp
	player_hp_bar.value = player.hp
	player_hp_label.text = "%d / %d" % [player.hp, _player_max_hp]
	timeline_scroll_view.setup(player.combatant_id, player.chain, true)

	var enemy_view := ENEMY_VIEW_SCENE.instantiate() as EnemyView
	enemy_container.add_child(enemy_view)
	enemy_view.setup(enemy)
	enemy_view.clicked.connect(_on_enemy_clicked)

	battle_controller.start_battle(player, [enemy])

	if battle_controller.ctx and battle_controller.ctx.timeline:
		timeline_scroll_view.bind_timeline(battle_controller.ctx.timeline)
		enemy_view.bind_timeline(battle_controller.ctx.timeline)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo()):
		if GameState.is_simulation:
			GameState.is_simulation = false
			get_tree().change_scene_to_file("res://scenes/build/build_scene.tscn")
			return
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	elif event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_SPACE:
				battle_controller.toggle_pause()
			KEY_1:
				speed_1x_btn.button_pressed = true
				EventBus.speed_changed.emit(1.0)
			KEY_2:
				speed_2x_btn.button_pressed = true
				EventBus.speed_changed.emit(2.0)
			KEY_3:
				speed_4x_btn.button_pressed = true
				EventBus.speed_changed.emit(4.0)
			KEY_TAB:
				print("Toggle Gantt chart")

func _on_hp_changed(id: StringName, _old_hp: int, new_hp: int) -> void:
	if id == &"player":
		player_hp_bar.value = new_hp
		player_hp_label.text = "%d / %d" % [new_hp, _player_max_hp]
		if GameState.is_simulation:
			return
		if GameState.current_run:
			GameState.current_run.hp = new_hp

func _on_battle_ended(winner: int) -> void:
	await get_tree().create_timer(1.0).timeout

	if not GameState.is_simulation \
			and winner == BattleContext.Winner.PLAYER \
			and GameState.current_run != null:
		get_tree().change_scene_to_file("res://scenes/reward/reward_scene.tscn")
		return

	var next_scene := resolve_post_battle(winner)
	get_tree().change_scene_to_file(next_scene)

static func resolve_post_battle(winner: int) -> String:
	if GameState.is_simulation:
		GameState.is_simulation = false
		return "res://scenes/build/build_scene.tscn"
	if winner == BattleContext.Winner.PLAYER and GameState.current_run != null:
		GameState.current_run.node_index += 1
		var save := SaveSystem.new()
		save.save_run(GameState.current_run)
		return "res://scenes/map/map_scene.tscn"
	if GameState.current_run:
		GameState.end_run(false)
	return "res://scenes/main_menu.tscn"

func _on_start_battle_pressed() -> void:
	battle_controller.set_paused(false)
	start_battle_btn.hide()
	build_btn.hide()
	speed_1x_btn.disabled = false
	speed_2x_btn.disabled = false
	speed_4x_btn.disabled = false
	surrender_btn.disabled = false

func _on_build_pressed() -> void:
	GameState.build_return_scene = "res://scenes/battle/battle_scene.tscn"
	get_tree().change_scene_to_file("res://scenes/build/build_scene.tscn")

func _on_enemy_clicked(id: StringName) -> void:
	print("Enemy clicked, show Gantt chart for: ", id)
