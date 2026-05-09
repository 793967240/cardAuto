# src/core/trait_instance.gd
# 词条运行时实例 - 持有 TraitData 引用与当前等级
# 阶段 2 §2.1
#
# 设计动机：
#   - 词条强化（lv1 → lv2）通过替换 data 引用实现（指向 data.upgrade）
#   - TraitInstance 是 RefCounted，在 RunState / Chain 中按值传递
#   - 不直接持有 lv 数字，而是通过 data.is_upgraded() 判断
class_name TraitInstance extends RefCounted

var data: TraitData

func _init(trait_data: TraitData) -> void:
	data = trait_data

## 当前 effect（升级后会切到 data.upgrade.effect）
func get_effect() -> TraitEffect:
	return data.effect if data else null

## 升级到 +版本（篝火"强化词条"调用）
## @return true=升级成功，false=已是最高级或未配置 upgrade
func upgrade() -> bool:
	if data == null or data.upgrade == null:
		return false
	data = data.upgrade
	return true

## 是否已升级
func is_upgraded() -> bool:
	return data != null and data.is_upgraded()

## 当前等级（1 或 2）
func get_level() -> int:
	return 2 if is_upgraded() else 1
