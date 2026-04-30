# src/core/battle_context.gd
# 战斗上下文 - 持有所有战斗状态，不依赖 UI
class_name BattleContext extends RefCounted

var player: Combatant
var enemies: Array[Combatant] = []
var timeline: Timeline
var seed: int = 0
var rng: RandomNumberGenerator

## 战斗统计数据
var stats: BattleStats

## 修整时长基础值（可被遗物/词条覆盖）
var base_recovery_ticks: int = 2
## 修整时长硬下限
const RECOVERY_MIN_TICKS := 1

signal battle_started()
signal battle_ended(winner: int)  # 0=player, 1=enemy, -1=timeout

enum Winner { PLAYER = 0, ENEMY = 1, TIMEOUT = -1 }

var _winner: Winner = Winner.TIMEOUT
var _is_finished: bool = false

func _init(p: Combatant, enemy_list: Array[Combatant], battle_seed: int = 0) -> void:
	player = p
	enemies = enemy_list
	seed = battle_seed
	timeline = Timeline.new()
	stats = BattleStats.new()
	rng = RandomNumberGenerator.new()
	rng.seed = battle_seed

	# 监听死亡事件
	player.died.connect(_on_player_died)
	for e in enemies:
		e.died.connect(_on_enemy_died.bind(e))

## 推进一个 tick（Headless 模拟使用）
func advance_one_tick() -> void:
	if _is_finished:
		return

	# 推进玩家链条
	player.chain.on_tick(self)
	player.tick_statuses(self)

	# 推进所有敌人链条
	for e in enemies:
		if e.is_alive():
			e.chain.on_tick(self)
			e.tick_statuses(self)

	stats.total_ticks += 1
	_check_victory()

## 计算战斗者的修整时长
func compute_recovery_duration(combatant: Combatant) -> int:
	var duration := base_recovery_ticks
	# TODO: 阶段 2 加入词条/遗物修正
	return max(RECOVERY_MIN_TICKS, duration)

## 默认目标选择（攻击类效果使用）
func choose_target(source: Combatant) -> Combatant:
	if source == player:
		# 玩家攻击：选第一个存活的敌人
		for e in enemies:
			if e.is_alive():
				return e
		return null
	else:
		# 敌人攻击：目标为玩家
		return player

## 获取所有存活敌人
func get_alive_enemies() -> Array[Combatant]:
	return enemies.filter(func(e): return e.is_alive())

## 战斗是否结束
func is_finished() -> bool:
	return _is_finished

## 获取胜利方
func get_winner() -> Winner:
	return _winner

func _on_player_died() -> void:
	if _is_finished:
		return
	_winner = Winner.ENEMY
	_is_finished = true
	battle_ended.emit(_winner)

func _on_enemy_died(_e: Combatant) -> void:
	_check_victory()

func _check_victory() -> void:
	if _is_finished:
		return
	if not player.is_alive():
		_on_player_died()
		return
	if get_alive_enemies().is_empty():
		_winner = Winner.PLAYER
		_is_finished = true
		battle_ended.emit(_winner)


# ─── 战斗统计数据 ──────────────────────────────────────────────
class BattleStats extends RefCounted:
	var total_ticks: int = 0
	var damage_dealt: int = 0
	var damage_taken: int = 0
	var cards_fired: int = 0
	var interrupts_landed: int = 0
	var healing_done: int = 0
