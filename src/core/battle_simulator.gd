# src/core/battle_simulator.gd
# Headless 战斗模拟器 - 无 UI，用于 CI 平衡回归
class_name BattleSimulator extends RefCounted

## 单次模拟最大 tick 数（防无限循环）
const DEFAULT_MAX_TICKS := 600  # 300 秒 @ 1x 速度

## 模拟结果
class BattleResult extends RefCounted:
	var winner: BattleContext.Winner = BattleContext.Winner.TIMEOUT
	var ticks_elapsed: int = 0
	var player_hp_remaining: int = 0
	var damage_dealt: int = 0
	var damage_taken: int = 0
	var cards_fired: int = 0
	var interrupts_landed: int = 0

	func is_player_win() -> bool:
		return winner == BattleContext.Winner.PLAYER

## 执行单次战斗模拟
func simulate(
	player: Combatant,
	enemies: Array[Combatant],
	battle_seed: int = 0,
	max_ticks: int = DEFAULT_MAX_TICKS
) -> BattleResult:
	var ctx := BattleContext.new(player, enemies, battle_seed)
	var tick := 0

	while not ctx.is_finished() and tick < max_ticks:
		ctx.advance_one_tick()
		tick += 1

	var result := BattleResult.new()
	result.winner = ctx.get_winner()
	result.ticks_elapsed = tick
	result.player_hp_remaining = player.hp
	result.damage_dealt = ctx.stats.damage_dealt
	result.damage_taken = ctx.stats.damage_taken
	result.cards_fired = ctx.stats.cards_fired
	result.interrupts_landed = ctx.stats.interrupts_landed
	return result

## 批量模拟（用于平衡回归）
func simulate_batch(
	player_factory: Callable,   # () -> Combatant
	enemies_factory: Callable,  # () -> Array[Combatant]
	count: int,
	base_seed: int = 0,
	max_ticks: int = DEFAULT_MAX_TICKS
) -> Array[BattleResult]:
	var results: Array[BattleResult] = []
	for i in count:
		var p := player_factory.call()
		var e := enemies_factory.call()
		results.append(simulate(p, e, base_seed + i, max_ticks))
	return results

## 计算批量结果的胜率
static func calc_win_rate(results: Array[BattleResult]) -> float:
	if results.is_empty():
		return 0.0
	var wins := results.filter(func(r): return r.is_player_win()).size()
	return float(wins) / float(results.size())
