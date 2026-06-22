# src/ui/map/map_scene.gd
# 爬塔地图 - 分叉路线图（逐层选择）
class_name MapScene extends Control

const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")
const MAP_NODE_ICON_BATTLE = preload("res://assets/ui/map/map_node_battle.png")
const MAP_NODE_ICON_CAMPFIRE = preload("res://assets/ui/map/map_node_campfire.png")
const MAP_NODE_ICON_CHEST = preload("res://assets/ui/map/map_node_chest.png")
const MAP_NODE_ICON_BOSS = preload("res://assets/ui/map/map_node_boss.png")

@onready var nodes_container: VBoxContainer = $Margin/Body/Scroll/NodesVBox
@onready var scroll: ScrollContainer = $Margin/Body/Scroll
@onready var hp_label: Label = $Margin/Body/Header/HPLabel
@onready var act_label: Label = $Margin/Body/Header/ActLabel
@onready var back_btn: Button = $Margin/Body/Header/BackBtn
@onready var title_label: Label = $Margin/Body/Header/TitleLabel
@onready var build_btn: Button = $Margin/Body/Header/BuildBtn

# Campfire 弹窗
@onready var campfire_panel: PanelContainer = $CampfirePanel
@onready var campfire_title: Label = $CampfirePanel/VBox/TitleLabel
@onready var campfire_rest_btn: Button = $CampfirePanel/VBox/RestBtn
@onready var campfire_forge_btn: Button = $CampfirePanel/VBox/ForgeBtn
@onready var campfire_skip_btn: Button = $CampfirePanel/VBox/SkipBtn

# Forge 子面板
@onready var forge_panel: PanelContainer = $ForgePanel
@onready var forge_title: Label = $ForgePanel/VBox/ForgeTitle
@onready var forge_list_vbox: VBoxContainer = $ForgePanel/VBox/ForgeScroll/ForgeListVBox
@onready var forge_cancel_btn: Button = $ForgePanel/VBox/ForgeCancelBtn

var _node_buttons: Dictionary = {}
var _available_node_ids: Dictionary = {}
var _route_lines: MapRouteLineLayer
var _backdrop: MapBackdropLayer
var _pending_chest_reward: Dictionary = {}

func _ready() -> void:
	if GameState.current_run == null:
		# 未开局，跳回主菜单
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())

	back_btn.pressed.connect(_on_back_pressed)
	build_btn.pressed.connect(_on_build_pressed)
	campfire_rest_btn.pressed.connect(_on_campfire_rest)
	campfire_forge_btn.pressed.connect(_on_campfire_forge)
	campfire_skip_btn.pressed.connect(_on_campfire_skip)
	forge_cancel_btn.pressed.connect(_on_forge_cancel)
	_prepare_overlay_panels()
	campfire_panel.hide()
	forge_panel.hide()
	_ensure_backdrop_layer()
	_ensure_route_line_layer()
	_connect_route_line_redraw()

	# 注：节点推进由战斗后流程负责（正式胜利→RewardScene._finalize；模拟/失败→BattleScene.resolve_post_battle）
	_refresh_ui()

func _prepare_overlay_panels() -> void:
	campfire_panel.z_index = 80
	forge_panel.z_index = 90
	campfire_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	forge_panel.mouse_filter = Control.MOUSE_FILTER_STOP

func _ensure_backdrop_layer() -> void:
	if is_instance_valid(_backdrop):
		return
	_backdrop = MapBackdropLayer.new()
	_backdrop.name = "MapBackdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	move_child(_backdrop, 1) # Above Background, below routes and UI.

func _ensure_route_line_layer() -> void:
	if is_instance_valid(_route_lines):
		return
	_route_lines = MapRouteLineLayer.new()
	_route_lines.name = "RouteLines"
	_route_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_route_lines)
	move_child(_route_lines, 2) # Above backdrop, below Margin/UI.

func _connect_route_line_redraw() -> void:
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null and not vbar.value_changed.is_connected(_on_map_scroll_changed):
		vbar.value_changed.connect(_on_map_scroll_changed)

func _on_map_scroll_changed(_value: float) -> void:
	if is_instance_valid(_route_lines):
		_route_lines.queue_redraw()

