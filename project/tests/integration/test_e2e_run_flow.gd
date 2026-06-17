# tests/integration/test_e2e_run_flow.gd
# 端到端 Run 流程冒烟测试
# 验证：资源加载 → Run 初始化 → 战斗 → 存档 整条链路畅通
# 阶段 1/2 验收覆盖：分叉地图完整路线通玩 + 中途存档 + 加载校验
extends GutTest

const E2E_LOG_DIR := "user://e2e_logs/"

# ─── 测试 1: .tres 资源能正常加载 ─────────────────────────────

func test_load_card_resources() -> void:
	var dir := DirAccess.open("res://data/cards/sword")
	assert_not_null(dir, "card dir should open")
	if dir == null:
		return

	var card_paths: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			card_paths.append("res://data/cards/sword/%s" % fname)
		fname = dir.get_next()
	dir.list_dir_end()
	card_paths.sort()

	var rarity_counts := {0: 0, 1: 0, 2: 0}
	for path in card_paths:
		var card := load(path) as CardData
		assert_not_null(card, "load(%s) should succeed" % path)
		if card:
			assert_true(card.id != &"", "%s 有 id" % path)
			assert_gte(card.cost, 1, "%s cost >= 1" % path)
			assert_not_null(card.effect, "%s effect 非空" % path)
			if not card.is_upgraded():
				assert_not_null(card.upgrade, "%s upgrade 非空" % path)
				assert_true(card.upgrade.is_upgraded(), "%s upgrade should be plus card" % path)
			rarity_counts[int(card.rarity)] = int(rarity_counts.get(int(card.rarity), 0)) + 1

	assert_eq(card_paths.size(), 100, "剑修卡牌总数应为 100")
	assert_eq(rarity_counts[0], 50, "普通卡应为 50")
	assert_eq(rarity_counts[1], 30, "罕见卡应为 30")
	assert_eq(rarity_counts[2], 20, "稀有卡应为 20")

	var upgrade_dir := DirAccess.open("res://data/cards/sword/upgrades")
	assert_not_null(upgrade_dir, "upgrade dir should open")
	if upgrade_dir:
		var upgrade_count := 0
		upgrade_dir.list_dir_begin()
		var up_name := upgrade_dir.get_next()
		while up_name != "":
			if not upgrade_dir.current_is_dir() and up_name.ends_with(".tres"):
				var up_card := load("res://data/cards/sword/upgrades/%s" % up_name) as CardData
				assert_not_null(up_card, "load upgrade %s" % up_name)
				if up_card:
					assert_true(up_card.is_upgraded(), "%s should be upgraded card" % up_name)
					assert_not_null(up_card.effect, "%s effect 非空" % up_name)
				upgrade_count += 1
			up_name = upgrade_dir.get_next()
		upgrade_dir.list_dir_end()
		assert_eq(upgrade_count, 98, "额外升级卡资源应为 98")

func test_load_enemy_resources() -> void:
	var enemies := ["slime", "stone_guard", "fire_imp", "iron_golem", "shadow_blade"]
	for id in enemies:
		var path := "res://data/enemies/%s.tres" % id
		var enemy := load(path) as EnemyData
		assert_not_null(enemy, "load(%s)" % path)
		if enemy:
			assert_eq(enemy.id, StringName(id), "id 字段正确")
			assert_gt(enemy.max_hp, 0, "max_hp > 0")
			assert_gt(enemy.deck.size(), 0, "%s 有卡牌仓库" % id)

func test_load_tuning_resource() -> void:
	var t := load("res://data/tuning/default.tres") as Tuning
	assert_not_null(t, "tuning/default.tres 加载成功")
	if t:
		assert_almost_eq(t.tick_duration_sec, 0.5, 0.001, "tick_duration_sec = 0.5")
		assert_eq(t.base_count, 8, "base_count = 8")

# ─── 测试 2: MapGenerator 行为正确 ─────────────────────────────

