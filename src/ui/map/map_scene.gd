# src/ui/map/map_scene.gd
# 爬塔地图 - 阶段 1 MVP（线性 10 节点 + Boss）
class_name MapScene extends Control

@onready var nodes_container: VBoxContainer = $Margin/Body/Scroll/NodesVBox
@onready var hp_label: Label = $Margin/Body/Header/HPLabel
@onready var act_label: Label = $Margin/Body/Header/ActLabel
@onready var back_btn: Button = $Margin/Body/Header/BackBtn
@onready var title_label: Label = $Margin/Body/Header/TitleLabel
@onready var build_btn: Button = $Margin/Body/Header/BuildBtn

# Campfire 弹窗
@onready var campfire_panel: PanelContainer = $CampfirePanel
@onready var campfire_title: Label = $CampfirePanel/VBox/TitleLabel
@onready var campfire_rest_btn: Button = $CampfirePanel/VBox/RestBtn
@onready var campfire_skip_btn: Button = $CampfirePanel/VBox/SkipBtn

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
	campfire_skip_btn.pressed.connect(_on_campfire_skip)
	campfire_panel.hide()

	# 注：节点推进由战斗后流程负责（正式胜利→RewardScene._finalize；模拟/失败→BattleScene.resolve_post_battle）
	_refresh_ui()

func _update_texts() -> void:
	title_label.text = tr("map.title")
	back_btn.text = tr("ui.button.back")
	build_btn.text = tr("build.title")
	campfire_title.text = tr("campfire.title")
	campfire_rest_btn.text = tr("campfire.option.rest")
	campfire_skip_btn.text = tr("campfire.option.skip")

func _refresh_ui() -> void:
	var run := GameState.current_run
	hp_label.text = "HP: %d / %d" % [run.hp, run.max_hp]
	act_label.text = tr("ui.label.act").format({"act": run.act})
	_rebuild_nodes()

func _rebuild_nodes() -> void:
	for child in nodes_container.get_children():
		child.queue_free()

	var run := GameState.current_run
	var current_idx: int = run.node_index

	for node_data in run.map_nodes:
		var idx: int = node_data["node_index"]
		var node_type: int = node_data["node_type"]
		var enemy_id: String = node_data.get("enemy_id", "")

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(360, 56)
		btn.text = _format_node_label(idx, node_type, enemy_id)

		# 状态：已通过 / 当前 / 未来
		if idx <= current_idx:
			btn.disabled = true
			btn.modulate = Color(0.45, 0.45, 0.45)  # 已通过：灰
		elif idx == current_idx + 1:
			btn.modulate = Color(1.2, 1.1, 0.7)  # 当前可选：金色
			btn.pressed.connect(_on_node_pressed.bind(node_data))
		else:
			btn.disabled = true
			btn.modulate = Color(0.7, 0.7, 0.8)  # 未来：暗

		nodes_container.add_child(btn)

func _format_node_label(idx: int, node_type: int, enemy_id: String) -> String:
	var type_name: String = ""
	match node_type:
		int(MapGenerator.NodeType.BATTLE):
			type_name = tr("map.node.battle")
		int(MapGenerator.NodeType.CAMPFIRE):
			type_name = tr("map.node.campfire")
		int(MapGenerator.NodeType.BOSS):
			type_name = tr("map.node.boss")

	var label: String = "[%d] %s" % [idx, type_name]
	if enemy_id != "":
		var loc_key := "enemy.%s.name" % enemy_id
		label += " — " + tr(loc_key)
	return label

# ─── 节点点击 ─────────────────────────────────────────────────

func _on_node_pressed(node_data: Dictionary) -> void:
	var node_type: int = node_data["node_type"]
	var enemy_id: String = node_data.get("enemy_id", "")

	match node_type:
		int(MapGenerator.NodeType.BATTLE), int(MapGenerator.NodeType.BOSS):
			# 把目标敌人 id 暂存到 GameState
			GameState.next_battle_enemy_id = enemy_id
			GameState.next_battle_is_boss = (node_type == int(MapGenerator.NodeType.BOSS))
			get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")
		int(MapGenerator.NodeType.CAMPFIRE):
			campfire_panel.show()

# ─── Campfire ────────────────────────────────────────────────

func _on_campfire_rest() -> void:
	var run := GameState.current_run
	var heal_amount: int = int(ceil(run.max_hp * 0.3))
	run.hp = mini(run.max_hp, run.hp + heal_amount)
	campfire_panel.hide()
	_advance_node()

func _on_campfire_skip() -> void:
	campfire_panel.hide()
	_advance_node()

# ─── 节点推进 ─────────────────────────────────────────────────

func _advance_node() -> void:
	GameState.current_run.node_index += 1
	var save := SaveSystem.new()
	save.save_run(GameState.current_run)

	if GameState.current_run.node_index >= GameState.current_run.map_nodes.size():
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
