extends Node

enum GamePhase {
	MAIN_MENU,
	MAP,
	BATTLE,
	BUILD,
	SHOP,
	EVENT,
	CAMPFIRE,
	GAME_OVER,
}

var current_phase: GamePhase = GamePhase.MAIN_MENU
var current_run: RunState = null

var next_battle_enemy_id: String = ""
var next_battle_is_boss: bool = false
var pending_map_node_id: String = ""

var is_simulation: bool = false

var build_return_scene: String = "res://scenes/map/map_scene.tscn"

var is_smoke_test: bool = false

func _ready() -> void:
	_parse_launch_args()

func _parse_launch_args() -> void:
	var args := OS.get_cmdline_args()
	if "--smoke-test" in args:
		is_smoke_test = true

const SWORD_STARTER_DECKS: Array[Dictionary] = [
	{
		"id": &"swift_blade",
		"name_key": "starter_deck.swift_blade.name",
		"desc_key": "starter_deck.swift_blade.desc",
		"cards": [
			"res://data/cards/sword/liu_yun_jian.tres",
			"res://data/cards/sword/yang_jian_shi.tres",
			"res://data/cards/sword/ci_jian.tres",
		],
	},
	{
		"id": &"charge_break",
		"name_key": "starter_deck.charge_break.name",
		"desc_key": "starter_deck.charge_break.desc",
		"cards": [
			"res://data/cards/sword/ju_qi.tres",
			"res://data/cards/sword/xu_shi.tres",
			"res://data/cards/sword/duan_yue_zhan.tres",
		],
	},
	{
		"id": &"guard_counter",
		"name_key": "starter_deck.guard_counter.name",
		"desc_key": "starter_deck.guard_counter.desc",
		"cards": [
			"res://data/cards/sword/yun_ti.tres",
			"res://data/cards/sword/yu_jian_dun.tres",
			"res://data/cards/sword/fan_shou.tres",
		],
	},
]

const BASE_SLOT_PATH := "res://data/slots/base/base_slot.tres"

func start_run(character_id: StringName) -> void:
	current_run = RunState.new()
	current_run.character_id = character_id

	_init_bases(character_id)

	current_run.chain_cards = _flatten_chain_cards(current_run)

	current_run.map_nodes = MapGenerator.generate()
	current_run.node_index = 0
	current_run.current_node_id = ""

	EventBus.run_started.emit(character_id)

func apply_starter_deck(deck_index: int) -> void:
	if current_run == null or current_run.character_id != &"sword":
		return
	if deck_index < 0 or deck_index >= SWORD_STARTER_DECKS.size():
		return

	current_run.deck.clear()
	for k in current_run.base_cards:
		current_run.base_cards[k] = null

	var deck_def: Dictionary = SWORD_STARTER_DECKS[deck_index]
	var paths: Array = deck_def.get("cards", [])
	for path_var in paths:
		var path := String(path_var)
		var card_data := load(path) as CardData
		if card_data:
			current_run.deck.append(card_data)

	for i in range(min(current_run.deck.size(), current_run.bases.size())):
		current_run.base_cards[current_run.bases[i].id] = current_run.deck[i]

	current_run.chain_cards = _flatten_chain_cards(current_run)

func _init_bases(character_id: StringName) -> void:
	current_run.bases.clear()
	current_run.base_cards.clear()
	current_run.base_gems.clear()

	var tuning := Tuning.get_default()
	var base_count := tuning.base_count

	var base_slot := load(BASE_SLOT_PATH) as SlotData
	if base_slot == null:
		base_slot = SlotData.new()
		base_slot.id = &"base_slot"
		base_slot.display_name_key = "slot.base.name"
		base_slot.gem_socket_count = 1

	for i in range(base_count):
		var slot := base_slot.duplicate() as SlotData
		slot.id = StringName("base_%d" % i)
		current_run.bases.append(slot)
		current_run.base_gems[slot.id] = []

	current_run.gems.clear()

static func _flatten_chain_cards(run: RunState) -> Array[CardData]:
	var out: Array[CardData] = []
	if run == null:
		return out
	for s in run.bases:
		var c: CardData = run.base_cards.get(s.id, null)
		if c != null:
			out.append(c)
	return out

func end_run(won: bool) -> void:
	EventBus.run_ended.emit(won)
	current_run = null

func change_phase(new_phase: GamePhase) -> void:
	current_phase = new_phase
