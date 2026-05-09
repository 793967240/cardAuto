# src/core/effects/effect_echo.gd
# 回响效果 - 复制链条中前一张牌的效果并立即触发
class_name EffectEcho extends CardEffect

@export var copy_count: int = 1  # 复制触发次数

func fire(ctx: BattleContext, source: Combatant) -> void:
	# 复制链条中前一张牌的效果。
	# 注：Chain.on_tick 中 card.fire() 在 _advance_index 之前调用，
	#     所以触发时 chain.current_index 仍指向回响这张牌本身。
	#     前一张牌的下标 = current_index - 1。
	var chain := source.chain
	var echo_index := chain.current_index - 1
	if echo_index < 0 or echo_index >= chain.slots.size():
		# 没有前一张牌（回响在链首），无效
		ctx.stats.cards_fired += 1
		return

	var prev_card := chain.slots[echo_index]
	if prev_card == null or prev_card.is_consumed:
		ctx.stats.cards_fired += 1
		return
	# 防止回响嵌套（前一张牌也是回响）→ 死循环
	if prev_card.data.effect is EffectEcho:
		ctx.stats.cards_fired += 1
		return

	# 触发前一张牌的效果（仅触发效果，不走 fire() 的 consume 逻辑）
	for i in copy_count:
		if prev_card.data.effect:
			prev_card.data.effect.fire(ctx, source)

	ctx.stats.cards_fired += 1
