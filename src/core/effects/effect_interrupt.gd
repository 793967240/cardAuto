# src/core/effects/effect_interrupt.gd
# 打断效果 - 清零目标当前卡进度 + 施加打断免疫
class_name EffectInterrupt extends CardEffect

@export var also_damage: int = 0         # 附加伤害（可选）
@export var immune_duration: int = 4     # 打断免疫持续 tick
@export var pierce_resistance: bool = false  # 是否穿透打断抗性

func fire(ctx: BattleContext, source: Combatant) -> void:
	var target := ctx.choose_target(source)
	if not target or not target.is_alive():
		return

	# 检查打断抗性（boss 专属）
	if not pierce_resistance and target.has_status(&"interrupt_resistance"):
		# 打断无效，但附加伤害照常
		pass
	else:
		# 检查打断免疫
		if not target.has_status(StatusInstance.ID_INTERRUPT_IMMUNE):
			target.chain.reset_current_card_progress()
			# 施加打断免疫
			var immune := StatusInstance.new(StatusInstance.ID_INTERRUPT_IMMUNE, 1, immune_duration)
			target.apply_status(immune)
			ctx.stats.interrupts_landed += 1

	# 附加伤害照常结算
	if also_damage > 0:
		var dealt := target.take_damage(also_damage, source.tags)
		ctx.stats.damage_dealt += dealt

	ctx.stats.cards_fired += 1