func _update_texts() -> void:
	title_label.text = tr("map.title")
	back_btn.text = tr("ui.button.back")
	build_btn.text = tr("build.title")
	campfire_title.text = tr("campfire.title")
	campfire_rest_btn.text = tr("campfire.option.rest")
	campfire_forge_btn.text = tr("campfire.option.forge")
	campfire_skip_btn.text = tr("campfire.option.skip")
	forge_title.text = tr("campfire.forge.title")
	forge_cancel_btn.text = tr("ui.button.cancel")

func _refresh_ui() -> void:
	var run := GameState.current_run
	hp_label.text = "HP: %d / %d" % [run.hp, run.max_hp]
	act_label.text = tr("ui.label.act").format({"act": run.act})
	_rebuild_nodes()

func _rebuild_nodes() -> void:
	for child in nodes_container.get_children():
		child.queue_free()
	_node_buttons.clear()

	var run := GameState.current_run
	var current_idx: int = run.node_index
	var available := MapGenerator.get_available_nodes(run.map_nodes, current_idx, run.current_node_id)
	_available_node_ids.clear()
	for node in available:
		_available_node_ids[str(node.get("id", ""))] = true

	var by_floor := _group_nodes_by_floor(run.map_nodes)
	var floors := by_floor.keys()
	floors.sort()
	floors.reverse()
	for floor in floors:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(0, 116)
		row.add_theme_constant_override(&"separation", 36)
		row.z_index = 1
		nodes_container.add_child(row)

		var nodes_by_lane := _nodes_by_lane(by_floor[floor])
		for lane in range(MapGenerator.LANES):
			if not nodes_by_lane.has(lane):
				row.add_child(_make_lane_spacer())
				continue

			var node_data: Dictionary = nodes_by_lane[lane]
			var idx: int = node_data.get("node_index", floor)
			var node_type: int = node_data["node_type"]
			var enemy_id: String = node_data.get("enemy_id", "")
			var node_id := str(node_data.get("id", ""))

			var btn := MapNodeButton.new()
			btn.setup(node_data, _format_node_label(idx, node_type, enemy_id, int(node_data.get("lane", 0))), _node_caption(node_type, enemy_id))

			if idx <= current_idx:
				btn.disabled = true
				btn.set_visual_state(MapNodeButton.VisualState.COMPLETED)
			elif _available_node_ids.has(node_id):
				btn.set_visual_state(MapNodeButton.VisualState.AVAILABLE)
				btn.pressed.connect(_on_node_pressed.bind(node_data))
			else:
				btn.disabled = true
				btn.set_visual_state(MapNodeButton.VisualState.LOCKED)

			row.add_child(btn)
			_node_buttons[node_id] = btn

	_update_route_lines_deferred(run.map_nodes, run.current_node_id)
	_update_scroll_position_deferred(current_idx)

func _nodes_by_lane(nodes: Array) -> Dictionary:
	var out: Dictionary = {}
	for node in nodes:
		out[int(node.get("lane", 0))] = node
	return out

func _make_lane_spacer() -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = MapNodeButton.NODE_SLOT_SIZE
	spacer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer

func _update_route_lines_deferred(nodes: Array, current_node_id: String) -> void:
	await get_tree().process_frame
	if not is_instance_valid(_route_lines):
		return
	_route_lines.setup(nodes, _node_buttons, current_node_id, _available_node_ids)

func _update_scroll_position_deferred(current_idx: int) -> void:
	await get_tree().process_frame
	if not is_instance_valid(scroll):
		return
	var floors_remaining: int = maxi(MapGenerator.FLOOR_COUNT - current_idx - 2, 0)
	scroll.scroll_vertical = int(floors_remaining * 116)
	await get_tree().process_frame
	if is_instance_valid(_route_lines):
		_route_lines.queue_redraw()

func _group_nodes_by_floor(nodes: Array) -> Dictionary:
	var by_floor: Dictionary = {}
	for node in nodes:
		var floor: int = int(node.get("floor", node.get("node_index", 0)))
		if not by_floor.has(floor):
			by_floor[floor] = []
		by_floor[floor].append(node)
	for floor in by_floor:
		by_floor[floor].sort_custom(func(a, b): return int(a.get("lane", 0)) < int(b.get("lane", 0)))
	return by_floor

