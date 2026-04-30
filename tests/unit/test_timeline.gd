# tests/unit/test_timeline.gd
# Timeline 单元测试
extends GutTest

var _timeline: Timeline

func before_each() -> void:
	_timeline = Timeline.new()

func after_each() -> void:
	_timeline = null

# ─── tick 推进测试 ────────────────────────────────────────────

func test_tick_advances_at_1x_speed() -> void:
	var tick_count := 0
	_timeline.tick_advanced.connect(func(_t): tick_count += 1)

	# 1 秒 @ 1x = 2 tick（1 tick = 0.5s）
	_timeline.update(1.0)
	assert_eq(tick_count, 2, "1 second should advance 2 ticks at 1x speed")

func test_tick_advances_at_2x_speed() -> void:
	_timeline.set_speed_multiplier(2.0)
	var tick_count := 0
	_timeline.tick_advanced.connect(func(_t): tick_count += 1)

	_timeline.update(1.0)
	assert_eq(tick_count, 4, "1 second at 2x should advance 4 ticks")

func test_tick_advances_at_4x_speed() -> void:
	_timeline.set_speed_multiplier(4.0)
	var tick_count := 0
	_timeline.tick_advanced.connect(func(_t): tick_count += 1)

	_timeline.update(1.0)
	assert_eq(tick_count, 8, "1 second at 4x should advance 8 ticks")

func test_partial_second_accumulates() -> void:
	var tick_count := 0
	_timeline.tick_advanced.connect(func(_t): tick_count += 1)

	# 0.4 秒 不足一个 tick
	_timeline.update(0.4)
	assert_eq(tick_count, 0, "0.4 second should not advance any tick")

	# 再 0.2 秒，累计 0.6 秒 = 1 tick
	_timeline.update(0.2)
	assert_eq(tick_count, 1, "0.6 seconds total should advance 1 tick")

func test_reset_clears_state() -> void:
	_timeline.update(2.0)
	_timeline.reset()
	assert_eq(_timeline.get_current_tick(), 0, "After reset, current_tick should be 0")

func test_get_current_tick_increments() -> void:
	_timeline.update(1.0)
	assert_eq(_timeline.get_current_tick(), 2, "current_tick should be 2 after 1 second")

func test_advance_ticks_direct() -> void:
	var ticks_received: Array[int] = []
	_timeline.tick_advanced.connect(func(t): ticks_received.append(t))
	_timeline.advance_ticks(3)
	assert_eq(ticks_received.size(), 3, "advance_ticks(3) should emit 3 signals")
	assert_eq(ticks_received, [1, 2, 3], "Tick values should be sequential")

func test_speed_multiplier_getter() -> void:
	_timeline.set_speed_multiplier(4.0)
	assert_eq(_timeline.get_speed_multiplier(), 4.0, "get_speed_multiplier should return set value")
