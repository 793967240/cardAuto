class_name BuildScene extends Control

const TICK_DURATION: float = 0.5
const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")
const PAPER_TEXT_COLOR := Color(0.24, 0.18, 0.12, 1.0)
const PAPER_MUTED_TEXT_COLOR := Color(0.42, 0.34, 0.24, 1.0)
const GOLD_TEXT_COLOR := Color(0.92, 0.82, 0.50, 1.0)
const GEM_BUTTON_TEXT_COLOR := Color(0.96, 0.94, 0.88, 1.0)
const GEM_BUTTON_SELECTED_TEXT_COLOR := Color(1.0, 0.92, 0.62, 1.0)
const GEM_BUTTON_DESC_TEXT_COLOR := Color(0.86, 0.84, 0.78, 1.0)
const GEM_BUTTON_COLLAPSED_HEIGHT := 44.0
const GEM_BUTTON_EXPANDED_HEIGHT := 104.0
const MAX_CONSUMABLE_CARDS_PER_CHAIN := 2

@onready var base_chain_hbox: HBoxContainer = $VBox/Body/MainArea/BasePanel/BaseMargin/BaseScroll/BaseChainHBox
@onready var gem_title: Label = $VBox/Body/GemPanel/GemMargin/GemVBox/GemTitle
@onready var gem_target_label: Label = $VBox/Body/GemPanel/GemMargin/GemVBox/GemTargetLabel
@onready var gem_list_vbox: VBoxContainer = $VBox/Body/GemPanel/GemMargin/GemVBox/GemScroll/GemListVBox
@onready var deck_grid: GridContainer = $VBox/Body/MainArea/DeckPanel/DeckMargin/DeckVBox/Scroll/DeckGrid
@onready var deck_label: Label = $VBox/Body/MainArea/DeckPanel/DeckMargin/DeckVBox/DeckLabel
@onready var total_duration_label: Label = $VBox/Header/TotalDurationLabel
@onready var simulate_btn: Button = $VBox/Header/SimulateBtn
@onready var confirm_btn: Button = $VBox/Header/ConfirmBtn
@onready var back_btn: Button = $VBox/Header/BackBtn
@onready var title_label: Label = $VBox/Header/TitleLabel

var _selected_card: CardData = null
var _selected_card_view: CardView = null

var _gem_target_base_id: StringName = &""
var _tip_label: Label = null
var _tip_tween: Tween = null


func _ready() -> void:
	_apply_static_text_contrast()
	deck_grid.set_meta(&"on_drop", Callable(self, "_on_deck_area_drop"))
	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	simulate_btn.pressed.connect(_on_simulate_pressed)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	if GameState.current_run == null:
		GameState.start_run(&"sword")

	_setup_tip_label()
	_refresh_all()

func _update_texts() -> void:
	title_label.text = tr("build.title")
	deck_label.text = tr("build.label.deck")
	gem_title.text = tr("build.label.gems")
	simulate_btn.text = tr("build.button.simulate")
	confirm_btn.text = tr("build.button.confirm")
	back_btn.text = tr("ui.button.back")

func _apply_static_text_contrast() -> void:
	deck_label.add_theme_color_override(&"font_color", PAPER_TEXT_COLOR)
	gem_title.add_theme_color_override(&"font_color", PAPER_TEXT_COLOR)
	gem_target_label.add_theme_color_override(&"font_color", PAPER_MUTED_TEXT_COLOR)
	total_duration_label.add_theme_color_override(&"font_color", Color(0.86, 0.86, 0.82, 1.0))

func _refresh_all() -> void:
	_rebuild_bases()
	_rebuild_gem_panel()
	_rebuild_deck_list()
	_update_total_duration()

