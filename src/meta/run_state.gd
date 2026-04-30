# src/meta/run_state.gd
# 当前 Run 的运行时状态（内存中 + 存档）
class_name RunState extends RefCounted

var character_id: StringName = &"sword"
var act: int = 1
var node_index: int = 0
var hp: int = 80
var max_hp: int = 80
var gold: int = 0
var deck: Array[CardData] = []
var slots: Array[SlotData] = []
var relics: Array     # Array[RelicData]（阶段3加入）

## 序列化为存档 Dictionary
func serialize() -> Dictionary:
	return {
		"version": 2,
		"character": str(character_id),
		"act": act,
		"node_index": node_index,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck": deck.map(func(c): return str(c.id)),
		"slots": slots.map(func(s): return s.serialize()),
		"relics": [],  # TODO: 阶段 3
	}

## 从存档 Dictionary 反序列化
static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.character_id = StringName(data.get("character", "sword"))
	state.act = data.get("act", 1)
	state.node_index = data.get("node_index", 0)
	state.hp = data.get("hp", 80)
	state.max_hp = data.get("max_hp", 80)
	state.gold = data.get("gold", 0)
	# deck/slots/relics 需要由 SaveSystem 根据 ID 重建引用
	return state
