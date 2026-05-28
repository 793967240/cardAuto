class_name BattleContext extends RefCounted

var player: Combatant
var enemies: Array[Combatant] = []
var timeline: Timeline
var seed: int = 0
var rng: RandomNumberGenerator

var stats: BattleStats

signal battle_started()
signal battle_ended(winner: int)

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

	player.died.connect(_on_player_died)
	for e in enemies:
		e.died.connect(_on_enemy_died.bind(e))

func advance_one_tick() -> void:
	if _is_finished:
		return

	player.chain.on_tick(self)
	player.tick_statuses(self)

	for e in enemies:
		if e.is_alive():
			e.chain.on_tick(self)
			e.tick_statuses(self)

	stats.total_ticks += 1
	_check_victory()

func choose_target(source: Combatant) -> Combatant:
	if source == player:
		for e in enemies:
			if e.is_alive():
				return e
		return null
	else:
		return player

func get_alive_enemies() -> Array[Combatant]:
	return enemies.filter(func(e): return e.is_alive())

func is_finished() -> bool:
	return _is_finished

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


class BattleStats extends RefCounted:
	var total_ticks: int = 0
	var damage_dealt: int = 0
	var damage_taken: int = 0
	var cards_fired: int = 0
	var interrupts_landed: int = 0
	var healing_done: int = 0
