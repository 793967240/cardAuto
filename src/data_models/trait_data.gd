# src/data_models/trait_data.gd
# 词条数据资源 - 每条词条一个 .tres 文件
# 阶段 2 §2.1 词条系统
class_name TraitData extends Resource

## 作用域：决定词条挂载方式
##   INDEPENDENT — 挂在基础底座单个槽位上，仅修饰该槽位的卡
##   SHARED      — 挂在扩展底座整组上，修饰整组所有卡
enum Scope { INDEPENDENT, SHARED }

## 触发时机：Chain 在不同阶段调用对应 hook
##   PASSIVE      — 静态修饰（如 cost-1、伤害+X），由 Chain.apply_traits 计算时持续生效
##   ON_PLAY      — 卡牌打出（fire）时触发
##   ON_RECOVERY  — 进入修整时触发
##   ON_CHAIN_END — 整轮链条结束（即一轮修整结束、重启链条）时触发
enum Trigger { PASSIVE, ON_PLAY, ON_RECOVERY, ON_CHAIN_END }

@export var id: StringName
@export var display_name_key: String   # i18n key: trait.{id}.name
@export var desc_key: String           # i18n key: trait.{id}.desc

@export var scope: Scope = Scope.INDEPENDENT
@export var trigger: Trigger = Trigger.PASSIVE

## 词条标签 — 用于互斥、协同识别
## 例：[&"cost_mod"]、[&"damage_mod"]、[&"echo"]
@export var tags: Array[StringName] = []

## 互斥标签 — 装备本词条后，同槽位不允许再挂载任何带这些 tag 的词条
## 例：mutex_tags=[&"cost_mod"] 表示同槽位只能挂一个 cost 类词条
@export var mutex_tags: Array[StringName] = []

## 词条效果实例（策略模式，类似 CardEffect）
@export var effect: TraitEffect

## 升级版（lv1 → lv2，篝火可强化 1 次）
@export var upgrade: TraitData = null

@export_multiline var description_template: String  # 编辑器预览，不走 i18n
@export var icon: Texture2D

## 派生 i18n key
func get_name_key() -> String:
	return "trait.%s.name" % id

func get_desc_key() -> String:
	return "trait.%s.desc" % id

## 是否为升级版（命名约定 _plus 结尾）
func is_upgraded() -> bool:
	return str(id).ends_with("_plus")

## 互斥校验：本词条与 other 是否互斥
##   规则：tag 与 other.mutex_tags 有交集，或 mutex_tags 与 other.tags 有交集
func is_mutex_with(other: TraitData) -> bool:
	if other == null:
		return false
	for tag in tags:
		if tag in other.mutex_tags:
			return true
	for mt in mutex_tags:
		if mt in other.tags:
			return true
	return false
