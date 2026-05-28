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

var is_simulation: bool = false

var build_return_scene: String = "res://scenes/map/map_scene.tscn"

var is_smoke_test: bool = false

func _ready() -> void:
	_parse_launch_args()

func _parse_launch_args() -> void:
	var args := OS.get_cmdline_args()
	if "--smoke-test" in args:
		is_smoke_test = true

const SWORD_STARTER_DECK: Array[String] = [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/jian_qi.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
	"res://data/cards/sword/chong_neng_zhan.tres",
	"res://data/cards/sword/jian_jue.tres",
	"res://data/cards/sword/qing_feng_zhan.tres",
]

const BASE_SLOT_PATH := "res://data/slots/base/base_slot.tres"

const STARTER_GEMS: Array[String] = [
	"res://data/gems/ruby.tres",
	"res://data/gems/sapphire.tres",
	"res://data/gems/amber.tres",
	"res://data/gems/jade.tres",
]

func start_run(character_id: StringName) -> void:
	current_run = RunState.new()
	current_run.character_id = character_id

	if character_id == &"sword":
		current_run.deck.clear()
		for path in SWORD_STARTER_DECK:
			var card_data := load(path) as CardData
			if card_data:
				current_run.deck.append(card_data)

	_init_bases(character_id)

	current_run.chain_cards = _flatten_chain_cards(current_run)

	current_run.map_nodes = MapGenerator.generate()
	current_run.node_index = 0

	EventBus.run_started.emit(character_id)

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

	if character_id == &"sword":
		for i in range(min(base_count, current_run.deck.size())):
			current_run.base_cards[current_run.bases[i].id] = current_run.deck[i]

	current_run.gems.clear()
	for path in STARTER_GEMS:
		var gem_data := load(path) as GemData
		if gem_data:
			current_run.gems.append(gem_data)

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
