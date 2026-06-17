# tests/integration/test_map_branching.gd
# 类杀戮尖塔分叉地图：多起点、逐层可选、最终汇合 Boss。
extends GutTest

func test_map_generator_creates_branching_floor_graph() -> void:
	var nodes := MapGenerator.generate(20260528)

	assert_gte(MapGenerator.FLOOR_COUNT, 10, "Route should have at least 10 floors including boss")
	assert_gt(nodes.size(), MapGenerator.FLOOR_COUNT, "Path graph should contain multiple branch nodes")
	assert_eq(MapGenerator.get_available_nodes(nodes, 0, "").size(), MapGenerator.PATH_COUNT,
		"Run start should offer one choice per generated path")

	var boss_nodes := nodes.filter(func(n): return n["node_type"] == int(MapGenerator.NodeType.BOSS))
	assert_eq(boss_nodes.size(), 1, "Map should have exactly one boss")
	assert_eq(boss_nodes[0]["floor"], MapGenerator.FLOOR_COUNT, "Boss should be on final floor")

	for node in nodes:
		var floor: int = node["floor"]
		if floor < MapGenerator.FLOOR_COUNT:
			assert_gt(node["next_ids"].size(), 0, "Non-final node should have onward choices")
		if node["node_type"] == int(MapGenerator.NodeType.BATTLE) \
				or node["node_type"] == int(MapGenerator.NodeType.BOSS):
			assert_true(str(node.get("enemy_id", "")) != "", "Combat nodes should have enemy_id")
		if node["node_type"] == int(MapGenerator.NodeType.CHEST):
			assert_eq(str(node.get("enemy_id", "")), "", "Chest nodes should not have enemy_id")
		for to_id in node["next_ids"]:
			var to_node := MapGenerator.get_node_by_id(nodes, to_id)
			assert_false(to_node.is_empty(), "Edge should point to an existing node")
			assert_lte(abs(int(to_node["lane"]) - int(node["lane"])), 1,
				"Path edges should only move to adjacent lanes")

func test_available_nodes_follow_selected_path_edges() -> void:
	var nodes := MapGenerator.generate(123)
	var first_choices := MapGenerator.get_available_nodes(nodes, 0, "")
	var chosen: Dictionary = first_choices[1]

	var next_choices := MapGenerator.get_available_nodes(nodes, 1, chosen["id"])
	var expected_ids: Array = chosen["next_ids"]

	assert_gt(next_choices.size(), 0, "Selected node should unlock next choices")
	for node in next_choices:
		assert_true(str(node["id"]) in expected_ids, "Next choices must come from selected node edges")
		assert_eq(node["floor"], 2, "Next choices should be on the next floor")

func test_all_penultimate_nodes_connect_to_boss() -> void:
	var nodes := MapGenerator.generate(456)
	var penultimate := nodes.filter(func(n): return n["floor"] == MapGenerator.FLOOR_COUNT - 1)

	assert_gt(penultimate.size(), 0, "Penultimate floor should have route nodes")
	for node in penultimate:
		assert_eq(node["next_ids"], ["boss"], "Every penultimate node should lead to boss")

func test_map_scene_floor_order_is_top_to_bottom() -> void:
	var scene := MapScene.new()
	var grouped := scene._group_nodes_by_floor(MapGenerator.generate(789))
	var floors := grouped.keys()
	floors.sort()
	floors.reverse()

	assert_eq(floors[0], MapGenerator.FLOOR_COUNT, "Boss floor should render first at the top")
	assert_eq(floors[floors.size() - 1], 1, "Starting floor should render last at the bottom")
	scene.free()

func test_generated_paths_do_not_cross_between_floors() -> void:
	var nodes := MapGenerator.generate(999)
	for floor in range(1, MapGenerator.FLOOR_COUNT - 1):
		var edges: Array = []
		for node in nodes:
			if int(node["floor"]) != floor:
				continue
			for to_id in node["next_ids"]:
				var to_node := MapGenerator.get_node_by_id(nodes, to_id)
				if to_node.is_empty() or int(to_node["floor"]) != floor + 1:
					continue
				edges.append({"from": int(node["lane"]), "to": int(to_node["lane"])})
		for i in range(edges.size()):
			for j in range(i + 1, edges.size()):
				var a: Dictionary = edges[i]
				var b: Dictionary = edges[j]
				var crosses: bool = (a["from"] < b["from"] and a["to"] > b["to"]) \
					or (a["from"] > b["from"] and a["to"] < b["to"])
				assert_false(crosses, "Generated map paths should not visually cross")

func test_map_generator_places_fixed_mid_route_chest_floor() -> void:
	var nodes := MapGenerator.generate(20260528)
	var chest_floor_nodes := nodes.filter(func(n): return n["floor"] == MapGenerator.CHEST_FLOOR)

	assert_gt(chest_floor_nodes.size(), 0, "Fixed chest floor should have route nodes")
	for node in chest_floor_nodes:
		assert_eq(node["node_type"], int(MapGenerator.NodeType.CHEST),
			"Every node on the fixed chest floor should be a chest")
