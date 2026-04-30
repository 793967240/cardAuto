# src/data_models/tuning.gd
# 全局平衡性数值表 - 统一管理 tick/修整/血量等基准值
class_name Tuning extends Resource

## Tick 相关
@export var tick_duration_sec: float = 0.5   # 1 tick = 0.5 秒
@export var base_recovery_ticks: int = 2      # 修整基础时长
@export var recovery_min_ticks: int = 1       # 修整硬下限

## 玩家基础属性
@export var player_base_hp: int = 80
@export var charge_cap: int = 99              # 充能上限

## 打断相关
@export var interrupt_immune_duration: int = 4  # 打断免疫默认持续 tick

## 链条速度倍率选项
@export var speed_options: Array[float] = [1.0, 2.0, 4.0]
@export var default_speed_index: int = 1    # 默认 2x

## 战斗时长上限（防无限战斗）
@export var max_battle_ticks: int = 600     # 300 秒 @ 1x

## 全局单例路径（AutoLoad 后可直接访问）
static func get_default() -> Tuning:
	# 如果有 tres 文件则加载，否则返回默认值
	const TUNING_PATH := "res://data/tuning/default.tres"
	if ResourceLoader.exists(TUNING_PATH):
		return load(TUNING_PATH)
	return Tuning.new()
