class_name BattleScene extends Control

@onready var battle_controller: BattleController = $BattleController
@onready var player_hp_label: Label = $VBox/TopBarPanel/TopBarMargin/TopBar/PlayerHpLabel
@onready var player_hp_bar: ProgressBar = $VBox/TopBarPanel/TopBarMargin/TopBar/HpBar
@onready var relic_bar: RelicBar = $VBox/TopBarPanel/TopBarMargin/TopBar/RelicBar
@onready var build_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/BuildBtn
@onready var start_battle_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/StartBattleBtn
@onready var speed_1x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed1xBtn
@onready var speed_2x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed2xBtn
@onready var speed_4x_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/Speed4xBtn
@onready var surrender_btn: Button = $VBox/TopBarPanel/TopBarMargin/TopBar/SurrenderBtn
@onready var enemy_timeline_scroll_view: TimelineScrollView = $VBox/EnemyTimelineArea/EnemyTimelineScrollView
@onready var enemy_container: HBoxContainer = $VBox/Center/EnemyContainer
@onready var battle_info_title: Label = $VBox/Center/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/BattleInfoTitle
@onready var battle_info_summary: Label = $VBox/Center/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/BattleInfoSummary
@onready var battle_log_scroll: ScrollContainer = $VBox/Center/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/BattleLogScroll
@onready var battle_log_vbox: VBoxContainer = $VBox/Center/BattleInfoPanel/BattleInfoMargin/BattleInfoVBox/BattleLogScroll/BattleLogVBox
@onready var timeline_scroll_view: TimelineScrollView = $VBox/Bottom/TimelineScrollView

const ENEMY_VIEW_SCENE = preload("res://scenes/battle/enemy_view.tscn")
const MAX_LOG_LINES := 80
const SHORT_CYCLE_HEAL_THRESHOLD := 2
const SHORT_CYCLE_GOLD_THRESHOLD := 1
const SHORT_CYCLE_HEAL_RATIO := 0.10
const SHORT_CYCLE_GOLD_BONUS := 10

var _player_max_hp: int = 80
var _total_logged_damage := 0
var _total_logged_heal := 0

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
	EventBus.battle_log_event.connect(_on_battle_log_event)
	EventBus.battle_ended.connect(_on_battle_ended)

	_init_battle()
	_enter_waiting_to_start_state()

func _init_battle() -> void:
	_clear_battle_log()
	var run := GameState.current_run
	if run:
		_player_max_hp = run.max_hp
	relic_bar.refresh()

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
	enemy_timeline_scroll_view.setup(enemy.combatant_id, enemy.chain, false)
	timeline_scroll_view.setup(player.combatant_id, player.chain, true)

	var enemy_view := ENEMY_VIEW_SCENE.instantiate() as EnemyView
	enemy_container.add_child(enemy_view)
	enemy_view.setup(enemy)
	enemy_view.clicked.connect(_on_enemy_clicked)

	battle_controller.start_battle(player, [enemy])

	if battle_controller.ctx and battle_controller.ctx.timeline:
		enemy_timeline_scroll_view.bind_timeline(battle_controller.ctx.timeline)
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

func _on_battle_log_event(event: Dictionary) -> void:
	var event_type := String(event.get("type", ""))
	var amount := int(event.get("amount", 0))
	if amount <= 0:
		return
	if event_type == "damage":
		_total_logged_damage += amount
	elif event_type == "heal":
		_total_logged_heal += amount
	else:
		return
	_update_battle_log_summary()
	_append_battle_log_line(_format_battle_log_event(event), _color_for_battle_log_event(event_type))

func _on_battle_ended(winner: int) -> void:
	await get_tree().create_timer(1.0).timeout

	if not GameState.is_simulation \
			and winner == BattleContext.Winner.PLAYER \
			and GameState.current_run != null:
		var cycles_completed := 999
		if battle_controller != null and battle_controller.ctx != null:
			cycles_completed = battle_controller.ctx.stats.player_cycles_completed
		BattleScene.apply_short_cycle_victory_bonus(GameState.current_run, cycles_completed)
		get_tree().change_scene_to_file("res://scenes/reward/reward_scene.tscn")
		return

	var next_scene := resolve_post_battle(winner)
	get_tree().change_scene_to_file(next_scene)