func test_map_generator_produces_valid_path() -> void:
	var nodes := MapGenerator.generate(12345)
	assert_gt(nodes.size(), MapGenerator.FLOOR_COUNT, "地图包含多条路线节点")
	assert_eq(MapGenerator.get_available_nodes(nodes, 0, "").size(), MapGenerator.PATH_COUNT,
		"起点有多条路线选择")

	var boss_nodes := nodes.filter(func(n): return n["node_type"] == int(MapGenerator.NodeType.BOSS))
	assert_eq(boss_nodes.size(), 1, "只有 1 个 Boss")
	assert_eq(boss_nodes[0]["id"], "boss", "Boss id 固定")

	# 所有 BATTLE 节点都有 enemy_id
	for n in nodes:
		if n["node_type"] == int(MapGenerator.NodeType.BATTLE) or n["node_type"] == int(MapGenerator.NodeType.BOSS):
			assert_true(n.get("enemy_id", "") != "", "战斗节点应有 enemy_id")

func test_map_generator_seed_determinism() -> void:
	var n1 := MapGenerator.generate(999)
	var n2 := MapGenerator.generate(999)
	assert_eq(n1.size(), n2.size(), "相同 seed 节点数相同")
	for i in range(n1.size()):
		assert_eq(n1[i]["node_type"], n2[i]["node_type"], "节点 %d 类型相同" % i)

# ─── 测试 3: 端到端战斗 ───────────────────────────────────────

func test_full_battle_using_resources() -> void:
	# 用真实 .tres 加载玩家卡牌仓库 + 敌人，跑一场战斗
	var player := Combatant.new(&"player", "Sword", 80)
	player.tags = [&"sword"]

	var deck_paths := [
		"res://data/cards/sword/zhan.tres",
		"res://data/cards/sword/xu_shi.tres",
		"res://data/cards/sword/qiang_pi.tres",
		"res://data/cards/sword/yu_jian_dun.tres",
		"res://data/cards/sword/hui_xiang_jian.tres",
	]
	var slots: Array[CardRuntime] = []
	for p in deck_paths:
		var c := load(p) as CardData
		assert_not_null(c, "load card %s" % p)
		if c:
			slots.append(CardRuntime.new(c))
	player.chain.set_slots(slots)

	var slime_data := load("res://data/enemies/slime.tres") as EnemyData
	assert_not_null(slime_data, "load slime")
	var enemy := slime_data.create_combatant()

	var sim := BattleSimulator.new()
	var result := sim.simulate(player, [enemy], 42, 600)

	assert_eq(result.winner, BattleContext.Winner.PLAYER,
		"玩家应当击败 slime (winner=%d)" % result.winner)
	assert_gt(result.ticks_elapsed, 0, "战斗有进展")
	assert_gt(result.damage_dealt, 0, "造成了伤害")
	assert_gt(result.cards_fired, 0, "触发了卡牌")

	push_warning("[e2e] 起手卡牌仓库 vs slime: %d ticks, %d damage, hp_left=%d" % [
		result.ticks_elapsed, result.damage_dealt, result.player_hp_remaining
	])

# ─── 测试 4: 存档读写完整循环 ─────────────────────────────────

func test_save_load_cycle() -> void:
	var save := SaveSystem.new()

	# 清理可能存在的旧存档
	if save.has_active_run():
		save.delete_run()

	# 构造 RunState
	var run := RunState.new()
	run.character_id = &"sword"
	run.act = 1
	run.node_index = 3
	run.hp = 65
	run.max_hp = 80
	run.gold = 30
	run.map_nodes = MapGenerator.generate(99)

	var ok := save.save_run(run)
	assert_true(ok, "save_run 成功")
	assert_true(save.has_active_run(), "has_active_run() 为 true")

	# 加载
	var loaded := save.load_run()
	assert_not_null(loaded, "load_run 返回非空")
	if loaded:
		assert_eq(loaded.character_id, &"sword", "character 还原")
		assert_eq(loaded.node_index, 3, "node_index 还原")
		assert_eq(loaded.hp, 65, "hp 还原")
		assert_eq(loaded.gold, 30, "gold 还原")
		assert_gt(loaded.map_nodes.size(), MapGenerator.FLOOR_COUNT, "map_nodes 还原")

	# 清理
	save.delete_run()
	assert_false(save.has_active_run(), "delete_run 后 has_active_run 为 false")

