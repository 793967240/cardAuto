# tests/headless_runner.gd
# Headless CI 测试入口
# 用法: godot --headless --script tests/headless_runner.gd
extends SceneTree

func _init() -> void:
	var gut = load("res://addons/gut/gut.gd").new()
	get_root().add_child(gut)

	gut.log_level = 1
	gut.add_directory("res://tests/unit")
	gut.add_directory("res://tests/integration")

	gut.end_run.connect(func():
		var fail = gut.get_fail_count()
		var pass_ = gut.get_pass_count()
		print("\n====== TEST RESULTS ======")
		print("PASSED: %d  FAILED: %d" % [pass_, fail])
		if fail > 0:
			print("RESULT: FAILED")
			quit(1)
		else:
			print("RESULT: PASSED")
			quit(0)
	)

	gut.run_tests()