func _format_node_label(idx: int, node_type: int, enemy_id: String, lane: int = 0) -> String:
	var type_name: String = ""
	match node_type:
		int(MapGenerator.NodeType.BATTLE):
			type_name = tr("map.node.battle")
		int(MapGenerator.NodeType.CAMPFIRE):
			type_name = tr("map.node.campfire")
		int(MapGenerator.NodeType.BOSS):
			type_name = tr("map.node.boss")
		int(MapGenerator.NodeType.CHEST):
			type_name = tr("map.node.chest")

	var label: String = "[%d-%d] %s" % [idx, lane + 1, type_name]
	if enemy_id != "":
		var loc_key := "enemy.%s.name" % enemy_id
		label += " — " + tr(loc_key)
	return label

func _node_caption(node_type: int, enemy_id: String) -> String:
	match node_type:
		int(MapGenerator.NodeType.BATTLE):
			return tr("enemy.%s.name" % enemy_id) if enemy_id != "" else tr("map.node.battle")
		int(MapGenerator.NodeType.CAMPFIRE):
			return tr("map.node.campfire")
		int(MapGenerator.NodeType.BOSS):
			return tr("map.node.boss")
		int(MapGenerator.NodeType.CHEST):
			return tr("map.node.chest")
	return ""

# ─── 节点点击 ─────────────────────────────────────────────────

func _on_node_pressed(node_data: Dictionary) -> void:
	var node_type: int = node_data["node_type"]
	var enemy_id: String = node_data.get("enemy_id", "")

	match node_type:
		int(MapGenerator.NodeType.BATTLE), int(MapGenerator.NodeType.BOSS):
			# 把目标敌人 id 暂存到 GameState
			GameState.next_battle_enemy_id = enemy_id
			GameState.next_battle_is_boss = (node_type == int(MapGenerator.NodeType.BOSS))
			GameState.pending_map_node_id = str(node_data.get("id", ""))
			get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
		int(MapGenerator.NodeType.CAMPFIRE):
			GameState.pending_map_node_id = str(node_data.get("id", ""))
			campfire_panel.show()
		int(MapGenerator.NodeType.CHEST):
			GameState.pending_map_node_id = str(node_data.get("id", ""))
			_open_chest()

# ─── Chest ───────────────────────────────────────────────────

func _open_chest() -> void:
	_pending_chest_reward = RewardPool.draw_chest()
	if _pending_chest_reward.is_empty():
		_advance_node()
		return
	var reward_name := _reward_display_name(_pending_chest_reward)
	var dialog := AcceptDialog.new()
	dialog.title = tr("chest.title")
	dialog.dialog_text = tr("chest.reward") % reward_name
	dialog.confirmed.connect(_on_chest_confirmed.bind(dialog))
	add_child(dialog)
	dialog.popup_centered()

func _on_chest_confirmed(dialog: AcceptDialog) -> void:
	_apply_chest_reward(_pending_chest_reward)
	_pending_chest_reward.clear()
	if is_instance_valid(dialog):
		dialog.queue_free()
	_advance_node()

func _apply_chest_reward(option: Dictionary) -> void:
	var run := GameState.current_run
	if run == null:
		return
	var reward_type: StringName = option.get("type", &"")
	var resource: Resource = option.get("resource", null)
	if reward_type == &"gem" and resource is GemData:
		run.gems.append(GemInstance.new(resource as GemData))
	elif reward_type == &"relic" and resource is RelicData:
		run.relics.append(resource as RelicData)

func _reward_display_name(option: Dictionary) -> String:
	var reward_type: StringName = option.get("type", &"")
	var resource: Resource = option.get("resource", null)
	if reward_type == &"gem" and resource is GemData:
		return tr((resource as GemData).get_name_key())
	if reward_type == &"relic" and resource is RelicData:
		return tr((resource as RelicData).get_name_key())
	return tr("chest.reward.unknown")

# ─── Campfire ────────────────────────────────────────────────

func _on_campfire_rest() -> void:
	var run := GameState.current_run
	var heal_amount: int = int(ceil(run.max_hp * 0.3))
	run.hp = mini(run.max_hp, run.hp + heal_amount)
	campfire_panel.hide()
	_advance_node()

