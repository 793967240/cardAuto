# src/data_models/enemy_data.gd
# 敌人数据资源
class_name EnemyData extends Resource

enum EnemyTier { MINION, NORMAL, ELITE, BOSS }

@export var id: StringName
@export var display_name_key: String   # enemy.{id}.name
@export var max_hp: int = 40
@export var tier: EnemyTier = EnemyTier.NORMAL
@export var tags: Array[StringName] = []
@export var deck: Array[CardData] = []     # 敌人链条卡牌列表（固定顺序）
@export var portrait: Texture2D
@export var act: int = 1                   # 所属 Act（1/2/3）

## 构建敌人 Combatant
func create_combatant() -> Combatant:
	var c := Combatant.new(id, display_name_key, max_hp)
	c.tags = tags.duplicate()
	# 构建链条
	var chain_slots: Array[CardRuntime] = []
	for card in deck:
		chain_slots.append(CardRuntime.new(card))
	c.chain.set_slots(chain_slots)
	return c
