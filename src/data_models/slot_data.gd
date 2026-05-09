# src/data_models/slot_data.gd
# 底座数据资源
# 阶段 2 §2.2 / TC-2-DATA-005
class_name SlotData extends Resource

enum SlotType { BASE, EXTENDED }

@export var id: StringName
@export var display_name_key: String
@export var slot_count: int = 6          # 槽位数（基础底座 6，扩展底座 1-3）
@export var slot_type: SlotType = SlotType.BASE
@export var description_key: String

## 扩展底座：整个底座共享一个词条（在 RunState 中维护）
## 基础底座：每个槽位独立词条（在 RunState 中维护）
@export var shared_trait_slots: int = 0  # 0 = 每槽独立；1 = 整体共享

## 珠子连接接口（GDD §3.3 底座连接系统）
##   基础底座：has_bead_out = true,  has_bead_in = false（链头）
##   扩展底座：has_bead_in = true,   has_bead_out = true（中段）
@export var has_bead_in: bool = false   # 入口珠（左侧）
@export var has_bead_out: bool = true   # 出口珠（右侧）

## 是否为扩展底座（便捷查询，等价于 slot_type == EXTENDED）
func is_extension() -> bool:
	return slot_type == SlotType.EXTENDED

## 是否为基础底座（链头，位置固定）
func is_base() -> bool:
	return slot_type == SlotType.BASE

## 序列化（用于存档）
func serialize() -> Dictionary:
	return {
		"id": id,
		"slot_count": slot_count,
		"slot_type": slot_type,
	}
