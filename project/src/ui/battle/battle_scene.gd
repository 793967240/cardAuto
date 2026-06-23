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
const RELIC_RUNTIME_SCRIPT = preload("res://src/core/relic_runtime.gd")
const DIALOG_PANEL_STYLE = preload("res://assets/ui/themes/xianxia/dialogs/dialog_panel_xianxia.tres")
const SPEED_BUTTON_NORMAL_STYLE = preload("res://assets/ui/themes/xianxia/buttons/btn_flat_normal.tres")
const SPEED_BUTTON_HOVER_STYLE = preload("res://assets/ui/themes/xianxia/buttons/btn_flat_hover.tres")
const SPEED_BUTTON_PRESSED_STYLE = preload("res://assets/ui/themes/xianxia/buttons/btn_flat_pressed.tres")
const MAX_LOG_LINES := 80
const SHORT_CYCLE_HEAL_THRESHOLD := 2
const SHORT_CYCLE_GOLD_THRESHOLD := 1
const SHORT_CYCLE_HEAL_RATIO := 0.10
const SHORT_CYCLE_GOLD_BONUS := 10

var _player_max_hp: int = 80
var _battle_start_hp: int = 80
var _total_logged_damage := 0
var _total_logged_heal := 0
var _battle_result_popup: Control = null

func _ready() -> void:
	var speed_group := ButtonGroup.new()
	speed_1x_btn.button_group = speed_group
	speed_2x_btn.button_group = speed_group
	speed_4x_btn.button_group = speed_group
	speed_1x_btn.button_pressed = true
	_apply_speed_button_styles()

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

func _apply_speed_button_styles() -> void:
	var buttons: Array[Button] = [speed_1x_btn, speed_2x_btn, speed_4x_btn]
	for button in buttons:
		button.add_theme_stylebox_override(&"normal", SPEED_BUTTON_NORMAL_STYLE)
		button.add_theme_stylebox_override(&"hover", SPEED_BUTTON_HOVER_STYLE)
		button.add_theme_stylebox_override(&"pressed", SPEED_BUTTON_PRESSED_STYLE)
		button.add_theme_stylebox_override(&"focus", SPEED_BUTTON_HOVER_STYLE)
		button.add_theme_stylebox_override(&"disabled", SPEED_BUTTON_NORMAL_STYLE)

func _init_battle() -> void:
	_clear_battle_log()
	var run := GameState.current_run
	if run:
		_player_max_hp = run.max_hp
		_battle_start_hp = run.hp
	relic_bar.refresh()

	var player := Combatant.new(&"player", tr("player.name"), _player_max_hp)
	if run:
		player.hp = run.hp
	player.tags.append(&"sword")
	if run:
		player.relic_runtime = RELIC_RUNTIME_SCRIPT.new(run.relics)

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
	if enemy_data.portrait != null:
		enemy_view.set_meta("portrait", enemy_data.portrait)
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
		var summary := _build_battle_result_summary()
		var bonus := BattleScene.apply_short_cycle_victory_bonus(GameState.current_run, int(summary.get("cycles_completed", 999)))
		summary["post_heal"] = int(bonus.get("healed", 0))
		summary["post_gold"] = int(bonus.get("gold", 0))
		_show_battle_result_popup(summary)
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

func _build_battle_result_summary() -> Dictionary:
	var stats: BattleContext.BattleStats = null
	if battle_controller != null and battle_controller.ctx != null:
		stats = battle_controller.ctx.stats
	var ticks := stats.total_ticks if stats != null else 0
	var player_hp := GameState.current_run.hp if GameState.current_run != null else _battle_start_hp
	return {
		"ticks": ticks,
		"seconds": float(ticks) * Tuning.get_default().tick_duration_sec,
		"start_hp": _battle_start_hp,
		"hp_before_post": player_hp,
		"damage_taken": stats.damage_taken if stats != null else 0,
		"battle_heal": stats.healing_done if stats != null else 0,
		"cycles_completed": stats.player_cycles_completed if stats != null else 999,
		"post_heal": 0,
		"post_gold": 0,
	}

func _show_battle_result_popup(summary: Dictionary) -> void:
	if is_instance_valid(_battle_result_popup):
		_battle_result_popup.queue_free()

	var panel := PanelContainer.new()
	panel.name = "BattleResultPopup"
	panel.custom_minimum_size = Vector2(560, 420)
	panel.z_index = 200
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(&"panel", DIALOG_PANEL_STYLE)
	add_child(panel)
	_battle_result_popup = panel

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 40)
	margin.add_theme_constant_override(&"margin_top", 34)
	margin.add_theme_constant_override(&"margin_right", 40)
	margin.add_theme_constant_override(&"margin_bottom", 30)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	margin.add_child(box)

	var title := Label.new()
	title.text = tr("battle.result.title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 28)
	title.add_theme_color_override(&"font_color", Color(0.10, 0.34, 0.34, 1))
	box.add_child(title)

	var lines := _battle_result_lines(summary)
	for line in lines:
		var label := Label.new()
		label.text = line
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override(&"font_size", 17)
		label.add_theme_color_override(&"font_color", Color(0.20, 0.38, 0.35, 1))
		box.add_child(label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	box.add_child(spacer)

	var confirm := Button.new()
	confirm.text = tr("battle.result.continue")
	confirm.custom_minimum_size = Vector2(180, 48)
	confirm.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm.pressed.connect(_on_battle_result_confirmed)
	box.add_child(confirm)

	await get_tree().process_frame
	var viewport_size := get_viewport_rect().size
	panel.size = panel.custom_minimum_size
	panel.position = (viewport_size - panel.size) * 0.5

func _battle_result_lines(summary: Dictionary) -> Array[String]:
	var ticks := int(summary.get("ticks", 0))
	var seconds := float(summary.get("seconds", 0.0))
	var start_hp := int(summary.get("start_hp", 0))
	var hp_before_post := int(summary.get("hp_before_post", start_hp))
	var damage_taken := int(summary.get("damage_taken", 0))
	var battle_heal := int(summary.get("battle_heal", 0))
	var post_heal := int(summary.get("post_heal", 0))
	var post_gold := int(summary.get("post_gold", 0))
	var hp_after_post := mini(_player_max_hp, hp_before_post + post_heal)
	var net_loss := maxi(0, start_hp - hp_after_post)

	var lines: Array[String] = []
	lines.append(tr("battle.result.time") % [ticks, seconds])
	lines.append(tr("battle.result.damage_taken") % damage_taken)
	lines.append(tr("battle.result.battle_heal") % battle_heal)
	lines.append(tr("battle.result.hp_change") % [start_hp, hp_after_post, net_loss])
	if post_heal > 0:
		lines.append(tr("battle.result.post_heal") % post_heal)
	else:
		lines.append(tr("battle.result.no_post_heal"))
	if post_gold > 0:
		lines.append(tr("battle.result.post_gold") % post_gold)
	return lines

func _on_battle_result_confirmed() -> void:
	if is_instance_valid(_battle_result_popup):
		_battle_result_popup.queue_free()
	_battle_result_popup = null
	get_tree().change_scene_to_file("res://scenes/reward/reward_scene.tscn")

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
		return Color(0.13, 0.50, 0.38, 1.0)
	return Color(0.68, 0.24, 0.22, 1.0)
