class_name BuildScene extends Control

const TICK_DURATION: float = 0.5
const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")

@onready var base_grid: GridContainer = $VBox/Body/BasePanel/BaseMargin/BaseGrid
@onready var gem_title: Label = $VBox/Body/GemPanel/GemMargin/GemVBox/GemTitle
@onready var gem_target_label: Label = $VBox/Body/GemPanel/GemMargin/GemVBox/GemTargetLabel
@onready var gem_list_vbox: VBoxContainer = $VBox/Body/GemPanel/GemMargin/GemVBox/GemScroll/GemListVBox
@onready var deck_grid: GridContainer = $VBox/Body/DeckPanel/DeckMargin/DeckVBox/Scroll/DeckGrid
@onready var deck_label: Label = $VBox/Body/DeckPanel/DeckMargin/DeckVBox/DeckLabel
@onready var total_duration_label: Label = $VBox/Footer/TotalDurationLabel
@onready var simulate_btn: Button = $VBox/Footer/SimulateBtn
@onready var confirm_btn: Button = $VBox/Footer/ConfirmBtn
@onready var back_btn: Button = $VBox/Footer/BackBtn
@onready var title_label: Label = $VBox/Header/TitleLabel

var _selected_card: CardData = null
var _selected_card_view: CardView = null

var _gem_target_base_id: StringName = &""


func _ready() -> void:
	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	simulate_btn.pressed.connect(_on_simulate_pressed)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	if GameState.current_run == null:
		GameState.start_run(&"sword")

	_refresh_all()

func _update_texts() -> void:
	title_label.text = tr("build.title")
	deck_label.text = tr("build.label.deck")
	gem_title.text = tr("build.label.gems")
	simulate_btn.text = tr("build.button.simulate")
	confirm_btn.text = tr("build.button.confirm")
	back_btn.text = tr("ui.button.back")

func _refresh_all() -> void:
	_rebuild_bases()
	_rebuild_gem_panel()
	_rebuild_deck_list()
	_update_total_duration()

func _rebuild_bases() -> void:
	for child in base_grid.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return
	for s in run.bases:
		var sd: SlotData = s
		var card: CardData = run.base_cards.get(sd.id, null)
		var gems: Array = run.base_gems.get(sd.id, [])

		var panel := VBoxContainer.new()
		panel.add_theme_constant_override(&"separation", 4)
		base_grid.add_child(panel)

		var name_label := Label.new()
		name_label.text = "#%s" % str(sd.id).replace("base_", "")
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		panel.add_child(name_label)

		var view := CARD_VIEW_SCENE.instantiate() as CardView
		panel.add_child(view)
		view.setup_build_slot(card)
		view.set_meta(&"base_id", sd.id)
		view.pressed.connect(_on_base_slot_pressed.bind(sd.id, view))

		if _gem_target_base_id == sd.id:
			view.set_selected(true)

		var gem_label := Label.new()
		if gems.size() > 0 and gems[0] != null:
			var gd: GemData = gems[0]
			gem_label.text = "[ %s ]" % tr(gd.get_name_key())
		else:
			gem_label.text = tr("build.gem.empty")
		gem_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gem_label.add_theme_font_size_override(&"font_size", 12)
		panel.add_child(gem_label)

func _on_base_slot_pressed(button_index: int, base_id: StringName, _view: CardView) -> void:
	var run := GameState.current_run
	if run == null:
		return
	if button_index == MOUSE_BUTTON_RIGHT:
		if run.base_cards.has(base_id) and run.base_cards[base_id] != null:
			run.base_cards[base_id] = null
			_refresh_all()
		return
	if _selected_card != null:
		run.base_cards[base_id] = _selected_card
		_clear_selection()
		_refresh_all()
	else:
		_gem_target_base_id = base_id
		_refresh_all()

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
	var current_gem: GemData = null
	if current_gems.size() > 0:
		current_gem = current_gems[0]

	if current_gem != null:
		var clear_btn := Button.new()
		clear_btn.text = tr("build.gem.clear")
		clear_btn.pressed.connect(_on_gem_clear_pressed)
		gem_list_vbox.add_child(clear_btn)

	for g in run.gems:
		var gd: GemData = g
		var btn := Button.new()
		var label := tr(gd.get_name_key())
		if current_gem != null and current_gem.id == gd.id:
			label = "● " + label
		btn.text = label
		btn.tooltip_text = tr(gd.get_desc_key())
		btn.pressed.connect(_on_gem_pick_pressed.bind(gd))
		gem_list_vbox.add_child(btn)

func _on_gem_pick_pressed(gd: GemData) -> void:
	var run := GameState.current_run
	if run == null or _gem_target_base_id == &"":
		return
	run.base_gems[_gem_target_base_id] = [gd]
	_refresh_all()

func _on_gem_clear_pressed() -> void:
	var run := GameState.current_run
	if run == null or _gem_target_base_id == &"":
		return
	run.base_gems[_gem_target_base_id] = []
	_refresh_all()

func _rebuild_deck_list() -> void:
	for child in deck_grid.get_children():
		child.queue_free()
	var run := GameState.current_run
	if run == null:
		return

	var used_counts: Dictionary = {}
	for k in run.base_cards:
		var c: CardData = run.base_cards[k]
		if c != null:
			used_counts[c.id] = int(used_counts.get(c.id, 0)) + 1

	var deck_counts: Dictionary = {}
	for c in run.deck:
		deck_counts[c.id] = int(deck_counts.get(c.id, 0)) + 1

	var displayed: Dictionary = {}
	for c in run.deck:
		if displayed.has(c.id):
			continue
		displayed[c.id] = true
		var total: int = deck_counts[c.id]
		var used: int = int(used_counts.get(c.id, 0))
		var available: int = total - used

		var view := CARD_VIEW_SCENE.instantiate() as CardView
		deck_grid.add_child(view)
		view.setup_deck_item(c, available, total)
		view.pressed.connect(_on_deck_card_pressed.bind(c, view, available))

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
	var spec := ChainComposer.Spec.new()
	spec.bases = run.bases.duplicate()
	spec.base_cards = run.base_cards.duplicate()
	spec.base_gems = run.base_gems.duplicate()
	var result := ChainComposer.compose(spec)
	var flat: Array[CardData] = []
	for cs in result.layout:
		var slot: ChainSlot = cs
		if slot.card and slot.card.data:
			flat.append(slot.card.data)
	run.chain_cards = flat

func _pick_simulation_enemy_id() -> String:
	return BuildScene.pick_simulation_enemy_id(GameState.current_run)

static func pick_simulation_enemy_id(run: RunState) -> String:
	if run == null or run.map_nodes == null:
		return "slime"
	var start_idx: int = run.node_index + 1
	for i in range(start_idx, run.map_nodes.size()):
		var n: Dictionary = run.map_nodes[i]
		var enemy_id: String = n.get("enemy_id", "")
		if enemy_id != "":
			return enemy_id
	return "slime"
