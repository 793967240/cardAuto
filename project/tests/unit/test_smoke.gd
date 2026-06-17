# tests/unit/test_smoke.gd
# 最基础的 smoke 测试 - 验证项目能跑起来
extends GutTest

func test_smoke_pass() -> void:
	assert_true(true, "Smoke test: project is alive")

func test_timeline_class_exists() -> void:
	var t := Timeline.new()
	assert_not_null(t, "Timeline class should be instantiable")

func test_chain_class_exists() -> void:
	# Chain 需要 Combatant 参数，先跳过构造测试
	assert_true(Chain != null, "Chain class should be loadable")

func test_battle_simulator_class_exists() -> void:
	var sim := BattleSimulator.new()
	assert_not_null(sim, "BattleSimulator should be instantiable")
