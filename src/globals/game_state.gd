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

## 命令行参数
var is_smoke_test: bool = false

func _ready() -> void:
	_parse_launch_args()

func _parse_launch_args() -> void:
	var args := OS.get_cmdline_args()
	if "--smoke-test" in args:
		is_smoke_test = true

func start_run(character_id: StringName) -> void:
	current_run = RunState.new()
	current_run.character_id = character_id
	EventBus.run_started.emit(character_id)

func end_run(won: bool) -> void:
	EventBus.run_ended.emit(won)
	current_run = null

func change_phase(new_phase: GamePhase) -> void:
	current_phase = new_phase
