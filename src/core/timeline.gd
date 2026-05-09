# src/core/timeline.gd
# 时间轴 Tick 调度器 - 核心时序引擎
# 不依赖任何 UI 节点，可在 Headless 环境运行
class_name Timeline extends RefCounted

## 基础 tick 时长（秒），来自 Tuning 资源，默认 0.5s
const DEFAULT_TICK_DURATION_SEC := 0.5

var _tick_duration_sec: float = DEFAULT_TICK_DURATION_SEC
var _accumulator: float = 0.0
var _current_tick: int = 0
var _speed_multiplier: float = 1.0  # 1x / 2x / 4x

signal tick_advanced(tick: int)

## 初始化时可从 Tuning 资源覆盖 tick 时长
func setup(tick_duration: float = DEFAULT_TICK_DURATION_SEC) -> void:
	_tick_duration_sec = tick_duration

## 每帧调用，推进时间轴
func update(delta: float) -> void:
	_accumulator += delta * _speed_multiplier
	while _accumulator >= _tick_duration_sec:
		_accumulator -= _tick_duration_sec
		_current_tick += 1
		tick_advanced.emit(_current_tick)

## 设置加速倍率（1.0 / 2.0 / 4.0）
func set_speed_multiplier(mult: float) -> void:
	_speed_multiplier = mult

func get_speed_multiplier() -> float:
	return _speed_multiplier

func get_current_tick() -> int:
	return _current_tick

## 当前 tick 内已累积的进度（0.0 ~ 1.0），供 UI 60fps 平滑插值使用。
## 注意：受 speed_multiplier 影响的实际推进速度已经体现在 _accumulator 中，
## 这里只暴露归一化后的小数部分。
func get_tick_progress() -> float:
	if _tick_duration_sec <= 0.0:
		return 0.0
	return clampf(_accumulator / _tick_duration_sec, 0.0, 1.0)

## 重置时间轴（战斗开始时调用）
func reset() -> void:
	_accumulator = 0.0
	_current_tick = 0

## 无 delta 直接推进指定 tick 数（用于 Headless 模拟）
func advance_ticks(count: int) -> void:
	for i in count:
		_current_tick += 1
		tick_advanced.emit(_current_tick)
