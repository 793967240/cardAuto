# src/core/effects/effect_attack.gd
# 攻击效果 - 对目标造成伤害
class_name EffectAttack extends CardEffect

@export var damage: int = 5
@export var hits: int = 1

func fire(ctx: BattleContext, source: Combatant) -> void:
	for i in hits:
		var target := ctx.choose_target(source)
		if target and target.is_alive():
			var dealt := target.take_damage(damage, source.tags)
			ctx.stats.damage_dealt += dealt
			ctx.stats.cards_fired += 1
