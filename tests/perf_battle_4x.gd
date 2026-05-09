# tests/perf_battle_4x.gd
# 4x 加速性能基准（仅逻辑层）
# 用法：
#   godot --headless --path . --script tests/perf_battle_4x.gd
#
# 阈值：1000 tick wall clock < 1000 ms
#       即 ticks_per_sec >= 1000，远超 4x@60fps 所需的 240 tick/sec
extends SceneTree

const TICKS_TO_RUN := 1000
const MAX_WALL_MS := 1000
const MIN_TICKS_PER_SEC := 240.0
const OUT_REL := "reports/perf/battle_logic_v1.json"

const STARTER_DECK_PATHS := [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
]

func _init() -> void:
	print("====== Perf Battle 4x (logic only) ======")

	var player := _build_player()
	if player == null:
		quit(1)
		return
	var enemy := _build_enemy("stone_guard")
	if enemy == null:
		quit(1)
		return

	# 用一个不会结束的环境跑 1000 tick
	# stone_guard 40HP，可能中途结束 → 改用一个超高血量目标
	var dummy := Combatant.new(&"dummy", "Dummy", 999999)
	var enemy_list: Array[Combatant] = [dummy]
	var ctx := BattleContext.new(player, enemy_list, 1)

	var t0 := Time.get_ticks_usec()
	var ticks_done := 0
	for i in range(TICKS_TO_RUN):
		if ctx.is_finished():
			break
		ctx.advance_one_tick()
		ticks_done += 1
	var t1 := Time.get_ticks_usec()
	var wall_us := t1 - t0
	var wall_ms := wall_us / 1000.0
	var ticks_per_sec: float = float(ticks_done) / max(0.000001, wall_us / 1_000_000.0)

	print("[perf] %d ticks in %.2f ms" % [ticks_done, wall_ms])
	print("[perf] ticks_per_sec = %.0f (req >= %.0f)" % [ticks_per_sec, MIN_TICKS_PER_SEC])

	var doc := {
		"version": "v1",
		"generated_at": Time.get_datetime_string_from_system(true, true),
		"godot_version": Engine.get_version_info()["string"],
		"ticks": ticks_done,
		"wall_ms": int(wall_ms),
		"ticks_per_sec": ticks_per_sec,
		"min_required_ticks_per_sec": MIN_TICKS_PER_SEC,
		"max_allowed_wall_ms": MAX_WALL_MS,
	}
	var out_abs := ProjectSettings.globalize_path("res://" + OUT_REL)
	DirAccess.make_dir_recursive_absolute(out_abs.get_base_dir())
	var f := FileAccess.open(out_abs, FileAccess.WRITE)
	if f == null:
		push_error("perf: cannot write %s" % out_abs)
		quit(1)
		return
	f.store_string(JSON.stringify(doc, "  "))
	print("Written: %s" % out_abs)

	if wall_ms > MAX_WALL_MS:
		print("FAIL: wall time %.2f ms exceeds %d ms" % [wall_ms, MAX_WALL_MS])
		quit(1)
		return
	if ticks_per_sec < MIN_TICKS_PER_SEC:
		print("FAIL: ticks_per_sec %.0f below required %.0f" % [ticks_per_sec, MIN_TICKS_PER_SEC])
		quit(1)
		return

	print("RESULT: OK (4x safety margin = %.1fx)" % (ticks_per_sec / MIN_TICKS_PER_SEC))
	quit(0)

func _build_player() -> Combatant:
	var p := Combatant.new(&"player", "Sword", 9999)
	p.tags = [&"sword"]
	var slots: Array[CardRuntime] = []
	for path in STARTER_DECK_PATHS:
		var card := load(path) as CardData
		if card == null:
			push_error("cannot load %s" % path)
			return null
		slots.append(CardRuntime.new(card))
	p.chain.set_slots(slots)
	return p

func _build_enemy(enemy_id: String) -> Combatant:
	var data := load("res://data/enemies/%s.tres" % enemy_id) as EnemyData
	if data == null:
		push_error("cannot load enemy %s" % enemy_id)
		return null
	return data.create_combatant()