func _on_campfire_forge() -> void:
	# 打开 forge 子面板
	campfire_panel.hide()
	_rebuild_forge_list()
	forge_panel.show()

func _on_forge_cancel() -> void:
	forge_panel.hide()
	campfire_panel.show()

func _rebuild_forge_list() -> void:
	for child in forge_list_vbox.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override(&"h_separation", 14)
	grid.add_theme_constant_override(&"v_separation", 16)
	forge_list_vbox.add_child(grid)

	var option_count := 0
	for i in range(run.deck.size()):
		var c: CardData = run.deck[i]
		if c == null:
			continue
		if c.upgrade == null:
			continue
		if c.is_upgraded():
			continue
		option_count += 1
		grid.add_child(_make_forge_card_option(c, i))
	if option_count == 0:
		grid.queue_free()
		var lbl := Label.new()
		lbl.text = tr("campfire.forge.no_upgradable")
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		forge_list_vbox.add_child(lbl)

func _make_forge_card_option(card: CardData, deck_index: int) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(CardView.BUILD_DECK_WIDTH, 250)
	box.add_theme_constant_override(&"separation", 6)

	var view := CARD_VIEW_SCENE.instantiate() as CardView
	box.add_child(view)
	view.setup_deck_item(card, 1, 1)
	view.tooltip_text = tr("campfire.forge.upgrade_to") % [tr(card.get_name_key()), tr(card.upgrade.get_name_key())]
	view.pressed.connect(func(_button_index: int): _on_forge_card_picked(card, deck_index))

	var label := Label.new()
	label.text = tr("campfire.forge.upgrade_to") % [tr(card.get_name_key()), tr(card.upgrade.get_name_key())]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", 12)
	box.add_child(label)
	return box

func _on_forge_card_picked(card: CardData, deck_index: int) -> void:
	if card == null or card.upgrade == null:
		return
	var run := GameState.current_run
	if run == null:
		return
	if deck_index < 0 or deck_index >= run.deck.size():
		return
	if run.deck[deck_index] == null or run.deck[deck_index].id != card.id:
		return

	MapScene.upgrade_card_instance(run, deck_index)
	forge_panel.hide()
	_advance_node()

static func upgrade_card_instance(run: RunState, deck_index: int) -> bool:
	if run == null or deck_index < 0 or deck_index >= run.deck.size():
		return false
	var card: CardData = run.deck[deck_index]
	if card == null or card.upgrade == null:
		return false
	run.deck[deck_index] = card.upgrade

	var replaced_chain := false
	for i in range(run.chain_cards.size()):
		if run.chain_cards[i] != null and run.chain_cards[i].id == card.id:
			run.chain_cards[i] = card.upgrade
			replaced_chain = true
			break

	for k in run.base_cards:
		var c: CardData = run.base_cards[k]
		if c != null and c.id == card.id:
			run.base_cards[k] = card.upgrade
			break
	return true

func _on_campfire_skip() -> void:
	campfire_panel.hide()
	_advance_node()

# ─── 节点推进 ─────────────────────────────────────────────────

func _advance_node() -> void:
	var run := GameState.current_run
	if GameState.pending_map_node_id != "":
		run.current_node_id = GameState.pending_map_node_id
		var node := MapGenerator.get_node_by_id(run.map_nodes, GameState.pending_map_node_id)
		run.node_index = int(node.get("floor", node.get("node_index", run.node_index + 1)))
		GameState.pending_map_node_id = ""
	else:
		run.node_index += 1
	var save := SaveSystem.new()
	save.save_run(run)

	if run.node_index >= MapGenerator.FLOOR_COUNT:
		# Run 完成
		GameState.end_run(true)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	_refresh_ui()

# ─── 其他 ────────────────────────────────────────────────────

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_build_pressed() -> void:
	# 告诉 BuildScene "确认/返回"应跳回地图
	GameState.build_return_scene = "res://scenes/map/map_scene.tscn"
	get_tree().change_scene_to_file("res://scenes/build/build_scene.tscn")