# ─── 测试 5: 完整分叉路线通玩（阶段 1/2 验收） ────────────────

const _STARTER_DECK_PATHS := [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
]

func _build_starter_player() -> Combatant:
	var p := Combatant.new(&"player", "Sword", 80)
	p.tags = [&"sword"]
	var slots: Array[CardRuntime] = []
	for path in _STARTER_DECK_PATHS:
		var c := load(path) as CardData
		assert_not_null(c, "load %s" % path)
		if c:
			slots.append(CardRuntime.new(c))
	p.chain.set_slots(slots)
	return p

func _spawn_enemy_for_node(node: Dictionary) -> Combatant:
	var enemy_id: String = node.get("enemy_id", "")
	if enemy_id == "":
		return null
	var data := load("res://data/enemies/%s.tres" % enemy_id) as EnemyData
	assert_not_null(data, "load enemy %s" % enemy_id)
	return data.create_combatant() if data else null

func _ensure_log_dir() -> void:
	DirAccess.make_dir_recursive_absolute(E2E_LOG_DIR)

func test_full_11_node_run_completes() -> void:
	# 跑多个 seed，验证「至少有一个 seed 能完整通关 11 节点」
	# 这是阶段 1 工程验收：证明 demo 可通玩，不是平衡保证。
	# 平衡分布由 baseline_runner 单独跑批验证。
	_ensure_log_dir()
	var seeds := [20260506, 1, 42, 123, 777, 999, 7777, 31415]
	var winning_seed := -1
	var winning_log: Array[String] = []

	for s in seeds:
		var run_log := _try_run_seed(s)
		if run_log.size() > 0 and run_log[run_log.size() - 1].find("boss_defeated=YES") != -1:
			winning_seed = s
			winning_log = run_log
			break

	# 写日志
	var log_path := E2E_LOG_DIR + "run_flow_v1.log"
	var f := FileAccess.open(log_path, FileAccess.WRITE)
	assert_not_null(f, "open log file")
	if f:
		f.store_line("# E2E run flow v1")
		f.store_line("# generated_at=%s" % Time.get_datetime_string_from_system())
		f.store_line("# seeds_tried=%s" % str(seeds))
		f.store_line("# winning_seed=%d" % winning_seed)
		f.store_line("")
		for line in winning_log:
			f.store_line(line)

	push_warning("[e2e] log saved to %s (winning_seed=%d)" % [log_path, winning_seed])

	assert_gt(winning_seed, -1,
		"至少 1 个 seed 应能完整通关（试了 %d 个）" % seeds.size())

