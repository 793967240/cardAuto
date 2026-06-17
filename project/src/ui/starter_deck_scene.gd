class_name StarterDeckScene extends Control

const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")
const MAP_SCENE := "res://scenes/map/map_scene.tscn"

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/SubtitleLabel
@onready var decks_row: HBoxContainer = $Margin/VBox/DecksRow

func _ready() -> void:
	if GameState.current_run == null:
		GameState.start_run(&"sword")
	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	_render_decks()

func _update_texts() -> void:
	title_label.text = tr("starter_deck.title")
	subtitle_label.text = tr("starter_deck.subtitle")

func _render_decks() -> void:
	for child in decks_row.get_children():
		child.queue_free()

	for i in range(GameState.SWORD_STARTER_DECKS.size()):
		decks_row.add_child(_make_deck_panel(i, GameState.SWORD_STARTER_DECKS[i]))

func _make_deck_panel(deck_index: int, deck_def: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(280, 780)
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_deck_pressed.bind(deck_index))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 14)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 14)
	btn.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 8)
	margin.add_child(box)

	var name_label := Label.new()
	name_label.text = tr(deck_def.get("name_key", ""))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override(&"font_size", 24)
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = tr(deck_def.get("desc_key", ""))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.custom_minimum_size = Vector2(0, 32)
	box.add_child(desc_label)

	var cards_column := VBoxContainer.new()
	cards_column.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cards_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_column.add_theme_constant_override(&"separation", 6)
	box.add_child(cards_column)

	var paths: Array = deck_def.get("cards", [])
	for path_var in paths:
		var card := load(String(path_var)) as CardData
		if card == null:
			continue
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		cards_column.add_child(view)
		view.setup_deck_item(card, 1, 1)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE

	return btn

func _on_deck_pressed(deck_index: int) -> void:
	GameState.apply_starter_deck(deck_index)
	var save := SaveSystem.new()
	save.save_run(GameState.current_run)
	get_tree().change_scene_to_file(MAP_SCENE)
