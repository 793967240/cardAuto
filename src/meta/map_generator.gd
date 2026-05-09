# src/meta/map_generator.gd
# 地图生成器 - 阶段 1 MVP：线性 10 节点 + Boss
# 阶段 3 会重写为非线性图（参考杀戮尖塔算法）
class_name MapGenerator extends RefCounted

enum NodeType { BATTLE, CAMPFIRE, BOSS }

## 阶段 1 MVP 敌人池（按节点强度递增使用）
const ENEMY_POOL: Array[String] = [
	"slime",
	"fire_imp",
	"shadow_blade",
	"stone_guard",
	"iron_golem",
]
const BOSS_ID: String = "iron_golem"  # 阶段 1 用铁傀儡当 boss

## 生成 11 节点的线性路径（10 普通节点 + 1 Boss）
## 规则：
##   - 节点 1-2 必须是 BATTLE
##   - 节点 5 可能是 CAMPFIRE
##   - 节点 10 必须是 CAMPFIRE
##   - 节点 11 是 BOSS
##   - 其余 70% BATTLE / 30% CAMPFIRE
static func generate(seed: int = 0) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed if seed != 0 else int(Time.get_unix_time_from_system())

	var nodes: Array = []

	for i in range(10):
		var node_index := i + 1
		var node_type: NodeType
		var enemy_id: String = ""

		match node_index:
			1, 2:
				node_type = NodeType.BATTLE
			5:
				node_type = NodeType.CAMPFIRE if rng.randf() < 0.5 else NodeType.BATTLE
			10:
				node_type = NodeType.CAMPFIRE
			_:
				node_type = NodeType.BATTLE if rng.randf() < 0.7 else NodeType.CAMPFIRE

		if node_type == NodeType.BATTLE:
			# 难度递增：前期用前面 enemies，后期用后面
			var pool_idx := mini(int(float(i) / 10.0 * ENEMY_POOL.size()), ENEMY_POOL.size() - 1)
			# 加一点随机：±1
			pool_idx = clampi(pool_idx + rng.randi_range(-1, 1), 0, ENEMY_POOL.size() - 1)
			enemy_id = ENEMY_POOL[pool_idx]

		nodes.append({
			"node_index": node_index,
			"node_type": int(node_type),
			"enemy_id": enemy_id,
		})

	# 第 11 个节点 = Boss
	nodes.append({
		"node_index": 11,
		"node_type": int(NodeType.BOSS),
		"enemy_id": BOSS_ID,
	})

	return nodes

## 把存档里的 dict 转回类型注解友好的 Dictionary
static func node_type_name(node_type: int) -> String:
	match node_type:
		int(NodeType.BATTLE): return "battle"
		int(NodeType.CAMPFIRE): return "campfire"
		int(NodeType.BOSS): return "boss"
	return "unknown"
