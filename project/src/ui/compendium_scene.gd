class_name CompendiumScene extends Control

const CARD_DIRS := ["res://data/cards/sword/"]
const GEM_DIR := "res://data/gems/"
const RELIC_DIR := "res://data/relics/"

@onready var title_label: Label = $Margin/VBox/Header/Title
@onready var back_button: Button = $Margin/VBox/Header/BackButton
@onready var tabs: TabContainer = $Margin/VBox/Tabs
@onready var cards_grid: GridContainer = $Margin/VBox/Tabs/Cards/Scroll/Grid
@onready var gems_grid: GridContainer = $Margin/VBox/Tabs/Gems/Scroll/Grid
@onready var relics_grid: GridContainer = $Margin/VBox/Tabs/Relics/Scroll/Grid

func _ready() -> void:
	_update_texts()
	back_button.pressed.connect(_on_back_pressed)
	if not EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.connect(_on_language_changed)
	_populate()

func _update_texts() -> void:
	title_label.text = tr("compendium.title")
	back_button.text = tr("ui.button.back")
	tabs.set_tab_title(0, tr("compendium.cards"))
	tabs.set_tab_title(1, tr("compendium.gems"))
	tabs.set_tab_title(2, tr("compendium.relics"))

func _populate() -> void:
	_clear(cards_grid)
	_clear(gems_grid)
	_clear(relics_grid)
	for card in _load_cards():
		cards_grid.add_child(_make_card_entry(card))
	for gem in _load_resources(GEM_DIR, GemData):
		gems_grid.add_child(_make_simple_entry(tr(gem.get_name_key()), tr(gem.get_desc_key()), "gem"))
	for relic in _load_resources(RELIC_DIR, RelicData):
		relics_grid.add_child(_make_simple_entry(tr(relic.get_name_key()), tr(relic.get_desc_key()), _rarity_label(relic.rarity)))

func _clear(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _make_card_entry(card: CardData) -> Control:
	var entry := _make_entry_shell()
	var box := entry.get_node("Margin/Box") as VBoxContainer
	_add_entry_label(box, tr(card.get_name_key()), 17, Color(1.0, 0.86, 0.50, 1.0))
	_add_entry_label(box, "%s  cost %d" % [_card_type_label(card.card_type), card.cost], 12, Color(0.74, 0.66, 0.50, 0.90))
	_add_entry_label(box, tr(card.get_desc_key()), 13, Color(0.92, 0.86, 0.72, 0.96), true)
	return entry

func _make_simple_entry(title: String, desc: String, meta: String) -> Control:
	var entry := _make_entry_shell()
	var box := entry.get_node("Margin/Box") as VBoxContainer
	_add_entry_label(box, title, 17, Color(1.0, 0.86, 0.50, 1.0))
	_add_entry_label(box, meta, 12, Color(0.74, 0.66, 0.50, 0.90))
	_add_entry_label(box, desc, 13, Color(0.92, 0.86, 0.72, 0.96), true)
	return entry

func _make_entry_shell() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 142)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override(&"panel", _entry_style())
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.name = "Box"
	box.add_theme_constant_override(&"separation", 6)
	margin.add_child(box)
	return panel

func _add_entry_label(parent: VBoxContainer, text: String, size: int, color: Color, wrap := false) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if wrap:
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(label)

func _load_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for dir_path in CARD_DIRS:
		for card in _load_resources(dir_path, CardData):
			if card is CardData and not (card as CardData).is_upgraded():
				out.append(card)
	out.sort_custom(func(a: CardData, b: CardData): return tr(a.get_name_key()) < tr(b.get_name_key()))
	return out

func _load_resources(dir_path: String, type: Variant) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res := load(dir_path + fname)
			if is_instance_of(res, type):
				out.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	out.sort_custom(func(a, b): return tr(a.get_name_key()) < tr(b.get_name_key()))
	return out

func _card_type_label(card_type: int) -> String:
	match card_type:
		CardData.CardType.ATTACK:
			return tr("card.type.attack")
		CardData.CardType.DEFENSE:
			return tr("card.type.defense")
		CardData.CardType.BUFF:
			return tr("card.type.buff")
		CardData.CardType.CONTROL:
			return tr("card.type.control")
		CardData.CardType.SUMMON:
			return tr("card.type.summon")
		_:
			return tr("card.type.special")

func _rarity_label(rarity: int) -> String:
	match rarity:
		RelicData.Rarity.COMMON:
			return tr("compendium.rarity.common")
		RelicData.Rarity.UNCOMMON:
			return tr("compendium.rarity.uncommon")
		_:
			return tr("compendium.rarity.rare")

func _entry_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.09, 0.06, 0.86)
	sb.border_color = Color(0.62, 0.45, 0.22, 0.70)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb

func _on_language_changed(_locale: String) -> void:
	_update_texts()
	_populate()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.is_echo()):
		_on_back_pressed()