func _rebuild_bases() -> void:
	for child in base_chain_hbox.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return
	for i in range(run.bases.size()):
		var s: SlotData = run.bases[i]
		var sd: SlotData = s
		var card: CardData = run.base_cards.get(sd.id, null)
		var gems: Array = run.base_gems.get(sd.id, [])

		var panel := VBoxContainer.new()
		panel.add_theme_constant_override(&"separation", 4)
		base_chain_hbox.add_child(panel)

		var name_label := Label.new()
		name_label.text = "#%s" % str(sd.id).replace("base_", "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override(&"font_color", PAPER_MUTED_TEXT_COLOR)
		name_label.add_theme_font_size_override(&"font_size", 16)
		panel.add_child(name_label)

		var view := CARD_VIEW_SCENE.instantiate() as CardView
		panel.add_child(view)
		view.setup_build_chain_slot(card)
		view.set_meta(&"base_id", sd.id)
		view.set_meta(&"slot_index", i)
		view.set_meta(&"on_drop", Callable(self, "_on_chain_slot_drop"))
		view.pressed.connect(_on_base_slot_pressed.bind(sd.id, view))

		if _gem_target_base_id == sd.id:
			view.set_selected(true)

		var gem_label := Label.new()
		if gems.size() > 0 and gems[0] != null:
			var gd := gem_data_from_entry(gems[0])
			gem_label.text = "[ %s ]" % tr(gd.get_name_key()) if gd != null else tr("build.gem.empty")
		else:
			gem_label.text = tr("build.gem.empty")
		gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gem_label.add_theme_font_size_override(&"font_size", 12)
		gem_label.add_theme_color_override(&"font_color", PAPER_MUTED_TEXT_COLOR)
		panel.add_child(gem_label)

		if i < run.bases.size() - 1:
			base_chain_hbox.add_child(_make_chain_arrow())

func _make_chain_arrow() -> Control:
	var arrow_wrap := CenterContainer.new()
	arrow_wrap.custom_minimum_size = Vector2(16, CardView.BUILD_CHAIN_SLOT_HEIGHT)
	arrow_wrap.size_flags_vertical = SIZE_SHRINK_CENTER

	var arrow := Label.new()
	arrow.text = ">"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.add_theme_font_size_override(&"font_size", 20)
	arrow.add_theme_color_override(&"font_color", Color(0.58, 0.45, 0.22, 1.0))
	arrow_wrap.add_child(arrow)
	return arrow_wrap

func _on_base_slot_pressed(button_index: int, base_id: StringName, _view: CardView) -> void:
	var run := GameState.current_run
	if run == null:
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		return
	if _selected_card != null:
		if not try_place_card_on_base(run, base_id, _selected_card):
			_show_tip(tr("build.tip.consumable_limit"))
			return
		_clear_selection()
		_refresh_all()
	else:
		_gem_target_base_id = base_id
		_refresh_all()

func _on_chain_slot_drop(target_slot_index: int, payload: Dictionary) -> void:
	var run := GameState.current_run
	if not apply_chain_slot_drop(run, target_slot_index, payload):
		if _drop_would_exceed_consumable_limit(run, target_slot_index, payload):
			_show_tip(tr("build.tip.consumable_limit"))
		return

	var target_base_id: StringName = run.bases[target_slot_index].id
	_clear_selection()
	_gem_target_base_id = target_base_id
	_refresh_all()

func _on_deck_area_drop(payload: Dictionary) -> void:
	var run := GameState.current_run
	if not apply_deck_area_drop(run, payload):
		return
	_clear_selection()
	_refresh_all()

static func apply_chain_slot_drop(run: RunState, target_slot_index: int, payload: Dictionary) -> bool:
	if run == null:
		return false
	if target_slot_index < 0 or target_slot_index >= run.bases.size():
		return false
	if not payload.has("source") or not payload.has("card"):
		return false

	var target_base_id: StringName = run.bases[target_slot_index].id
	var source := String(payload.get("source", ""))

	if source == "deck_item":
		var card := payload.get("card", null) as CardData
		if card == null or available_count_for_card(run, card) <= 0:
			return false
		if not try_place_card_on_base(run, target_base_id, card):
			return false
	elif source == "slot":
		var source_slot_index := int(payload.get("slot_index", -1))
		if source_slot_index < 0 or source_slot_index >= run.bases.size():
			return false
		if source_slot_index == target_slot_index:
			return false
		var source_base_id: StringName = run.bases[source_slot_index].id
		var source_card: CardData = run.base_cards.get(source_base_id, null)
		var target_card: CardData = run.base_cards.get(target_base_id, null)
		run.base_cards[target_base_id] = source_card
		run.base_cards[source_base_id] = target_card
	else:
		return false
	return true

static func try_place_card_on_base(run: RunState, target_base_id: StringName, card: CardData) -> bool:
	if run == null or target_base_id == &"" or card == null:
		return false
	if consumable_count_after_placing(run, target_base_id, card) > MAX_CONSUMABLE_CARDS_PER_CHAIN:
		return false
	run.base_cards[target_base_id] = card
	return true

static func consumable_count_after_placing(run: RunState, target_base_id: StringName, card: CardData) -> int:
	if run == null:
		return 0
	var count := 0
	for base in run.bases:
		var base_id: StringName = base.id
		var c: CardData = card if base_id == target_base_id else run.base_cards.get(base_id, null)
		if is_consumable_card(c):
			count += 1
	return count

static func is_consumable_card(card: CardData) -> bool:
	return card != null and (card.consumable or card.tags.has(&"consumable"))

static func _drop_would_exceed_consumable_limit(run: RunState, target_slot_index: int, payload: Dictionary) -> bool:
	if run == null or target_slot_index < 0 or target_slot_index >= run.bases.size():
		return false
	if String(payload.get("source", "")) != "deck_item":
		return false
	var card := payload.get("card", null) as CardData
	if not is_consumable_card(card):
		return false
	return consumable_count_after_placing(run, run.bases[target_slot_index].id, card) > MAX_CONSUMABLE_CARDS_PER_CHAIN

static func apply_deck_area_drop(run: RunState, payload: Dictionary) -> bool:
	if run == null:
		return false
	if String(payload.get("source", "")) != "slot":
		return false
	var source_slot_index := int(payload.get("slot_index", -1))
	if source_slot_index < 0 or source_slot_index >= run.bases.size():
		return false
	var source_base_id: StringName = run.bases[source_slot_index].id
	if run.base_cards.get(source_base_id, null) == null:
		return false
	run.base_cards[source_base_id] = null
	return true

func _rebuild_gem_panel() -> void:
	for child in gem_list_vbox.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return

	if _gem_target_base_id == &"":
		gem_target_label.text = tr("build.gem.no_target")
		return

	gem_target_label.text = tr("build.gem.target") % str(_gem_target_base_id).replace("base_", "#")

	var current_gems: Array = run.base_gems.get(_gem_target_base_id, [])
	var current_gem = null
	if current_gems.size() > 0:
		current_gem = current_gems[0]

	if current_gem != null:
		var clear_btn := Button.new()
		clear_btn.text = tr("build.gem.clear")
		clear_btn.pressed.connect(_on_gem_clear_pressed)
		gem_list_vbox.add_child(clear_btn)

	for g in run.gems:
		var gd := gem_data_from_entry(g)
		if gd == null:
			continue
		var is_selected: bool = current_gem != null and current_gem == g
		var btn := _make_gem_button(gd, is_selected)
		btn.pressed.connect(_on_gem_pick_pressed.bind(g))
		gem_list_vbox.add_child(btn)

func _make_gem_button(gd: GemData, is_selected: bool) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.tooltip_text = tr(gd.get_desc_key())
	btn.custom_minimum_size = Vector2(0, GEM_BUTTON_EXPANDED_HEIGHT if is_selected else GEM_BUTTON_COLLAPSED_HEIGHT)
	btn.size_flags_horizontal = SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 6)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 6)
	btn.add_child(margin)

	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override(&"separation", 4)
	margin.add_child(content)

	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = ("%s %s" % ["●", tr(gd.get_name_key())]) if is_selected else tr(gd.get_name_key())
	name_label.add_theme_font_size_override(&"font_size", 16)
	name_label.add_theme_color_override(&"font_color", GEM_BUTTON_SELECTED_TEXT_COLOR if is_selected else GEM_BUTTON_TEXT_COLOR)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	content.add_child(name_label)

	if is_selected:
		var desc_label := Label.new()
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_label.text = tr(gd.get_desc_key())
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override(&"font_size", 13)
		desc_label.add_theme_color_override(&"font_color", GEM_BUTTON_DESC_TEXT_COLOR)
		desc_label.size_flags_horizontal = SIZE_EXPAND_FILL
		desc_label.size_flags_vertical = SIZE_EXPAND_FILL
		content.add_child(desc_label)

	return btn

