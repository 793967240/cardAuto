extends Control

const CARD_VIEW_SCENE := preload("res://scenes/components/card_view.tscn")
const CARD_RUNTIME := preload("res://src/core/card_runtime.gd")

const SAMPLE_CARDS := [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/lie_shan_pi.tres",
	"res://data/cards/sword/zhan_nian.tres",
	"res://data/cards/sword/tian_he_yi_jian.tres",
]

@onready var battle_row: HBoxContainer = $Root/Content/BattlePanel/Margin/Rows/BattleRow
@onready var build_row: HBoxContainer = $Root/Content/BuildPanel/Margin/Rows/BuildRow
@onready var deck_row: HBoxContainer = $Root/Content/DeckPanel/Margin/Rows/DeckRow

func _ready() -> void:
	_populate()

func _populate() -> void:
	var cards := _load_sample_cards()
	if cards.is_empty():
		return
	_add_battle_samples(cards)
	_add_build_samples(cards)
	_add_deck_samples(cards)

func _load_sample_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for path in SAMPLE_CARDS:
		var card := load(path) as CardData
		if card != null:
			out.append(card)
	return out

func _add_battle_samples(cards: Array[CardData]) -> void:
	for i in range(cards.size()):
		var runtime := CARD_RUNTIME.new(cards[i])
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		battle_row.add_child(view)
		view.setup(runtime, cards[i].cost)
		if i == 1:
			view.update_progress(1)
		elif i == 2:
			view.set_active(true)
		elif i == 3:
			runtime.is_consumed = true
			view.mark_consumed()

func _add_build_samples(cards: Array[CardData]) -> void:
	var empty := CARD_VIEW_SCENE.instantiate() as CardView
	build_row.add_child(empty)
	empty.setup_build_chain_slot(null)

	for card in cards:
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		build_row.add_child(view)
		view.setup_build_chain_slot(card)

func _add_deck_samples(cards: Array[CardData]) -> void:
	for i in range(cards.size()):
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		deck_row.add_child(view)
		if i == cards.size() - 1:
			view.setup_deck_item(cards[i], 0, 2)
		else:
			view.setup_deck_item(cards[i], i + 1, 2)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