static func resolve_post_battle(winner: int) -> String:
	if GameState.is_simulation:
		GameState.is_simulation = false
		return "res://scenes/build/build_scene.tscn"
	if winner == BattleContext.Winner.PLAYER and GameState.current_run != null:
		if GameState.pending_map_node_id != "":
			GameState.current_run.current_node_id = GameState.pending_map_node_id
			var node := MapGenerator.get_node_by_id(GameState.current_run.map_nodes, GameState.pending_map_node_id)
			GameState.current_run.node_index = int(node.get("floor", node.get("node_index", GameState.current_run.node_index + 1)))
			GameState.pending_map_node_id = ""
		else:
			GameState.current_run.node_index += 1
		var save := SaveSystem.new()
		save.save_run(GameState.current_run)
		return "res://scenes/map/map_scene.tscn"
	if GameState.current_run:
		GameState.end_run(false)
	return "res://scenes/main_menu.tscn"

static func apply_short_cycle_victory_bonus(run: RunState, cycles_completed: int) -> Dictionary:
	var result := {
		"healed": 0,
		"gold": 0,
	}
	if run == null:
		return result
	if cycles_completed <= SHORT_CYCLE_HEAL_THRESHOLD:
		var heal_amount := maxi(1, int(ceil(float(run.max_hp) * SHORT_CYCLE_HEAL_RATIO)))
		var old_hp := run.hp
		run.hp = mini(run.max_hp, run.hp + heal_amount)
		result["healed"] = run.hp - old_hp
	if cycles_completed <= SHORT_CYCLE_GOLD_THRESHOLD:
		run.gold += SHORT_CYCLE_GOLD_BONUS
		result["gold"] = SHORT_CYCLE_GOLD_BONUS
	return result

func _on_start_battle_pressed() -> void:
	battle_controller.set_paused(false)
	start_battle_btn.visible = false
	build_btn.visible = false
	speed_1x_btn.disabled = false
	speed_2x_btn.disabled = false
	speed_4x_btn.disabled = false
	surrender_btn.disabled = false

func _on_build_pressed() -> void:
	GameState.build_return_scene = "res://scenes/battle/battle_scene.tscn"
	get_tree().change_scene_to_file("res://scenes/build/build_scene.tscn")

func _enter_waiting_to_start_state() -> void:
	battle_controller.set_paused(true)
	build_btn.visible = true
	start_battle_btn.visible = true
	start_battle_btn.disabled = false
	speed_1x_btn.disabled = true
	speed_2x_btn.disabled = true
	speed_4x_btn.disabled = true
	surrender_btn.disabled = true

func _on_enemy_clicked(id: StringName) -> void:
	print("Enemy clicked, show Gantt chart for: ", id)

func _clear_battle_log() -> void:
	_total_logged_damage = 0
	_total_logged_heal = 0
	battle_info_title.text = tr("battle.label.info")
	for child in battle_log_vbox.get_children():
		child.queue_free()
	_update_battle_log_summary()

func _update_battle_log_summary() -> void:
	battle_info_summary.text = tr("battle.log.summary") % [_total_logged_damage, _total_logged_heal]

func _append_battle_log_line(text: String, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", 13)
	battle_log_vbox.add_child(label)
	while battle_log_vbox.get_child_count() > MAX_LOG_LINES:
		battle_log_vbox.get_child(0).queue_free()
	await get_tree().process_frame
	var bar := battle_log_scroll.get_v_scroll_bar()
	if bar:
		battle_log_scroll.scroll_vertical = int(bar.max_value)

func _format_battle_log_event(event: Dictionary) -> String:
	var source_name := String(event.get("source_name", ""))
	var target_name := String(event.get("target_name", ""))
	var label_key := String(event.get("source_label_key", ""))
	var source_label := tr(label_key) if label_key != "" else ""
	var amount := int(event.get("amount", 0))
	var tick := int(event.get("tick", 0))
	if String(event.get("type", "")) == "heal":
		return tr("battle.log.heal") % [tick, _format_actor(source_name), _format_source(source_label), amount]
	return tr("battle.log.damage") % [
		tick,
		_format_actor(source_name),
		_format_actor(target_name),
		_format_source(source_label),
		amount,
	]

func _format_actor(actor_name: String) -> String:
	return actor_name if actor_name != "" else tr("battle.log.unknown")

func _format_source(source_label: String) -> String:
	if source_label == "":
		return tr("battle.log.source.default")
	return source_label

func _color_for_battle_log_event(event_type: String) -> Color:
	if event_type == "heal":
		return Color(0.56, 0.95, 0.62, 1.0)
	return Color(0.96, 0.66, 0.50, 1.0)