func _on_gem_pick_pressed(gem) -> void:
	var run := GameState.current_run
	if run == null or _gem_target_base_id == &"":
		return
	install_gem_instance(run, _gem_target_base_id, gem)
	_refresh_all()

func _on_gem_clear_pressed() -> void:
	var run := GameState.current_run
	if run == null or _gem_target_base_id == &"":
		return
	run.base_gems[_gem_target_base_id] = []
	_refresh_all()

static func install_gem_instance(run: RunState, target_base_id: StringName, gem) -> bool:
	if run == null or target_base_id == &"" or gem == null:
		return false
	var gd := gem_data_from_entry(gem)
	if gd == null:
		return false
	for base_id in run.base_gems.keys():
		var arr: Array = run.base_gems[base_id]
		for i in range(arr.size() - 1, -1, -1):
			if arr[i] == gem:
				arr.remove_at(i)
		run.base_gems[base_id] = arr
	run.base_gems[target_base_id] = [gem]
	return true

static func gem_data_from_entry(gem) -> GemData:
	if gem is GemInstance:
		return (gem as GemInstance).data
	if gem is GemData:
		return gem as GemData
	return null

func _rebuild_deck_list() -> void:
	for child in deck_grid.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return
	_update_deck_columns()

	var remaining_used := _used_counts_by_card(run)
	for i in range(run.deck.size()):
		var c: CardData = run.deck[i]
		if c == null:
			continue
		var used: int = int(remaining_used.get(c.id, 0))
		if used > 0:
			remaining_used[c.id] = used - 1
			continue
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		deck_grid.add_child(view)
		view.setup_deck_item(c, 1, 1)
		view.set_meta(&"deck_index", i)
		view.set_meta(&"on_drop", Callable(self, "_on_deck_area_drop"))
		view.pressed.connect(_on_deck_card_pressed.bind(c, view, 1))

