# src/data_models/slot_data.gd
# 底座数据资源
class_name SlotData extends Resource

enum SlotType { BASE, EXTENDED }

@export var id: StringName
@export var display_name_key: String
@export var slot_count: int = 6          # 槽位数（基础底座 6，扩展底座 1-3）
@export var slot_type: SlotType = SlotType.BASE
@export var description_key: String

## 扩展底座：整个底座共享一个词条
## 基础底座：每个槽位独立词条（在 RunState 中维护）
@export var shared_trait_slots: int = 0  # 0 = 每槽独立；1 = 整体共享

## 序列化（用于存档）
func serialize() -> Dictionary:
	return {
		"id": id,
		"slot_count": slot_count,
		"slot_type": slot_type,
	}