func _try_run_seed(seed_val: int) -> Array[String]:
	# 尝试用给定 seed 跑完一遍，返回日志行；不通关也返回日志（含 boss_defeated=NO）
	var log_lines: Array[String] = []
	log_lines.append("seed=%d" % seed_val)
	var nodes := MapGenerator.generate(seed_val)
	if nodes.size() <= MapGenerator.FLOOR_COUNT:
		log_lines.append("INVALID node count: %d" % nodes.size())
		return log_lines
	if MapGenerator.get_node_by_id(nodes, "boss").is_empty():
		log_lines.append("INVALID missing boss")
		return log_lines

	var player := _build_starter_player()
	var sim := BattleSimulator.new()
	var battles_won := 0
	var battles_total := 0
	var boss_defeated := false
	var completed_floor := 0
	var current_node_id := ""

	while completed_floor < MapGenerator.FLOOR_COUNT:
		var choices := MapGenerator.get_available_nodes(nodes, completed_floor, current_node_id)
		if choices.is_empty():
			log_lines.append("floor %02d ERROR: no choices" % (completed_floor + 1))
			break
		var node: Dictionary = _pick_e2e_route_choice(choices)
		var node_idx: int = node["node_index"]
		var nt: int = node["node_type"]
		var nt_name := MapGenerator.node_type_name(nt)
		current_node_id = str(node["id"])

		if nt == int(MapGenerator.NodeType.CAMPFIRE):
			var heal := int(player.max_hp * 0.3)
			var hp_before := player.hp
			player.hp = mini(player.max_hp, player.hp + heal)
			log_lines.append("node %-7s floor=%02d  %-9s heal=%d hp=%d->%d" % [
				current_node_id, node_idx, nt_name, heal, hp_before, player.hp])
			completed_floor = node_idx
			continue

		if nt == int(MapGenerator.NodeType.CHEST):
			log_lines.append("node %-7s floor=%02d  %-9s reward=YES" % [
				current_node_id, node_idx, nt_name])
			completed_floor = node_idx
			continue

		var enemy := _spawn_enemy_for_node(node)
		if not enemy:
			log_lines.append("node %s  ERROR: no enemy" % current_node_id)
			break

		battles_total += 1
		var hp_before := player.hp
		_reset_player_between_battles(player)
		var result := sim.simulate(player, [enemy], seed_val + node_idx, 600)
		var won := result.winner == BattleContext.Winner.PLAYER
		if won:
			battles_won += 1
		log_lines.append("node %-7s floor=%02d  %-9s enemy=%-12s ticks=%3d dmg=%3d taken=%3d hp=%d->%d won=%s" % [
			current_node_id, node_idx, nt_name, enemy.combatant_id, result.ticks_elapsed,
			result.damage_dealt, result.damage_taken,
			hp_before, player.hp, "YES" if won else "NO"])

		if not won:
			break
		completed_floor = node_idx
		if nt == int(MapGenerator.NodeType.BOSS):
			boss_defeated = true

	log_lines.append("---")
	log_lines.append("battles_total=%d  battles_won=%d  boss_defeated=%s  hp_final=%d" % [
		battles_total, battles_won, "YES" if boss_defeated else "NO", player.hp])
	return log_lines

func _pick_e2e_route_choice(choices: Array[Dictionary]) -> Dictionary:
	for node in choices:
		if node["node_type"] == int(MapGenerator.NodeType.CAMPFIRE):
			return node
	return choices[0]

func _reset_player_between_battles(c: Combatant) -> void:
	# 战斗间复位：清状态 + 链条 progress（HP 保留以模拟真实跨战斗）
	c.statuses.clear()
	var existing := c.chain.slots
	for slot in existing:
		if slot != null:
			slot.is_consumed = false
	c.chain.set_slots(existing)
	c.chain.current_card_progress = 0

# ─── 测试 6: 中途存档 + 加载状态一致 ──────────────────────────

func test_save_load_midrun_preserves_state() -> void:
	var save := SaveSystem.new()
	if save.has_active_run():
		save.delete_run()

	# 模拟玩到节点 6（节点 5 后存档）
	var run := RunState.new()
	run.character_id = &"sword"
	run.act = 1
	run.node_index = 3
	run.current_node_id = "f3_l1"
	run.hp = 52
	run.max_hp = 80
	run.gold = 45
	run.map_nodes = MapGenerator.generate(99)

	# 模拟链条状态（5 张起手卡）
	var chain_cards: Array[CardData] = []
	for path in _STARTER_DECK_PATHS:
		chain_cards.append(load(path) as CardData)
	run.chain_cards = chain_cards

	var ok := save.save_run(run)
	assert_true(ok, "save 成功")

	# 销毁 run state 引用
	run = null

	# 加载并校验
	var loaded := save.load_run()
	assert_not_null(loaded, "load 成功")
	if loaded:
		assert_eq(loaded.character_id, &"sword", "character_id 一致")
		assert_eq(loaded.node_index, 3, "node_index 一致 (=3)")
		assert_eq(loaded.current_node_id, "f3_l1", "current_node_id 一致")
		assert_eq(loaded.hp, 52, "hp 一致")
		assert_eq(loaded.max_hp, 80, "max_hp 一致")
		assert_eq(loaded.gold, 45, "gold 一致")
		assert_gt(loaded.map_nodes.size(), MapGenerator.FLOOR_COUNT, "map_nodes 有分叉节点")
		assert_eq(MapGenerator.get_node_by_id(loaded.map_nodes, "boss")["node_type"],
			int(MapGenerator.NodeType.BOSS), "加载后 BOSS 仍存在")

	save.delete_run()