static func _used_counts_by_card(run: RunState) -> Dictionary:
	var used_counts: Dictionary = {}
	if run == null:
		return used_counts
	for k in run.base_cards:
		var c: CardData = run.base_cards[k]
		if c != null:
			used_counts[c.id] = int(used_counts.get(c.id, 0)) + 1
	return used_counts

static func available_count_for_card(run: RunState, card: CardData) -> int:
	if run == null or card == null:
		return 0
	var total := 0
	for deck_card in run.deck:
		if deck_card != null and deck_card.id == card.id:
			total += 1
	var used := 0
	for k in run.base_cards:
		var base_card: CardData = run.base_cards[k]
		if base_card != null and base_card.id == card.id:
			used += 1
	return total - used

func _update_deck_columns() -> void:
	var available_width := deck_grid.get_parent_area_size().x
	if available_width <= 0.0:
		available_width = get_viewport_rect().size.x - 360.0
	var h_gap := 10.0
	var card_pitch := float(CardView.BUILD_DECK_WIDTH) + h_gap
	deck_grid.columns = maxi(2, int(floor((available_width + h_gap) / card_pitch)))

func _on_deck_card_pressed(button_index: int, card: CardData, view: CardView, available: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if available <= 0:
		return
	_clear_selection()
	_selected_card = card
	_selected_card_view = view
	view.set_selected(true)

func _clear_selection() -> void:
	if is_instance_valid(_selected_card_view):
		_selected_card_view.set_selected(false)
	_selected_card = null
	_selected_card_view = null

func _update_total_duration() -> void:
	var run := GameState.current_run
	var total_ticks: int = 0
	if run != null:
		var spec := ChainComposer.Spec.new()
		spec.bases = run.bases.duplicate()
		spec.base_cards = run.base_cards.duplicate()
		spec.base_gems = run.base_gems.duplicate()
		var result := ChainComposer.compose(spec)
		total_ticks = result.total_cost
	var seconds: float = total_ticks * TICK_DURATION
	total_duration_label.text = tr("build.label.total_duration") + ": %d tick (%.1fs)" % [total_ticks, seconds]

func _setup_tip_label() -> void:
	if _tip_label != null:
		return
	_tip_label = Label.new()
	_tip_label.visible = false
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override(&"font_size", 18)
	_tip_label.add_theme_color_override(&"font_color", Color(1.0, 0.91, 0.62, 1.0))
	_tip_label.add_theme_color_override(&"font_outline_color", Color(0.05, 0.03, 0.01, 0.95))
	_tip_label.add_theme_constant_override(&"outline_size", 5)
	_tip_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tip_label.offset_top = 70.0
	_tip_label.offset_bottom = 106.0
	add_child(_tip_label)

func _show_tip(text: String) -> void:
	_setup_tip_label()
	_tip_label.text = text
	_tip_label.modulate = Color.WHITE
	_tip_label.visible = true
	if _tip_tween != null and _tip_tween.is_running():
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_interval(1.2)
	_tip_tween.tween_property(_tip_label, "modulate:a", 0.0, 0.35)
	_tip_tween.finished.connect(func(): _tip_label.visible = false)

func _on_simulate_pressed() -> void:
	_persist_chain_cards_compat()
	GameState.is_simulation = true
	GameState.next_battle_enemy_id = _pick_simulation_enemy_id()
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")

func _on_confirm_pressed() -> void:
	_persist_chain_cards_compat()
	var save := SaveSystem.new()
	save.save_run(GameState.current_run)
	get_tree().change_scene_to_file(GameState.build_return_scene)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(GameState.build_return_scene)

func _persist_chain_cards_compat() -> void:
	var run := GameState.current_run
	if run == null:
		return
	var flat: Array[CardData] = []
	for base in run.bases:
		var card: CardData = run.base_cards.get(base.id, null)
		if card != null:
			flat.append(card)
	run.chain_cards = flat

func _pick_simulation_enemy_id() -> String:
	return BuildScene.pick_simulation_enemy_id(GameState.current_run)

static func pick_simulation_enemy_id(run: RunState) -> String:
	if run == null or run.map_nodes == null:
		return "slime"
	var available := MapGenerator.get_available_nodes(run.map_nodes, run.node_index, run.current_node_id)
	for n in available:
		var enemy_id: String = n.get("enemy_id", "")
		if enemy_id != "":
			return enemy_id
	for n in run.map_nodes:
		if int(n.get("floor", n.get("node_index", 0))) <= run.node_index:
			continue
		var enemy_id: String = n.get("enemy_id", "")
		if enemy_id != "":
			return enemy_id
	return "slime"
