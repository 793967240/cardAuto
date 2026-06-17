class_name RunState extends RefCounted

var character_id: StringName = &"sword"
var act: int = 1
var node_index: int = 0
var current_node_id: String = ""
var hp: int = 80
var max_hp: int = 80
var gold: int = 0
var deck: Array[CardData] = []

var bases: Array[SlotData] = []
var base_cards: Dictionary = {}  # base_id (StringName) → CardData (nullable)
var base_gems: Dictionary = {}   # base_id (StringName) → Array[GemInstance]

var gems: Array = []  # Array[GemInstance] — 玩家宝石背包

var chain_cards: Array[CardData] = []

var relics: Array = []  # Array[RelicData]
var map_nodes: Array = []

func serialize() -> Dictionary:
	return {
		"version": 4,
		"character": str(character_id),
		"act": act,
		"node_index": node_index,
		"current_node_id": current_node_id,
		"hp": hp,
		"max_hp": max_hp,
		"gold": gold,
		"deck": deck.map(func(c): return str(c.id) if c else ""),
		"chain": chain_cards.map(func(c): return str(c.id) if c else ""),
		"bases": bases.map(func(s): return str(s.id) if s else ""),
		"base_cards": _serialize_base_cards(),
		"base_gems": _serialize_base_gems(),
		"gems": gems.map(func(g): return _serialize_gem_id(g)),
		"map_nodes": map_nodes,
		"relics": relics.map(func(r): return str(r.id) if r else ""),
	}

func _serialize_base_cards() -> Dictionary:
	var out: Dictionary = {}
	for k in base_cards:
		var c: CardData = base_cards[k]
		out[str(k)] = str(c.id) if c else ""
	return out

func _serialize_base_gems() -> Dictionary:
	var out: Dictionary = {}
	for k in base_gems:
		var arr: Array = base_gems[k]
		out[str(k)] = arr.map(func(g): return _serialize_gem_id(g))
	return out

static func _serialize_gem_id(gem) -> String:
	if gem is GemInstance:
		var gi := gem as GemInstance
		return str(gi.data.id) if gi.data else ""
	if gem is GemData:
		return str((gem as GemData).id)
	return ""

static func from_dict(data: Dictionary) -> RunState:
	var state := RunState.new()
	state.character_id = StringName(data.get("character", "sword"))
	state.act = data.get("act", 1)
	state.node_index = data.get("node_index", 0)
	state.current_node_id = data.get("current_node_id", "")
	state.hp = data.get("hp", 80)
	state.max_hp = data.get("max_hp", 80)
	state.gold = data.get("gold", 0)
	state.map_nodes = data.get("map_nodes", [])
	return state