class MapRouteLineLayer extends Control:
	var _nodes: Array = []
	var _buttons: Dictionary = {}
	var _current_node_id: String = ""
	var _available_ids: Dictionary = {}

	func setup(nodes: Array, buttons: Dictionary, current_node_id: String, available_ids: Dictionary) -> void:
		_nodes = nodes.duplicate()
		_buttons = buttons.duplicate()
		_current_node_id = current_node_id
		_available_ids = available_ids.duplicate()
		queue_redraw()

	func _draw() -> void:
		for node in _nodes:
			var from_id := str(node.get("id", ""))
			if not _buttons.has(from_id):
				continue
			var from_btn := _buttons[from_id] as Control
			var from_center := _center_in_layer(from_btn)
			for to_var in node.get("next_ids", []):
				var to_id := str(to_var)
				if not _buttons.has(to_id):
					continue
				var to_btn := _buttons[to_id] as Control
				var to_center := _center_in_layer(to_btn)
				var active := _current_node_id == from_id or (_current_node_id == "" and _available_ids.has(from_id))
				var reachable := _available_ids.has(to_id)
				var path_color := Color(0.31, 0.66, 0.60, 0.92) if active or reachable else Color(0.55, 0.68, 0.66, 0.34)
				var path_width := 5.5 if active or reachable else 2.5
				draw_line(from_center, to_center, Color(0.92, 1.0, 0.96, 0.68), path_width + 4.0, true)
				draw_line(from_center, to_center, path_color.darkened(0.18), path_width + 1.8, true)
				draw_line(from_center, to_center, path_color, path_width, true)
				if active or reachable:
					var mid := from_center.lerp(to_center, 0.5)
					draw_circle(mid, 4.0, Color(0.78, 0.96, 0.82, 0.9))

	func _center_in_layer(control: Control) -> Vector2:
		var control_origin := control.get_global_transform_with_canvas().origin
		var layer_origin := get_global_transform_with_canvas().origin
		return control_origin - layer_origin + Vector2(control.size.x * 0.5, 39.0)

class MapBackdropLayer extends Control:
	func _draw() -> void:
		var top := Color(0.90, 0.98, 0.97, 0.28)
		var bottom := Color(0.72, 0.88, 0.87, 0.18)
		for i in range(16):
			var t := float(i) / 15.0
			var y := lerpf(0.0, size.y, t)
			draw_rect(Rect2(0, y, size.x, max(size.y / 16.0 + 1.0, 1.0)), top.lerp(bottom, t))
		for i in range(7):
			var y := size.y * (0.18 + float(i) * 0.12)
			var ridge_color := Color(0.24, 0.52, 0.50, 0.06 + float(i % 3) * 0.025)
			var points := PackedVector2Array()
			points.append(Vector2(-80, y + 34))
			for x in range(-80, int(size.x) + 160, 180):
				var peak := y - 18 - float((x / 180 + i) % 3) * 18.0
				points.append(Vector2(x + 80, peak))
				points.append(Vector2(x + 160, y + 38))
			points.append(Vector2(size.x + 80, size.y + 80))
			points.append(Vector2(-80, size.y + 80))
			draw_colored_polygon(points, ridge_color)
		for i in range(36):
			var x := fmod(float(i * 137), max(size.x, 1.0))
			var y := fmod(float(i * 89), max(size.y, 1.0))
			var alpha := 0.06 + float(i % 4) * 0.020
			draw_circle(Vector2(x, y), 1.2 + float(i % 3), Color(0.42, 0.78, 0.70, alpha))

