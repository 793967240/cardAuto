# src/data_models/card_data.gd
# 卡牌数据资源 - 每张卡牌一个 .tres 文件
class_name CardData extends Resource

enum CardType { ATTACK, DEFENSE, BUFF, CONTROL, SUMMON, SPECIAL }
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

@export var id: StringName
@export var display_name_key: String   # i18n key: card.{id}.name
@export var desc_key: String           # i18n key: card.{id}.desc
@export var cost: int = 1              # 基础 cost（tick）
@export var card_type: CardType = CardType.ATTACK
@export var tags: Array[StringName] = []   # [&"fire", &"sword", &"charge"]
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var description_template: String  # 编辑器预览用（不走 i18n）
@export var effect_script: GDScript     # 指向具体效果脚本
@export var icon: Texture2D
@export var consumable: bool = false    # 一次性卡（消耗标签）
@export var upgrade: CardData = null    # +版本（GDD §9）

## 派生 i18n key
func get_name_key() -> String:
	return "card.%s.name" % id

func get_desc_key() -> String:
	return "card.%s.desc" % id

## 是否为升级版
func is_upgraded() -> bool:
	return str(id).ends_with("_plus")
