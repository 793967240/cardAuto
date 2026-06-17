class_name BattleController extends Node

var ctx: BattleContext
var _is_running: bool = false

func _ready() -> void:
	EventBus.speed_changed.connect(_on_speed_changed)

func _process(delta: float) -> void:
	if not _is_running or ctx == null or ctx.is_finished():
		return
	ctx.timeline.update(delta)

func start_battle(player: Combatant, enemies: Array[Combatant], seed: int = 0) -> void:
	ctx = BattleContext.new(player, enemies, seed)

	ctx.timeline.tick_advanced.connect(_on_tick_advanced)
	ctx.battle_log_event.connect(_on_battle_log_event)
	ctx.battle_ended.connect(_on_battle_ended)

	_connect_combatant_signals(player)
	for e in enemies:
		_connect_combatant_signals(e)

	var tuning := Tuning.get_default()
	ctx.timeline.setup(tuning.tick_duration_sec)
	ctx.timeline.set_speed_multiplier(tuning.speed_options[tuning.default_speed_index])

	_is_running = false
	EventBus.battle_started.emit()

func toggle_pause() -> void:
	_is_running = not _is_running

func set_paused(paused: bool) -> void:
	_is_running = not paused

func is_running() -> bool:
	return _is_running

func surrender() -> void:
	if ctx and not ctx.is_finished():
		_is_running = false
		EventBus.battle_ended.emit(BattleContext.Winner.ENEMY)

func _on_tick_advanced(tick: int) -> void:
	if ctx == null or ctx.is_finished():
		return
	ctx.advance_one_tick()
	EventBus.battle_tick_advanced.emit(tick)

func _on_battle_ended(winner: int) -> void:
	_is_running = false
	EventBus.battle_ended.emit(winner)

func _on_battle_log_event(event: Dictionary) -> void:
	EventBus.battle_log_event.emit(event)

func _on_speed_changed(mult: float) -> void:
	if ctx:
		ctx.timeline.set_speed_multiplier(mult)

func _connect_combatant_signals(combatant: Combatant) -> void:
	combatant.hp_changed.connect(
		func(old_hp: int, new_hp: int):
			EventBus.combatant_hp_changed.emit(combatant.combatant_id, old_hp, new_hp)
	)
	combatant.died.connect(
		func():
			EventBus.combatant_died.emit(combatant.combatant_id)
	)
	combatant.status_applied.connect(
		func(status: StatusInstance):
			EventBus.status_applied.emit(combatant.combatant_id, status.status_id)
	)
	combatant.status_expired.connect(
		func(status_id: StringName):
			EventBus.status_expired.emit(combatant.combatant_id, status_id)
	)
	combatant.chain.card_fired.connect(
		func(card: CardRuntime, index: int):
			EventBus.card_fired.emit(combatant.combatant_id, card.data.id, index)
	)
	combatant.chain.cycle_completed.connect(
		func():
			EventBus.chain_cycle_completed.emit(combatant.combatant_id)
	)
