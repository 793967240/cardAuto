# src/core/effects/effect_attack.gd
# 攻击效果 - 对目标造成伤害
class_name EffectAttack extends CardEffect

@export var damage: int = 5
@export var hits: int = 1

func fire(ctx: BattleContext, source: Combatant) -> void:
	# 词条修饰：source.chain.modify_damage 聚合 PASSIVE 词条对伤害的修饰
	var current_card: CardRuntime = source.chain.get_current_card() if source.chain else null
	var dmg := damage
	if source.chain:
		dmg = source.chain.modify_damage(current_card, dmg)
	for i in hits:
		var target := ctx.choose_target(source)
		if target and target.is_alive():
			var dealt := target.take_damage(dmg, source.tags)
			ctx.stats.damage_dealt += dealt
			ctx.stats.cards_fired += 1
