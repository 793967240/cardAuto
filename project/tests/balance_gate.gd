# tests/balance_gate.gd
# CI 平衡警告 gate（警告级，不阻塞）
# 用法：
#   godot --headless --path . --script tests/balance_gate.gd
#
# 行为：
#   - 读 reports/baseline/baseline_v1.json
#   - 跑小批量（CI 友好）每 matchup 200 局
#   - 对比 win_rate / avg_ticks 偏移，超阈值打 ⚠ warning
#   - 把 markdown 表格 append 到 $GITHUB_STEP_SUMMARY（如有）
#   - 退出码 0（warning 不阻塞）；baseline 缺失 → 退出 1
extends SceneTree

const BASELINE_PATH := "reports/baseline/baseline_v1.json"
const CI_BATTLE_COUNT := 200
const MAX_TICKS := 600
const WIN_RATE_DELTA := 0.10
const AVG_TICKS_DELTA_RATIO := 0.30

const STARTER_DECK_PATHS := [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
]

func _init() -> void:
	print("====== Balance Gate ======")

	var baseline_abs := ProjectSettings.globalize_path("res://" + BASELINE_PATH)
	if not FileAccess.file_exists(baseline_abs):
		push_error("balance_gate: baseline missing at %s" % baseline_abs)
		print("FAIL: baseline missing. Run baseline_runner first.")
		quit(1)
		return

	var f := FileAccess.open(baseline_abs, FileAccess.READ)
	if f == null:
		push_error("balance_gate: cannot open baseline")
		quit(1)
		return
	var baseline_text := f.get_as_text()
	var baseline = JSON.parse_string(baseline_text)
	if typeof(baseline) != TYPE_DICTIONARY:
		push_error("balance_gate: baseline is not a JSON object")
		quit(1)
		return

	var baseline_matchups: Array = baseline.get("matchups", [])
	if baseline_matchups.is_empty():
		push_error("balance_gate: baseline has no matchups")
		quit(1)
		return

	var rows: Array = []
	var warn_count := 0
	for entry in baseline_matchups:
		var enemy_id: String = ""
		if entry.has("enemies") and entry["enemies"] is Array and entry["enemies"].size() > 0:
			enemy_id = String(entry["enemies"][0])
		else:
			continue

		var current := _run_matchup(enemy_id, CI_BATTLE_COUNT)
		var bw: float = float(entry.get("win_rate", 0.0))
		var bt: float = float(entry.get("avg_ticks", 0.0))
		var cw: float = current["win_rate"]
		var ct: float = current["avg_ticks"]

		var status_tags: Array[String] = []
		if abs(cw - bw) > WIN_RATE_DELTA:
			status_tags.append("⚠ WIN_RATE")
			warn_count += 1
		if bt > 0 and abs(ct - bt) / bt > AVG_TICKS_DELTA_RATIO:
			status_tags.append("⚠ TICKS")
			warn_count += 1
		var status := "✅ OK" if status_tags.is_empty() else " ".join(status_tags)

		var row := {
			"matchup": entry.get("name", "starter_vs_" + enemy_id),
			"baseline_win_rate": bw,
			"current_win_rate": cw,
			"win_delta": cw - bw,
			"baseline_avg_ticks": bt,
			"current_avg_ticks": ct,
			"ticks_delta_pct": ((ct - bt) / bt * 100.0) if bt > 0 else 0.0,
			"status": status,
		}
		rows.append(row)
		print("[%-30s] win=%.3f→%.3f (%+.3f) ticks=%.1f→%.1f (%+.1f%%) %s" % [
			row["matchup"], bw, cw, row["win_delta"],
			bt, ct, row["ticks_delta_pct"], status])

	# 写 markdown 摘要（如果在 CI 环境）
	var md := _build_markdown(rows, warn_count)
	_maybe_append_to_step_summary(md)

	print("")
	print("warnings: %d" % warn_count)
	print("RESULT: %s (warnings are non-blocking)" % ("WARN" if warn_count > 0 else "OK"))
	quit(0)

# ─── matchup ───────────────────────────────────────────────

func _build_player() -> Combatant:
	var p := Combatant.new(&"player", "Sword", 80)
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

func _run_matchup(enemy_id: String, count: int) -> Dictionary:
	var sim := BattleSimulator.new()
	var results := sim.simulate_batch(
		_build_player,
		func() -> Array[Combatant]: return [_build_enemy(enemy_id)] as Array[Combatant],
		count, 1, MAX_TICKS,
	)
	var wins := 0
	var sum_ticks := 0
	for r in results:
		if r.is_player_win():
			wins += 1
		sum_ticks += r.ticks_elapsed
	var n: float = max(1.0, float(results.size()))
	return {
		"win_rate": float(wins) / n,
		"avg_ticks": float(sum_ticks) / n,
	}

# ─── markdown summary ──────────────────────────────────────

func _build_markdown(rows: Array, warn_count: int) -> String:
	var lines: Array[String] = []
	lines.append("## Balance Gate")
	lines.append("")
	if warn_count == 0:
		lines.append("✅ No drift detected (%d matchups)." % rows.size())
	else:
		lines.append("⚠ **%d warning(s)** detected (non-blocking)." % warn_count)
	lines.append("")
	lines.append("| matchup | baseline_win_rate | current_win_rate | delta | baseline_avg_ticks | current_avg_ticks | ticks_delta_pct | status |")
	lines.append("|---|---|---|---|---|---|---|---|")
	for r in rows:
		lines.append("| %s | %.3f | %.3f | %+.3f | %.1f | %.1f | %+.1f%% | %s |" % [
			r["matchup"], r["baseline_win_rate"], r["current_win_rate"],
			r["win_delta"], r["baseline_avg_ticks"], r["current_avg_ticks"],
			r["ticks_delta_pct"], r["status"]])
	return "\n".join(lines) + "\n"

func _maybe_append_to_step_summary(md: String) -> void:
	var summary_path: String = OS.get_environment("GITHUB_STEP_SUMMARY")
	if summary_path == "":
		print("(GITHUB_STEP_SUMMARY not set; skip markdown append)")
		return
	var f: FileAccess = FileAccess.open(summary_path, FileAccess.READ_WRITE)
	if f == null:
		# 文件可能不存在，新建
		f = FileAccess.open(summary_path, FileAccess.WRITE)
	if f == null:
		push_warning("cannot open GITHUB_STEP_SUMMARY: %s" % summary_path)
		return
	f.seek_end()
	f.store_string(md)
	print("appended markdown summary to %s" % summary_path)
