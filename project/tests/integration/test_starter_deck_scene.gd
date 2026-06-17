extends GutTest

var _save: SaveSystem
var _scene: StarterDeckScene

func before_each() -> void:
	_save = SaveSystem.new()
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null

func after_each() -> void:
	if is_instance_valid(_scene):
		_scene.queue_free()
		await get_tree().process_frame
	if _save.has_active_run():
		_save.delete_run()
	GameState.current_run = null

func test_starter_deck_scene_renders_deck_cards_before_card_view_ready() -> void:
	GameState.start_run(&"sword")
	var packed := load("res://scenes/starter_deck_scene.tscn") as PackedScene
	_scene = packed.instantiate() as StarterDeckScene
	add_child(_scene)
	await get_tree().process_frame

	assert_eq(_scene.decks_row.get_child_count(), GameState.SWORD_STARTER_DECKS.size(),
		"Starter card repository scene should render all repository choices")
	for panel in _scene.decks_row.get_children():
		var card_column := _find_card_column(panel)
		assert_not_null(card_column, "Starter card repository cards should be arranged in a vertical column")
		var card_views := panel.find_children("*", "CardView", true, false)
		assert_eq(card_views.size(), 3, "Each starter card repository choice should render three cards")
		for card_view in card_views:
			var view := card_view as CardView
			assert_eq(view.mode, CardView.Mode.BUILD_DECK_ITEM,
				"Starter card repository previews should use repository item mode")
			assert_eq(int(view.custom_minimum_size.y), CardView.BUILD_DECK_HEIGHT,
				"Starter card repository previews should use the taller repository card height")
			assert_gte(int(view.desc_label.size.y), 74,
				"Starter card repository preview effect text should have room for at least four lines")
			assert_true(view.build_name_label.visible,
				"Starter card repository preview should show the dedicated build name label")
			assert_ne(view.build_name_label.text, "",
				"Starter card repository preview card name should not be empty")
			var name_bottom := int(view.build_name_label.get_global_rect().end.y)
			var art_top := int(view.art_rect.get_global_rect().position.y)
			assert_lte(name_bottom, art_top,
				"Starter card repository preview card name should sit above the card art")
		for i in range(card_views.size()):
			for j in range(i + 1, card_views.size()):
				assert_false(
					(card_views[i] as Control).get_global_rect().intersects((card_views[j] as Control).get_global_rect()),
					"Starter card repository previews should not overlap"
				)

func _find_card_column(root: Node) -> VBoxContainer:
	for child in root.find_children("*", "VBoxContainer", true, false):
		var has_card_view := false
		for maybe_card in child.get_children():
			if maybe_card is CardView:
				has_card_view = true
				break
		if has_card_view:
			return child as VBoxContainer
	return null
