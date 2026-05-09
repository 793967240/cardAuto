# src/core/effects/traits/trait_effect_echo.gd
# 词条效果：回响型 — 卡牌打出时，额外触发"前一张卡"的效果一次
# 阶段 2 §2.1 / GDD §3.5 回响型
# 典型词条：回响阵（echo_chamber）— 该扩展底座所有卡触发时，重打前一张卡
#
# 实现注意：通过 source.chain.layout + current_index - 1 找前一张卡
# 直接调 prev_card.fire(ctx, source) 复用现有效果
class_name TraitEffectEcho extends TraitEffect

@export var max_triggers_per_chain: int = 999  # 单条链最多触发多少次（防无限循环）

# 单局触发计数（运行时状态，每场战斗外部重置）
var _triggered_count: int = 0

func on_card_played(card: CardRuntime, ctx: BattleContext, source: Combatant) -> void:
	if source == null or source.chain == null:
		return
	if _triggered_count >= max_triggers_per_chain:
		return
	# 找前一张卡（current_index 在 fire 后还未 advance，所以前一张是 current_index - 1）
	var prev_idx := source.chain.current_index - 1
	if prev_idx < 0:
		return  # 链条第一张，没有前一张
	var prev_slot: ChainSlot = source.chain.layout[prev_idx] if prev_idx < source.chain.layout.size() else null
	if prev_slot == null or prev_slot.card == null:
		return
	# 不要复制 echo 自身触发的卡 = card 本身（防自递归），其实 echo 是词条不是卡，不会自触发
	# 但要防止前一张卡是同一张（环形链条不应出现，但保险起见）
	if prev_slot.card == card:
		return
	_triggered_count += 1
	# 重新触发前一张卡的效果（不消耗、不计入 stats.cards_fired，这是回响）
	if prev_slot.card.data and prev_slot.card.data.effect:
		prev_slot.card.data.effect.fire(ctx, source)

## 战斗开始时重置（由 BattleController 在 start_battle 中调用，或外部代码调用）
func reset() -> void:
	_triggered_count = 0
