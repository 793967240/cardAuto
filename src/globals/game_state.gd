# src/globals/game_state.gd
# 全局游戏状态单例
# AutoLoad 为 "GameState"
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
var current_run: RunState = null   # 当前 Run 状态（null = 无进行中的 Run）

## 下次战斗的元数据（由 MapScene 写入，由 BattleScene 读取）
var next_battle_enemy_id: String = ""
var next_battle_is_boss: bool = false

## 模拟战斗（构筑界面"模拟战斗"按钮）：
## 战斗结束后不推进 node_index、不写血量、不存档，跳回构筑界面。
var is_simulation: bool = false

## 构筑界面"确认/返回"应该跳回的场景路径。
## 由进入 BuildScene 之前的场景设置（默认地图）。
var build_return_scene: String = "res://scenes/map/map_scene.tscn"

## 命令行参数
var is_smoke_test: bool = false

func _ready() -> void:
	_parse_launch_args()

func _parse_launch_args() -> void:
	var args := OS.get_cmdline_args()
	if "--smoke-test" in args:
		is_smoke_test = true

## 剑修角色起始 10 张卡（路径列表）
const SWORD_STARTER_DECK: Array[String] = [
	"res://data/cards/sword/zhan.tres",
	"res://data/cards/sword/zhan.tres",          # 斩 ×2
	"res://data/cards/sword/jian_qi.tres",
	"res://data/cards/sword/xu_shi.tres",
	"res://data/cards/sword/qiang_pi.tres",
	"res://data/cards/sword/yu_jian_dun.tres",
	"res://data/cards/sword/hui_xiang_jian.tres",
	"res://data/cards/sword/chong_neng_zhan.tres",
	"res://data/cards/sword/jian_jue.tres",
	"res://data/cards/sword/qing_feng_zhan.tres",
]

func start_run(character_id: StringName) -> void:
	current_run = RunState.new()
	current_run.character_id = character_id

	# 加载起始卡组
	if character_id == &"sword":
		current_run.deck.clear()
		for path in SWORD_STARTER_DECK:
			var card_data := load(path) as CardData
			if card_data:
				current_run.deck.append(card_data)

	# 初始化 1×6 链条（全 null = 空槽位）
	current_run.chain_cards.resize(6)
	# 默认放入前 6 张作为初始构筑（玩家可在 BuildScene 调整）
	for i in range(min(6, current_run.deck.size())):
		current_run.chain_cards[i] = current_run.deck[i]

	# 生成地图
	current_run.map_nodes = MapGenerator.generate()
	current_run.node_index = 0

	EventBus.run_started.emit(character_id)

func end_run(won: bool) -> void:
	EventBus.run_ended.emit(won)
	current_run = null

func change_phase(new_phase: GamePhase) -> void:
	current_phase = new_phase