class MapNodeButton extends Button:
	enum VisualState { LOCKED, AVAILABLE, COMPLETED }
	const NODE_SLOT_SIZE := Vector2(96, 104)

	var node_type: int = 0
	var caption: String = ""
	var visual_state: VisualState = VisualState.LOCKED

	func _init() -> void:
		custom_minimum_size = NODE_SLOT_SIZE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		text = ""
		flat = true
		focus_mode = Control.FOCUS_ALL
		var empty := StyleBoxEmpty.new()
		add_theme_stylebox_override(&"normal", empty)
		add_theme_stylebox_override(&"hover", empty)
		add_theme_stylebox_override(&"pressed", empty)
		add_theme_stylebox_override(&"disabled", empty)
		add_theme_stylebox_override(&"focus", empty)

	func setup(node_data: Dictionary, tooltip: String, new_caption: String) -> void:
		node_type = int(node_data.get("node_type", 0))
		caption = new_caption
		tooltip_text = tooltip
		queue_redraw()

	func set_visual_state(new_state: VisualState) -> void:
		visual_state = new_state
		queue_redraw()

	func _draw() -> void:
		var center := Vector2(size.x * 0.5, 39.0)
		var radius := 31.0 if node_type == int(MapGenerator.NodeType.BOSS) else 27.0
		var palette := _palette()
		var alpha := 1.0 if visual_state != VisualState.LOCKED else 0.58
		var hover_scale := 1.08 if is_hovered() and not disabled else 1.0
		radius *= hover_scale

		draw_circle(center + Vector2(0, 5), radius + 5.0, Color(0.10, 0.30, 0.28, 0.22 * alpha))
		if visual_state == VisualState.AVAILABLE:
			draw_circle(center, radius + 9.0, Color(0.44, 0.82, 0.72, 0.24))
			draw_arc(center, radius + 8.0, -PI * 0.15, PI * 1.35, 48, Color(0.76, 0.96, 0.82, 0.95), 3.0, true)
		draw_circle(center, radius + 3.0, palette["rim"].darkened(0.18))
		draw_circle(center, radius, palette["rim"])

		var icon_color: Color = palette["icon"]
		var icon := _node_texture()
		if icon != null:
			var icon_size := Vector2(67, 67) if node_type == int(MapGenerator.NodeType.BOSS) else Vector2(61, 61)
			var rect := Rect2(center - icon_size * 0.5, icon_size)
			draw_texture_rect(icon, rect, false, _icon_tint())
		else:
			draw_circle(center, radius - 4.0, palette["fill"])
			draw_arc(center, radius - 7.0, PI * 1.12, PI * 1.86, 30, Color(1, 1, 1, 0.18 * alpha), 3.0, true)
			match node_type:
				int(MapGenerator.NodeType.BATTLE):
					_draw_battle_icon(center, icon_color)
				int(MapGenerator.NodeType.CAMPFIRE):
					_draw_campfire_icon(center, icon_color)
				int(MapGenerator.NodeType.BOSS):
					_draw_boss_icon(center, icon_color)
				int(MapGenerator.NodeType.CHEST):
					_draw_chest_icon(center, icon_color)

		if visual_state == VisualState.COMPLETED:
			_draw_check(center + Vector2(22, -22))

		_draw_caption()

	func _palette() -> Dictionary:
		var fill := Color(0.82, 0.94, 0.90, 1)
		var rim := Color(0.42, 0.72, 0.66, 1)
		var icon := Color(0.12, 0.36, 0.34, 1)
		match node_type:
			int(MapGenerator.NodeType.BATTLE):
				fill = Color(0.92, 0.86, 0.82, 1)
				rim = Color(0.68, 0.38, 0.34, 1)
			int(MapGenerator.NodeType.CAMPFIRE):
				fill = Color(0.82, 0.94, 0.84, 1)
				rim = Color(0.48, 0.74, 0.52, 1)
			int(MapGenerator.NodeType.BOSS):
				fill = Color(0.88, 0.84, 0.92, 1)
				rim = Color(0.50, 0.42, 0.72, 1)
			int(MapGenerator.NodeType.CHEST):
				fill = Color(0.94, 0.93, 0.80, 1)
				rim = Color(0.74, 0.68, 0.36, 1)
		if visual_state == VisualState.LOCKED:
			fill = fill.darkened(0.14)
			rim = Color(0.58, 0.68, 0.66, 1)
			icon = Color(0.46, 0.58, 0.56, 1)
		elif visual_state == VisualState.COMPLETED:
			fill = Color(0.78, 0.90, 0.88, 1)
			rim = Color(0.42, 0.62, 0.58, 1)
			icon = Color(0.20, 0.48, 0.44, 1)
		return {"fill": fill, "rim": rim, "icon": icon}

	func _draw_battle_icon(center: Vector2, color: Color) -> void:
		draw_line(center + Vector2(-15, -13), center + Vector2(15, 17), color, 4.0, true)
		draw_line(center + Vector2(15, -13), center + Vector2(-15, 17), color, 4.0, true)
		draw_line(center + Vector2(-18, 14), center + Vector2(-10, 22), color.darkened(0.2), 5.0, true)
		draw_line(center + Vector2(18, 14), center + Vector2(10, 22), color.darkened(0.2), 5.0, true)
		draw_circle(center, 4.0, color.lightened(0.15))

	func _draw_campfire_icon(center: Vector2, color: Color) -> void:
		var flame := PackedVector2Array([
			center + Vector2(0, -19),
			center + Vector2(11, -4),
			center + Vector2(6, 14),
			center + Vector2(-8, 15),
			center + Vector2(-13, 1),
		])
		draw_colored_polygon(flame, color)
		draw_circle(center + Vector2(2, 5), 8.0, Color(0.95, 0.42, 0.18, 0.9))
		draw_line(center + Vector2(-17, 18), center + Vector2(17, 10), color.darkened(0.35), 4.0, true)
		draw_line(center + Vector2(-15, 10), center + Vector2(17, 18), color.darkened(0.35), 4.0, true)

	func _draw_boss_icon(center: Vector2, color: Color) -> void:
		var crown := PackedVector2Array([
			center + Vector2(-20, 8),
			center + Vector2(-15, -13),
			center + Vector2(-5, 0),
			center + Vector2(0, -18),
			center + Vector2(6, 0),
			center + Vector2(17, -13),
			center + Vector2(21, 8),
		])
		draw_colored_polygon(crown, color)
		draw_rect(Rect2(center + Vector2(-18, 8), Vector2(36, 8)), color.darkened(0.18))
		draw_circle(center + Vector2(-12, -13), 3.0, Color(1, 0.78, 0.3, 1))
		draw_circle(center + Vector2(0, -18), 3.0, Color(1, 0.78, 0.3, 1))
		draw_circle(center + Vector2(15, -13), 3.0, Color(1, 0.78, 0.3, 1))

	func _draw_chest_icon(center: Vector2, color: Color) -> void:
		draw_rect(Rect2(center + Vector2(-19, -5), Vector2(38, 24)), color.darkened(0.12))
		draw_rect(Rect2(center + Vector2(-21, -15), Vector2(42, 13)), color)
		draw_line(center + Vector2(-19, 4), center + Vector2(19, 4), Color(0.25, 0.14, 0.07, 0.8), 3.0)
		draw_rect(Rect2(center + Vector2(-5, -3), Vector2(10, 12)), Color(0.98, 0.82, 0.38, 1))

	func _draw_check(center: Vector2) -> void:
		draw_circle(center, 9.0, Color(0.12, 0.38, 0.31, 0.95))
		draw_line(center + Vector2(-5, 0), center + Vector2(-1, 5), Color(0.85, 1, 0.86, 1), 2.5, true)
		draw_line(center + Vector2(-1, 5), center + Vector2(6, -5), Color(0.85, 1, 0.86, 1), 2.5, true)

	func _draw_caption() -> void:
		var font := get_theme_default_font()
		var font_size := 14
		var text_color := Color(0.92, 0.86, 0.68, 1) if visual_state != VisualState.LOCKED else Color(0.62, 0.61, 0.68, 1)
		var label := caption
		if font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > size.x - 4.0:
			label = label.left(4) + ".."
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var pos := Vector2((size.x - text_size.x) * 0.5, 89.0)
		draw_string(font, pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.7))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	func _node_texture() -> Texture2D:
		match node_type:
			int(MapGenerator.NodeType.BATTLE):
				return MAP_NODE_ICON_BATTLE
			int(MapGenerator.NodeType.CAMPFIRE):
				return MAP_NODE_ICON_CAMPFIRE
			int(MapGenerator.NodeType.BOSS):
				return MAP_NODE_ICON_BOSS
			int(MapGenerator.NodeType.CHEST):
				return MAP_NODE_ICON_CHEST
		return null

	func _icon_tint() -> Color:
		match visual_state:
			VisualState.LOCKED:
				return Color(0.48, 0.48, 0.55, 0.68)
			VisualState.COMPLETED:
				return Color(0.62, 0.78, 0.73, 0.82)
		return Color.WHITE
