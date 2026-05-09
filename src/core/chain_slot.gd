# src/core/chain_slot.gd
# Chain 上单个槽位的运行时元数据
# 阶段 2 §2.1 + §2.2
#
# Chain.set_layout 接收 Array[ChainSlot] 替代旧的 Array[CardRuntime]
# 每个 ChainSlot 同时携带：
#   - card: 该槽位的卡（可空）
#   - independent_trait: 基础底座该槽位的独立词条（可空）
#   - shared_trait: 该卡所属扩展底座的共享词条（可空，所有共属同一扩展底座的 ChainSlot 引用同一个 TraitInstance）
#   - base_id: 该槽位归属底座的 id（用于"未连接底座不参战"过滤）
class_name ChainSlot extends RefCounted

var card: CardRuntime
var independent_trait: TraitInstance = null  # 仅基础底座槽位有
var shared_trait: TraitInstance = null       # 仅扩展底座槽位有（同底座共享同一引用）
var base_id: StringName = &""                # 归属底座 id

func _init(c: CardRuntime, base: StringName = &"") -> void:
	card = c
	base_id = base

## 该槽位生效的所有词条（独立 + 共享，去 null）
func active_traits() -> Array:
	var out: Array = []
	if independent_trait != null:
		out.append(independent_trait)
	if shared_trait != null:
		out.append(shared_trait)
	return out
