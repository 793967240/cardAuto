# tests/integration/test_simulation_flow.gd
# 锁定"构筑界面 → 模拟战斗 → 不污染存档"的关键不变量。
#
# 覆盖：
#   - 模拟战斗胜利：node_index 不变、hp 不变、不存档、不结束 Run、跳回构筑
#   - 模拟战斗失败：node_index 不变、hp 不变、不结束 Run、跳回构筑
#   - 模拟战斗结束：is_simulation 标志复位
#   - 正式战斗胜利：node_index += 1、存档、跳地图（对照组）
#   - 正式战斗失败：end_run(false)、跳主菜单（对照组）
#   - build_scene._pick_simulation_enemy_id 选下一个未通关战斗节点
extends GutTest

const BUILD_SCENE = "res://scenes/build/build_scene.tscn"
const MAP_SCENE = "res://scenes/map/map_scene.tscn"
const MENU_SCENE = "res://scenes/main_menu.tscn"

var _save: SaveSystem

func before_each() -> void:
	# 每个测试前清理 GameState 与存档，确保隔离
	_save = SaveSystem.new()
	if _save.has_active_run():
		_save.delete_run()
	GameState.is_simulation = false
	GameState.current_run = null
	GameState.next_battle_enemy_id = ""

func after_each() -> void:
	# 清理副作用，避免污染后续测试
	if _save.has_active_run():
		_save.delete_run()
	GameState.is_simulation = false
	GameState.current_run = null
	GameState.next_battle_enemy_id = ""

# ─── 模拟战斗：核心不变量 ────────────────────────────────────────

func _make_run_at_node(idx: int, hp: int = 60) -> RunState:
	var run := RunState.new()
	run.character_id = &"sword"
	run.act = 1
	run.node_index = idx
	run.hp = hp
	run.max_hp = 80
	run.gold = 25
	run.map_nodes = MapGenerator.generate(20260506)
	GameState.current_run = run
	return run

func test_simulation_win_does_not_advance_node() -> void:
	var run := _make_run_at_node(3)
	GameState.is_simulation = true

	var next_scene := BattleScene.resolve_post_battle(BattleContext.Winner.PLAYER)

	assert_eq(next_scene, BUILD_SCENE, "模拟胜利应跳回构筑界面")
	assert_eq(run.node_index, 3, "node_index 必须不变")
	assert_eq(run.hp, 60, "hp 必须不变")
	assert_not_null(GameState.current_run, "Run 必须仍然存在")
	assert_false(GameState.is_simulation, "is_simulation 应被复位")
	assert_false(_save.has_active_run(), "不应写入存档文件")

func test_simulation_loss_does_not_end_run() -> void:
	var run := _make_run_at_node(5)
	GameState.is_simulation = true

	var next_scene := BattleScene.resolve_post_battle(BattleContext.Winner.ENEMY)

	assert_eq(next_scene, BUILD_SCENE, "模拟失败应跳回构筑界面（而非主菜单）")
	assert_eq(run.node_index, 5, "node_index 必须不变")
	assert_not_null(GameState.current_run, "Run 必须仍然存在（不能 end_run）")
	assert_false(GameState.is_simulation, "is_simulation 应被复位")
	assert_false(_save.has_active_run(), "不应写入存档文件")

func test_simulation_with_no_run_still_returns_to_build() -> void:
	# 极端情况：没有 RunState 也不应炸
	GameState.is_simulation = true
	GameState.current_run = null

	var next_scene := BattleScene.resolve_post_battle(BattleContext.Winner.PLAYER)
	assert_eq(next_scene, BUILD_SCENE, "无 Run 的模拟战斗仍应回构筑")
	assert_false(GameState.is_simulation, "is_simulation 应被复位")

# ─── 正式战斗：对照组 ───────────────────────────────────────────

func test_real_battle_win_advances_node_and_saves() -> void:
	var run := _make_run_at_node(2)
	GameState.is_simulation = false

	var next_scene := BattleScene.resolve_post_battle(BattleContext.Winner.PLAYER)

	assert_eq(next_scene, MAP_SCENE, "正式胜利应跳地图")
	assert_eq(run.node_index, 3, "node_index 应推进 +1")
	assert_true(_save.has_active_run(), "应写入存档")

	# 验证存档内容也是新的 node_index
	var loaded := _save.load_run()
	assert_not_null(loaded, "存档应可加载")
	if loaded:
		assert_eq(loaded.node_index, 3, "存档里的 node_index = 3")

func test_real_battle_loss_ends_run() -> void:
	var _run := _make_run_at_node(4)
	GameState.is_simulation = false

	var next_scene := BattleScene.resolve_post_battle(BattleContext.Winner.ENEMY)

	assert_eq(next_scene, MENU_SCENE, "正式失败应回主菜单")
	assert_null(GameState.current_run, "失败应 end_run，current_run 置空")

# ─── 模拟战斗敌人选择 ───────────────────────────────────────────
# 用 BuildScene.pick_simulation_enemy_id 的静态版本测试（不实例化场景）

func test_pick_simulation_enemy_targets_next_unfinished_battle_node() -> void:
	# 玩家停在节点 0（还没通关任何节点），节点 1 必为 BATTLE，应该被选中
	var run := _make_run_at_node(0)

	var enemy_id := BuildScene.pick_simulation_enemy_id(run)
	# MapGenerator 第 1 个节点必是 BATTLE 且 enemy_id 来自 ENEMY_POOL
	var expected_id: String = run.map_nodes[1]["enemy_id"]
	assert_eq(enemy_id, expected_id,
		"应选到下一个未通关战斗节点的 enemy_id，期望 %s" % expected_id)
	assert_true(enemy_id != "", "enemy_id 非空")

func test_pick_simulation_enemy_skips_campfire() -> void:
	# 通过插入一个 CAMPFIRE 节点后再 BATTLE 节点，验证选择逻辑跳过没 enemy_id 的节点
	var run := _make_run_at_node(0)
	# 把第 1 个节点（默认是 BATTLE）替换为 CAMPFIRE（无 enemy_id）
	run.map_nodes[1] = {
		"node_index": 2,
		"node_type": int(MapGenerator.NodeType.CAMPFIRE),
		"enemy_id": "",
	}
	# 第 2 个节点（默认 BATTLE）保留
	var enemy_id := BuildScene.pick_simulation_enemy_id(run)
	var expected_id: String = run.map_nodes[2]["enemy_id"]
	assert_eq(enemy_id, expected_id, "应跳过 CAMPFIRE 节点，选到下一个有 enemy_id 的节点")

func test_pick_simulation_enemy_falls_back_to_slime_when_no_battle_left() -> void:
	# 玩家已通关到末尾 → 没有未通关节点
	var run := _make_run_at_node(0)
	run.node_index = run.map_nodes.size()

	var enemy_id := BuildScene.pick_simulation_enemy_id(run)
	assert_eq(enemy_id, "slime", "无可选战斗节点时 fallback 到 slime")

func test_pick_simulation_enemy_no_run_returns_slime() -> void:
	# 直接传 null，不依赖 GameState
	var enemy_id := BuildScene.pick_simulation_enemy_id(null)
	assert_eq(enemy_id, "slime", "传入 null 时 fallback 到 slime")
