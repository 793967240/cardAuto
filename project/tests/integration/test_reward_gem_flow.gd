# tests/integration/test_reward_gem_flow.gd
# 阶段 2 奖励池集成：战斗后奖励可以产出并领取宝石。
extends GutTest

var _save: SaveSystem
const RESOURCE_CATALOG = preload("res://src/meta/resource_catalog.gd")

func before_each() -> void:
	_save = SaveSystem.new()
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null

func after_each() -> void:
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null

func test_reward_pool_draw_options_includes_gem_and_cards() -> void:
	var options := RewardPool.draw_options(&"sword", 3, 20260528)

	assert_eq(options.size(), 3, "Mixed reward should produce 3 options")

	var gem_count := 0
	var card_count := 0
	for option in options:
		assert_true(option.has("type"), "Reward option should have type")
		assert_true(option.has("resource"), "Reward option should have resource")
		if option["type"] == &"gem":
			gem_count += 1
			assert_true(option["resource"] is GemData, "Gem option should carry GemData")
		elif option["type"] == &"card":
			card_count += 1
			assert_true(option["resource"] is CardData, "Card option should carry CardData")
		else:
			fail_test("Unknown reward option type: %s" % str(option["type"]))

	assert_gte(gem_count, 1, "Mixed reward should include at least one gem")
	assert_gte(card_count, 1, "Mixed reward should still include card options")

func test_resource_catalog_matches_reward_data_files() -> void:
	assert_eq(RESOURCE_CATALOG.card_paths(&"sword").size(), _count_tres_files("res://data/cards/sword/"),
		"Sword card catalog should include every top-level card resource")
	assert_eq(RESOURCE_CATALOG.gem_paths().size(), _count_tres_files("res://data/gems/"),
		"Gem catalog should include every gem resource")
	assert_eq(RESOURCE_CATALOG.relic_paths().size(), _count_tres_files("res://data/relics/"),
		"Relic catalog should include every relic resource")

	for path in RESOURCE_CATALOG.card_paths(&"sword"):
		assert_true(FileAccess.file_exists(path), "Catalog card path should exist: %s" % path)
		assert_true(load(path) is CardData, "Catalog card path should load CardData: %s" % path)
	for path in RESOURCE_CATALOG.gem_paths():
		assert_true(FileAccess.file_exists(path), "Catalog gem path should exist: %s" % path)
		assert_true(load(path) is GemData, "Catalog gem path should load GemData: %s" % path)
	for path in RESOURCE_CATALOG.relic_paths():
		assert_true(FileAccess.file_exists(path), "Catalog relic path should exist: %s" % path)
		assert_true(load(path) is RelicData, "Catalog relic path should load RelicData: %s" % path)

func test_reward_pool_draw_options_is_seed_deterministic() -> void:
	var first := RewardPool.draw_options(&"sword", 3, 99)
	var second := RewardPool.draw_options(&"sword", 3, 99)

	assert_eq(_option_ids(first), _option_ids(second), "Same seed should produce same mixed reward ids")

func test_chest_reward_draws_relic_or_gem() -> void:
	var option := RewardPool.draw_chest(20260528)

	assert_false(option.is_empty(), "Chest should produce a reward")
	assert_true(option["type"] == &"relic" or option["type"] == &"gem",
		"Chest reward should be relic or gem")
	if option["type"] == &"relic":
		assert_true(option["resource"] is RelicData, "Relic chest reward should carry RelicData")
	else:
		assert_true(option["resource"] is GemData, "Gem chest reward should carry GemData")

func test_reward_scene_gem_pick_adds_gem_advances_and_saves() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run
	run.map_nodes = MapGenerator.generate(123)
	run.node_index = 1
	GameState.pending_map_node_id = "f2_l0"
	var gem_count_before := run.gems.size()
	var ruby := load("res://data/gems/ruby.tres") as GemData
	assert_not_null(ruby, "load ruby")

	RewardScene.apply_reward(run, &"gem", ruby)
	var next_scene := RewardScene.finalize_run(run)

	assert_eq(run.gems.size(), gem_count_before + 1, "Picking a gem should add it to run gem inventory")
	assert_true(run.gems[run.gems.size() - 1] is GemInstance, "Picked gem should be an independent instance")
	assert_eq((run.gems[run.gems.size() - 1] as GemInstance).data.id, &"ruby", "Picked gem should be ruby")
	assert_eq(run.node_index, 2, "Reward finalize should advance node")
	assert_eq(run.current_node_id, "f2_l0", "Reward finalize should remember picked map node")
	assert_eq(next_scene, "res://scenes/map/map_scene.tscn", "Reward finalize should return to map mid-run")
	assert_true(_save.has_active_run(), "Reward finalize should save run")

	var loaded := _save.load_run()
	assert_not_null(loaded, "Saved run should load")
	if loaded:
		assert_eq(loaded.node_index, 2, "Loaded run should preserve advanced node")
		assert_gt(loaded.gems.size(), gem_count_before, "Loaded run should preserve picked gem")

func test_chest_relic_pick_adds_relic_and_persists() -> void:
	GameState.start_run(&"sword")
	var run := GameState.current_run
	run.map_nodes = MapGenerator.generate(321)
	run.node_index = 2
	GameState.pending_map_node_id = "f3_l1"
	var relic := load("res://data/relics/ancient_coin.tres") as RelicData
	assert_not_null(relic, "load relic")

	var scene := MapScene.new()
	scene._apply_chest_reward({"type": &"relic", "resource": relic})
	var next_scene := RewardScene.finalize_run(run)
	scene.free()

	assert_eq(run.relics.size(), 1, "Chest relic should be added to run")
	assert_eq(run.relics[0].id, &"ancient_coin", "Picked relic should be ancient_coin")
	assert_eq(next_scene, "res://scenes/map/map_scene.tscn", "Chest should continue the run")

	var loaded := _save.load_run()
	assert_not_null(loaded, "Saved run should load")
	if loaded:
		assert_eq(loaded.relics.size(), 1, "Loaded run should preserve relic")
		assert_eq(loaded.relics[0].id, &"ancient_coin", "Loaded relic id should match")

func _option_ids(options: Array[Dictionary]) -> Array[String]:
	var ids: Array[String] = []
	for option in options:
		var res: Resource = option.get("resource", null)
		var rid := ""
		if res is CardData:
			rid = str((res as CardData).id)
		elif res is GemData:
			rid = str((res as GemData).id)
		elif res is RelicData:
			rid = str((res as RelicData).id)
		ids.append("%s:%s" % [str(option.get("type", "")), rid])
	return ids

func _count_tres_files(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	assert_not_null(dir, "Data directory should exist: %s" % dir_path)
	if dir == null:
		return 0
	var count := 0
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			count += 1
		fname = dir.get_next()
	dir.list_dir_end()
	return count
