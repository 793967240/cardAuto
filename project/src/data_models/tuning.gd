class_name Tuning extends Resource

@export var tick_duration_sec: float = 0.5

@export var player_base_hp: int = 80
@export var charge_cap: int = 99

@export var interrupt_immune_duration: int = 4

@export var speed_options: Array[float] = [1.0, 2.0, 4.0]
@export var default_speed_index: int = 1

@export var max_battle_ticks: int = 600

@export var base_count: int = 8

static func get_default() -> Tuning:
	const TUNING_PATH := "res://data/tuning/default.tres"
	if ResourceLoader.exists(TUNING_PATH):
		return load(TUNING_PATH)
	return Tuning.new()
