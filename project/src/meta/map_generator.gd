# src/meta/map_generator.gd
# 地图生成器 - 分叉路线图（参考杀戮尖塔：逐层选择、路径汇合到 Boss）
class_name MapGenerator extends RefCounted

enum NodeType { BATTLE, CAMPFIRE, BOSS, CHEST }

const FLOOR_COUNT: int = 10
const LANES: int = 5
const PATH_COUNT: int = 4
const CHEST_FLOOR: int = 4

## Act 1 敌人池（按层数递增使用）
const ENEMY_POOL: Array[String] = [
	"slime",
	"fire_imp",
	"shadow_blade",
	"stone_guard",
	"iron_golem",
]
const BOSS_ID: String = "tai_xu_judge"

## 生成可选择路线图。
## 节点字段：
##   - id: 唯一节点 id
##   - node_index: 所在层数（兼容旧流程，完成一层后 +1）
##   - floor/lane: UI 布局坐标
##   - next_ids: 下一层可达节点 id
static func generate(seed: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system())

	var node_map: Dictionary = {}
	var edges_by_floor: Dictionary = {}
	var starts := _pick_start_lanes(rng)

	for start_lane in starts:
		var current_lane: int = start_lane
		_ensure_node(node_map, 1, current_lane, rng)
		for floor in range(1, FLOOR_COUNT - 1):
			var next_lane := _pick_next_lane(current_lane, floor, edges_by_floor, rng)
			var from_node := _ensure_node(node_map, floor, current_lane, rng)
			var to_node := _ensure_node(node_map, floor + 1, next_lane, rng)
			_add_edge(from_node, str(to_node["id"]))
			_record_edge(edges_by_floor, floor, current_lane, next_lane)
			current_lane = next_lane

		var penultimate := _ensure_node(node_map, FLOOR_COUNT - 1, current_lane, rng)
		_add_edge(penultimate, "boss")

	node_map["boss"] = {
		"id": "boss",
		"node_index": FLOOR_COUNT,
		"floor": FLOOR_COUNT,
		"lane": int(LANES / 2),
		"node_type": int(NodeType.BOSS),
		"enemy_id": BOSS_ID,
		"next_ids": [],
	}

	var nodes: Array = node_map.values()
	nodes.sort_custom(func(a, b):
		var fa: int = int(a.get("floor", 0))
		var fb: int = int(b.get("floor", 0))
		if fa == fb:
			return int(a.get("lane", 0)) < int(b.get("lane", 0))
		return fa < fb
	)
	return nodes

static func _pick_node_type(floor: int, rng: RandomNumberGenerator) -> NodeType:
	if floor == FLOOR_COUNT:
		return NodeType.BOSS
	if floor == 1:
		return NodeType.BATTLE
	if floor == CHEST_FLOOR:
		return NodeType.CHEST
	if floor == FLOOR_COUNT - 1:
		return NodeType.CAMPFIRE
	return NodeType.CAMPFIRE if rng.randf() < 0.25 else NodeType.BATTLE

static func _pick_enemy_id(floor: int, lane: int, rng: RandomNumberGenerator) -> String:
	if floor == FLOOR_COUNT:
		return BOSS_ID
	var progress := float(floor - 1) / float(FLOOR_COUNT - 2)
	var pool_idx := mini(int(progress * ENEMY_POOL.size()), ENEMY_POOL.size() - 1)
	pool_idx = clampi(pool_idx + rng.randi_range(-1, 1) + (lane % 2), 0, ENEMY_POOL.size() - 1)
	return ENEMY_POOL[pool_idx]

static func _node_id(floor: int, lane: int) -> String:
	if floor == FLOOR_COUNT:
		return "boss"
	return "f%d_l%d" % [floor, lane]

static func _pick_start_lanes(rng: RandomNumberGenerator) -> Array[int]:
	var lanes: Array[int] = []
	while lanes.size() < PATH_COUNT:
		var lane := rng.randi_range(0, LANES - 1)
		if lane not in lanes:
			lanes.append(lane)
	lanes.sort()
	return lanes

