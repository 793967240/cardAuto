# tests/baseline_runner.gd
# 阶段 1 平衡基线跑批工具
# 用法：
#   godot --headless --path . --script tests/baseline_runner.gd
#   godot --headless --path . --script tests/baseline_runner.gd -- --count 1000 --out reports/baseline/baseline_v1.json
#
# 输出：JSON 文件，含 5 个 matchup（起手卡组 vs 5 个敌人）的统计信息
extends SceneTree

const DEFAULT_COUNT := 1000
const DEFAULT_OUT := "reports/baseline/baseline_v1.json"
const MAX_TICKS := 600

const STARTER_DECK_PATHS := [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
]

const ENEMY_IDS := ["slime", "fire_imp", "shadow_blade", "stone_guard", "iron_golem"]

func _init() -> void:
	var args := _parse_args()
	var count: int = args.get("count", DEFAULT_COUNT)
	var out_rel: String = args.get("out", DEFAULT_OUT)

	# 解析输出路径：如果是相对路径，相对项目根
	var out_abs: String
	if out_rel.is_absolute_path():
		out_abs = out_rel
	else:
		out_abs = ProjectSettings.globalize_path("res://" + out_rel)

	print("====== Baseline Runner ======")
	print("count per matchup : %d" % count)
	print("output            : %s" % out_abs)
	print("")

	var t_start := Time.get_ticks_msec()
	var matchups: Array = []
	for enemy_id in ENEMY_IDS:
		var stats := _run_matchup(enemy_id, count)
		matchups.append(stats)
		print("[%-12s] win=%.3f  avg_ticks=%6.1f  avg_dmg=%5.1f  avg_taken=%5.1f  hp_avg=%5.1f" % [
			enemy_id, stats["win_rate"], stats["avg_ticks"],
			stats["avg_damage_dealt"], stats["avg_damage_taken"],
			stats["hp_remaining"]["avg"]])

	var elapsed_sec := (Time.get_ticks_msec() - t_start) / 1000.0
	print("")
	print("Total elapsed: %.2fs" % elapsed_sec)

	var doc := {
		"version": "v1",
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"godot_version": Engine.get_version_info()["string"],
		"battle_count_per_matchup": count,
		"player_deck": STARTER_DECK_PATHS,
		"matchups": matchups,
	}

	if not _write_json(out_abs, doc):
		push_error("baseline_runner: failed to write %s" % out_abs)
		quit(1)
		return

	print("Written: %s" % out_abs)
	print("RESULT: OK")
	quit(0)

# ─── arg parsing ────────────────────────────────────────────

func _parse_args() -> Dictionary:
	var result := {"count": DEFAULT_COUNT, "out": DEFAULT_OUT}
	var argv := OS.get_cmdline_user_args()
	var i := 0
	while i < argv.size():
		var a: String = argv[i]
		match a:
			"--count":
				if i + 1 < argv.size():
					result["count"] = int(argv[i + 1])
					i += 1
			"--out":
				if i + 1 < argv.size():
					result["out"] = String(argv[i + 1])
					i += 1
		i += 1
	return result

# ─── matchup ───────────────────────────────────────────────

func _build_player() -> Combatant:
	var p := Combatant.new(&"player", "Sword", 80)
	p.tags = [&"sword"]
	var slots: Array[CardRuntime] = []
	for path in STARTER_DECK_PATHS:
		var card := load(path) as CardData
		if card == null:
			push_error("baseline_runner: cannot load %s" % path)
			return null
		slots.append(CardRuntime.new(card))
	p.chain.set_slots(slots)
	return p

func _build_enemy(enemy_id: String) -> Combatant:
	var data := load("res://data/enemies/%s.tres" % enemy_id) as EnemyData
	if data == null:
		push_error("baseline_runner: cannot load enemy %s" % enemy_id)
		return null
	return data.create_combatant()

func _run_matchup(enemy_id: String, count: int) -> Dictionary:
	var sim := BattleSimulator.new()
	var results := sim.simulate_batch(
		_build_player,
		func() -> Array[Combatant]: return [_build_enemy(enemy_id)] as Array[Combatant],
		count, 1, MAX_TICKS,
	)

	var wins := 0
	var sum_ticks := 0
	var sum_dmg := 0
	var sum_taken := 0
	var sum_cards := 0
	var hp_list: Array[int] = []
	for r in results:
		if r.is_player_win():
			wins += 1
		sum_ticks += r.ticks_elapsed
		sum_dmg += r.damage_dealt
		sum_taken += r.damage_taken
		sum_cards += r.cards_fired
		hp_list.append(r.player_hp_remaining)

	var n := float(results.size())
	hp_list.sort()
	var p50 := hp_list[int(hp_list.size() * 0.5)] if hp_list.size() > 0 else 0
	var p90 := hp_list[int(hp_list.size() * 0.9)] if hp_list.size() > 0 else 0
	var hp_avg := 0.0
	for h in hp_list:
		hp_avg += float(h)
	hp_avg = hp_avg / max(1.0, n)

	return {
		"name": "starter_vs_%s" % enemy_id,
		"player": "starter_sword",
		"enemies": [enemy_id],
		"win_rate": float(wins) / max(1.0, n),
		"avg_ticks": float(sum_ticks) / max(1.0, n),
		"avg_damage_dealt": float(sum_dmg) / max(1.0, n),
		"avg_damage_taken": float(sum_taken) / max(1.0, n),
		"avg_cards_fired": float(sum_cards) / max(1.0, n),
		"hp_remaining": {"avg": hp_avg, "p50": p50, "p90": p90},
	}

# ─── io ────────────────────────────────────────────────────

func _write_json(abs_path: String, data: Dictionary) -> bool:
	# 确保父目录存在
	var dir_path := abs_path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(dir_path)

	var f := FileAccess.open(abs_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "  "))
	return true
