class_name EffectBossTaiXu extends CardEffect

enum Move {
	TRIBULATION,
	LAW_SEAL,
	NULL_GUARD,
	FINAL_DECREE,
}

@export var move: Move = Move.TRIBULATION

func fire(ctx: BattleContext, source: Combatant) -> void:
	if ctx == null or source == null:
		return
	_ensure_phase_two(source)
	match move:
		Move.TRIBULATION:
			_fire_tribulation(ctx, source)
		Move.LAW_SEAL:
			_fire_law_seal(ctx, source)
		Move.NULL_GUARD:
			_fire_null_guard(ctx, source)
		Move.FINAL_DECREE:
			_fire_final_decree(ctx, source)
	ctx.stats.cards_fired += 1

func _ensure_phase_two(source: Combatant) -> bool:
	if source.hp > int(ceil(float(source.max_hp) * 0.5)):
		return false
	if source.battle_flags.get("tai_xu_phase_two", false):
		return true
	source.battle_flags["tai_xu_phase_two"] = true
	source.apply_status(StatusInstance.make_shield(24))
	source.apply_status(StatusInstance.new(StatusInstance.ID_HASTE, 1, 8))
	return true

func _fire_tribulation(ctx: BattleContext, source: Combatant) -> void:
	var target := ctx.choose_target(source)
	if target == null:
		return
	var damage := 14 if not _is_phase_two(source) else 20
	var dealt := target.take_damage(damage, source.tags)
	ctx.record_damage(source, target, dealt, "enemy.tai_xu_tribulation.name")
	target.apply_status(StatusInstance.make_burn(2 if not _is_phase_two(source) else 3, 4))

func _fire_law_seal(ctx: BattleContext, source: Combatant) -> void:
	var target := ctx.choose_target(source)
	if target == null:
		return
	target.apply_status(StatusInstance.make_vulnerable(4 if not _is_phase_two(source) else 6))
	target.apply_status(StatusInstance.make_weakness(2 if not _is_phase_two(source) else 3))

func _fire_null_guard(_ctx: BattleContext, source: Combatant) -> void:
	source.apply_status(StatusInstance.make_shield(18 if not _is_phase_two(source) else 32))
	source.apply_status(StatusInstance.new(StatusInstance.ID_INTERRUPT_RESISTANCE, 1, 4))

func _fire_final_decree(ctx: BattleContext, source: Combatant) -> void:
	var target := ctx.choose_target(source)
	if target == null:
		return
	var damage := 28 if not _is_phase_two(source) else 42
	if target.has_status(StatusInstance.ID_VULNERABLE) or target.has_status(StatusInstance.ID_WEAKNESS):
		damage += 10
	if not target.has_status(StatusInstance.ID_INTERRUPT_IMMUNE):
		target.chain.reset_current_card_progress()
		target.apply_status(StatusInstance.new(StatusInstance.ID_INTERRUPT_IMMUNE, 1, 4))
	var dealt := target.take_damage(damage, source.tags)
	ctx.record_damage(source, target, dealt, "enemy.tai_xu_final_decree.name")

func _is_phase_two(source: Combatant) -> bool:
	return bool(source.battle_flags.get("tai_xu_phase_two", false))
