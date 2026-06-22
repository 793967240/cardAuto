extends GutTest

func test_compendium_scene_instantiates() -> void:
	var packed := load("res://scenes/compendium_scene.tscn") as PackedScene
	assert_not_null(packed, "Compendium scene should load")
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame

	assert_gt(scene.cards_grid.get_child_count(), 0, "Compendium should list cards")
	assert_gt(scene.gems_grid.get_child_count(), 0, "Compendium should list gems")
	assert_gt(scene.relics_grid.get_child_count(), 0, "Compendium should list relics")

	scene.queue_free()
