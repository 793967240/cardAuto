# tools/ui_resolution_check.gd
# 多分辨率 UI 巡检脚本
# 用法（必须有显示，不可 headless）：
#   godot --path . --script tools/ui_resolution_check.gd
#
# 行为：
#   - 4 档分辨率 × 4 个场景 = 16 张截图，存到 reports/ui_audit/{res}/{scene}.png
#   - 每个分辨率写 overflow.json，列出超出 viewport 的 Control 节点
#   - 任一 overflow → 退出 1
extends SceneTree

const RESOLUTIONS := [
	{"name": "1920x1080", "size": Vector2i(1920, 1080)},
	{"name": "2560x1440", "size": Vector2i(2560, 1440)},
	{"name": "1280x800",  "size": Vector2i(1280, 800)},
	{"name": "3440x1440", "size": Vector2i(3440, 1440)},
]

const SCENES := [
	{"name": "main_menu", "path": "res://scenes/main_menu.tscn"},
	{"name": "battle",    "path": "res://scenes/battle/battle_scene.tscn"},
	{"name": "build",     "path": "res://scenes/build/build_scene.tscn"},
	{"name": "map",       "path": "res://scenes/map/map_scene.tscn"},
]

const OUT_REL := "reports/ui_audit"

func _initialize() -> void:
	# 必须在主线程异步执行；用 _initialize 启动 deferred 任务
	call_deferred("_run_async")

func _run_async() -> void:
	# 给 SceneTree 一帧建立完毕
	await process_frame
	await process_frame
	var overall_overflows := 0
	for res_entry in RESOLUTIONS:
		var res_name: String = res_entry["name"]
		var size: Vector2i = res_entry["size"]
		print("\n--- Resolution %s ---" % res_name)
		DisplayServer.window_set_size(size)
		await process_frame
		await process_frame
		# 实际渲染目标 size（canvas_items stretch 下，viewport 保持基准 1920×1200，
		# 内容按比例拉伸到 window 内；这里我们以 viewport 实际 size 作为越界基准）
		var actual_viewport: Vector2i = Vector2i(get_root().get_viewport().get_visible_rect().size)

		var overflow_entries: Array = []
		for scn in SCENES:
			var scene_name: String = scn["name"]
			var scene_path: String = scn["path"]
			var ok := await _capture_scene(res_name, scene_name, scene_path, actual_viewport, overflow_entries)
			print("  %s %s" % [("OK" if ok else "ERR"), scene_name])

		_write_overflow(res_name, size, actual_viewport, overflow_entries)
		overall_overflows += overflow_entries.size()

	print("\n====== Done ======")
	print("total overflow nodes: %d" % overall_overflows)
	if overall_overflows > 0:
		print("RESULT: FAIL (overflow detected)")
		quit(1)
		return
	print("RESULT: OK")
	quit(0)

func _capture_scene(res_name: String, scene_name: String, scene_path: String,
		size: Vector2i, overflow_out: Array) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("cannot load %s" % scene_path)
		return false

	# 准备一个干净的 GameState 以便 build/map/battle 不跳回主菜单
	_ensure_run_state()

	# 清空 root 子节点，挂入新场景
	var root := get_root()
	for child in root.get_children():
		# 跳过 autoload 节点（它们是根节点的直接子节点）
		if child.name in ["GameState", "Settings", "EventBus"]:
			continue
		root.remove_child(child)
		child.queue_free()
	await process_frame

	var instance := packed.instantiate()
	root.add_child(instance)
	# 等渲染稳定（多帧 + 下一物理帧）
	await process_frame
	await process_frame
	await process_frame

	# 截图
	var img: Image = root.get_viewport().get_texture().get_image()
	var out_dir := ProjectSettings.globalize_path("res://" + OUT_REL + "/" + res_name)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := "%s/%s.png" % [out_dir, scene_name]
	var err := img.save_png(out_path)
	if err != OK:
		push_error("save png failed: %s" % out_path)

	# Overflow 检测
	_collect_overflow(instance, scene_name, size, overflow_out)

	# 清理
	instance.queue_free()
	await process_frame
	return true

func _collect_overflow(node: Node, scene_name: String, viewport: Vector2i, out: Array) -> void:
	# 检查 Control 节点是否超出 viewport
	# 跳过：ScrollContainer 内部子节点（滚动内容超出是预期）、不可见节点、空尺寸节点
	_walk_for_overflow(node, scene_name, viewport, false, out)

func _walk_for_overflow(node: Node, scene_name: String, viewport: Vector2i,
		inside_scroll: bool, out: Array) -> void:
	var ctrl: Control = node as Control
	if ctrl != null:
		if not ctrl.visible:
			return
		if not inside_scroll:
			var rect: Rect2 = ctrl.get_global_rect()
			if rect.size.x > 0 and rect.size.y > 0:
				var overflow: bool = false
				if rect.position.x < -1.0 or rect.position.y < -1.0:
					overflow = true
				if rect.position.x + rect.size.x > viewport.x + 1.0:
					overflow = true
				if rect.position.y + rect.size.y > viewport.y + 1.0:
					overflow = true
				if overflow:
					out.append({
						"scene": scene_name,
						"node": String(ctrl.get_path()),
						"class": ctrl.get_class(),
						"rect": {
							"x": rect.position.x, "y": rect.position.y,
							"w": rect.size.x, "h": rect.size.y,
						},
						"viewport": {"w": viewport.x, "h": viewport.y},
					})
	# 进入 ScrollContainer 后，其所有后代都不参与越界检查
	var next_inside_scroll: bool = inside_scroll or (ctrl is ScrollContainer)
	for child in node.get_children():
		_walk_for_overflow(child, scene_name, viewport, next_inside_scroll, out)

func _write_overflow(res_name: String, requested: Vector2i, actual_viewport: Vector2i, overflows: Array) -> void:
	var doc := {
		"resolution": res_name,
		"requested_window": {"w": requested.x, "h": requested.y},
		"actual_viewport": {"w": actual_viewport.x, "h": actual_viewport.y},
		"overflows": overflows,
	}
	var out_dir := ProjectSettings.globalize_path("res://" + OUT_REL + "/" + res_name)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var out_path := out_dir + "/overflow.json"
	var f := FileAccess.open(out_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(doc, "  "))

func _ensure_run_state() -> void:
	# 确保 GameState.current_run 非 null（map_scene/build_scene 依赖）
	var gs := get_root().get_node_or_null("GameState")
	if gs == null:
		return
	if gs.current_run == null and gs.has_method("start_run"):
		gs.start_run(&"sword")
