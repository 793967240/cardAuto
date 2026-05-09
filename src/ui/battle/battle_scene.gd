# src/ui/battle/battle_scene.gd
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
	# 速度按钮组：使用 ButtonGroup 实现互斥 toggle
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

	# i18n
	build_btn.text = tr("battle.button.adjust_chain")
	start_battle_btn.text = tr("battle.button.start_battle")
	surrender_btn.text = tr("battle.button.surrender")

	# 监听 EventBus
	EventBus.combatant_hp_changed.connect(_on_hp_changed)
	EventBus.battle_ended.connect(_on_battle_ended)

	_init_battle()

func _init_battle() -> void:
	# 1. 创建玩家：优先从 RunState 读取，没有则用默认配置
	var run := GameState.current_run
	if run:
		_player_max_hp = run.max_hp

	var player := Combatant.new(&"player", tr("player.name"), _player_max_hp)
	if run:
		player.hp = run.hp
	player.tags.append(&"sword")  # 剑修

	# 构建玩家链条：优先从 RunState.chain_cards，否则用默认链条
	var player_cards: Array[CardRuntime] = []
	if run and not run.chain_cards.is_empty():
		for c in run.chain_cards:
			if c != null:
				player_cards.append(CardRuntime.new(c))
	if player_cards.is_empty():
		# fallback：默认起手 5 张
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

	# 2. 创建敌人：从 GameState.next_battle_enemy_id 读取
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

	# 初始化 UI
	player_hp_bar.max_value = _player_max_hp
	player_hp_bar.value = player.hp
	player_hp_label.text = "%d / %d" % [player.hp, _player_max_hp]
	timeline_scroll_view.setup(player.combatant_id, player.chain, true)

	var enemy_view := ENEMY_VIEW_SCENE.instantiate() as EnemyView
	enemy_container.add_child(enemy_view)
	enemy_view.setup(enemy)
	enemy_view.clicked.connect(_on_enemy_clicked)

	# 启动战斗
	battle_controller.start_battle(player, [enemy])

	# 战斗启动后，把 Timeline 注入底部时间轴 / 敌方面板，开启 60fps 平滑刷新
	if battle_controller.ctx and battle_controller.ctx.timeline:
		timeline_scroll_view.bind_timeline(battle_controller.ctx.timeline)
		enemy_view.bind_timeline(battle_controller.ctx.timeline)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo()):
		# 模拟战斗中按 ESC：返回构筑界面而非主菜单
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
				print("Toggle Gantt chart") # 甘特图待实现

func _on_hp_changed(id: StringName, _old_hp: int, new_hp: int) -> void:
	if id == &"player":
		player_hp_bar.value = new_hp
		player_hp_label.text = "%d / %d" % [new_hp, _player_max_hp]
		# 模拟战斗：不回写 RunState，避免污染存档
		if GameState.is_simulation:
			return
		# 回写到 RunState（即时同步，保证存档准确）
		if GameState.current_run:
			GameState.current_run.hp = new_hp

func _on_battle_ended(winner: int) -> void:
	await get_tree().create_timer(1.0).timeout

	# 正式战斗胜利：先去奖励界面（三选一卡牌），由 RewardScene 负责推进 node_index + 存档
	# 模拟战斗 / 失败 / 无 Run：走原有的 resolve_post_battle 路径（保持兼容）
	if not GameState.is_simulation \
			and winner == BattleContext.Winner.PLAYER \
			and GameState.current_run != null:
		get_tree().change_scene_to_file("res://scenes/reward/reward_scene.tscn")
		return

	var next_scene := resolve_post_battle(winner)
	get_tree().change_scene_to_file(next_scene)

## 战斗结束后的状态推进策略（提取为静态方法以便测试）。
## 副作用：修改 GameState（node_index / is_simulation / end_run）+ 持久化存档。
## 返回：下一个应跳转的场景路径。
##
## 不变量：
##   - 模拟战斗：is_simulation 复位、不修改 node_index、不存档、不 end_run，回构筑
##   - 正式胜利：node_index += 1、存档、回地图
##              （注：此契约由 RewardScene._finalize 在运行时实际完成；
##                静态函数本身保留原有副作用以兼容已有单元测试 test_simulation_flow）
##   - 正式失败：end_run(false)、回主菜单
static func resolve_post_battle(winner: int) -> String:
	# 模拟战斗：无论胜负，都回构筑界面，不推进进度、不存档、不结束 Run
	if GameState.is_simulation:
		GameState.is_simulation = false
		return "res://scenes/build/build_scene.tscn"
	# 正式战斗：胜利 → 推进节点 + 存档 → 地图
	if winner == BattleContext.Winner.PLAYER and GameState.current_run != null:
		GameState.current_run.node_index += 1
		var save := SaveSystem.new()
		save.save_run(GameState.current_run)
		return "res://scenes/map/map_scene.tscn"
	# 失败或无 Run → 结束 Run → 主菜单
	if GameState.current_run:
		GameState.end_run(false)
	return "res://scenes/main_menu.tscn"

func _on_start_battle_pressed() -> void:
	# 玩家确认开始战斗：启动模拟、隐藏开始/构筑按钮、启用速度和投降按钮
	battle_controller.set_paused(false)
	start_battle_btn.hide()
	build_btn.hide()
	speed_1x_btn.disabled = false
	speed_2x_btn.disabled = false
	speed_4x_btn.disabled = false
	surrender_btn.disabled = false

func _on_build_pressed() -> void:
	# 进入构筑界面调整链条；构筑确认/返回后会回到本场景，
	# 由 _init_battle 重新读取 RunState.chain_cards 实现刷新。
	GameState.build_return_scene = "res://scenes/battle/battle_scene.tscn"
	get_tree().change_scene_to_file("res://scenes/build/build_scene.tscn")

func _on_enemy_clicked(id: StringName) -> void:
	print("Enemy clicked, show Gantt chart for: ", id)