static func _ensure_node(node_map: Dictionary, floor: int, lane: int, rng: RandomNumberGenerator) -> Dictionary:
	var id := _node_id(floor, lane)
	if node_map.has(id):
		return node_map[id]
	var node_type := _pick_node_type(floor, rng)
	var node := {
		"id": id,
		"node_index": floor,
		"floor": floor,
		"lane": lane,
		"node_type": int(node_type),
		"enemy_id": _pick_enemy_id(floor, lane, rng) if node_type == NodeType.BATTLE else "",
		"next_ids": [],
	}
	node_map[id] = node
	return node

static func _pick_next_lane(current_lane: int, floor: int, edges_by_floor: Dictionary, rng: RandomNumberGenerator) -> int:
	var candidates: Array[int] = []
	var boss_lane := int(LANES / 2)
	for lane in [current_lane - 1, current_lane, current_lane + 1]:
		if lane < 0 or lane >= LANES:
			continue
		if floor == FLOOR_COUNT - 2 and abs(lane - boss_lane) > 1:
			continue
		if not _would_cross_existing_edge(floor, current_lane, lane, edges_by_floor):
			candidates.append(lane)
	if candidates.is_empty():
		candidates.append(current_lane)
	return candidates[rng.randi_range(0, candidates.size() - 1)]

static func _would_cross_existing_edge(floor: int, from_lane: int, to_lane: int, edges_by_floor: Dictionary) -> bool:
	var edges: Array = edges_by_floor.get(floor, [])
	for edge in edges:
		var other_from: int = edge["from"]
		var other_to: int = edge["to"]
		if other_from == from_lane:
			continue
		if from_lane < other_from and to_lane > other_to:
			return true
		if from_lane > other_from and to_lane < other_to:
			return true
	return false

static func _record_edge(edges_by_floor: Dictionary, floor: int, from_lane: int, to_lane: int) -> void:
	if not edges_by_floor.has(floor):
		edges_by_floor[floor] = []
	edges_by_floor[floor].append({"from": from_lane, "to": to_lane})

static func _add_edge(node: Dictionary, to_id: String) -> void:
	var next_ids: Array = node["next_ids"]
	if to_id not in next_ids:
		next_ids.append(to_id)

static func get_node_by_id(nodes: Array, id: String) -> Dictionary:
	for node in nodes:
		if str(node.get("id", "")) == id:
			return node
	return {}

static func get_available_nodes(nodes: Array, completed_floor: int, current_node_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var next_floor := completed_floor + 1
	if current_node_id == "":
		for node in nodes:
			if int(node.get("floor", node.get("node_index", 0))) == next_floor:
				out.append(node)
		return out

	var current := get_node_by_id(nodes, current_node_id)
	var next_ids: Array = current.get("next_ids", [])
	for node in nodes:
		if str(node.get("id", "")) in next_ids:
			out.append(node)
	return out

static func legacy_linear(seed: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system())
	var nodes: Array = []
	for i in range(10):
		var node_index := i + 1
		var node_type := NodeType.BATTLE if node_index != 10 else NodeType.CAMPFIRE
		nodes.append({
			"id": "legacy_%d" % node_index,
			"node_index": node_index,
			"floor": node_index,
			"lane": 0,
			"node_type": int(node_type),
			"enemy_id": _pick_enemy_id(node_index, 0, rng) if node_type == NodeType.BATTLE else "",
			"next_ids": ["legacy_%d" % (node_index + 1)],
		})
	nodes.append({
		"id": "legacy_11",
		"node_index": 11,
		"floor": 11,
		"lane": 0,
		"node_type": int(NodeType.BOSS),
		"enemy_id": BOSS_ID,
		"next_ids": [],
	})
	return nodes

## 把存档里的 dict 转回类型注解友好的 Dictionary
static func node_type_name(node_type: int) -> String:
	match node_type:
		int(NodeType.BATTLE): return "battle"
		int(NodeType.CAMPFIRE): return "campfire"
		int(NodeType.BOSS): return "boss"
		int(NodeType.CHEST): return "chest"
	return "unknown"
