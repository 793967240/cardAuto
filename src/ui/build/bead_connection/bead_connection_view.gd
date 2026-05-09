# src/ui/build/bead_connection/bead_connection_view.gd
# 阶段 2 §2.2 / TC-2-UI-002 珠子连线 UI
#
# 独立控件，对外提供「输入底座列表 → 玩家拖珠子连线 → 输出 connections 字典」
# 的能力。设计上不依赖 BuildScene，方便单独测试和后续接入。
#
# 接口：
#   set_slots(slots: Array[SlotData])  - 设置工作台显示的底座
#   get_connections() -> Dictionary    - 取出当前连线（出口底座 id → 入口底座 id）
#   set_connections(conn: Dictionary)  - 灌入预设连线（用于读取存档）
#   signal connections_changed         - 连线变化时发射
#
# 交互（KISS 两步法，见路线图风险登记 UI-002 备注）：
#   1) 点击未选中的"出口珠" → 进入选中态（蓝色高亮）
#   2) 点击任一"入口珠" → 完成连线（出口→入口）
#   3) 点击已有连线的任一端珠子 → 删除该连线
#   4) Esc / 点空白 → 取消选中
class_name BeadConnectionView extends Control

const BEAD_SIZE := 18.0
const BEAD_OUT_COLOR := Color(0.4, 0.6, 1.0)        # 出口珠：蓝
const BEAD_IN_COLOR := Color(1.0, 0.6, 0.3)         # 入口珠：橙
const BEAD_OUT_SELECTED_COLOR := Color(0.7, 0.85, 1.0)
const BEAD_IN_SELECTED_COLOR := Color(1.0, 0.85, 0.55)
const LINE_COLOR := Color(0.85, 0.78, 0.6, 0.9)
const LINE_WIDTH := 3.0
const SLOT_BG_COLOR := Color(0.18, 0.16, 0.13, 0.85)
const SLOT_BG_ORPHAN_COLOR := Color(0.18, 0.16, 0.13, 0.35)  # orphan 灰显
const SLOT_HEIGHT := 60.0
const SLOT_GAP := 36.0
const SLOT_PAD := 14.0
const BASE_SLOT_W_PER_CELL := 50.0  # 每个槽位占的宽度（用于估算底座 visual 宽度）

signal connections_changed
signal bead_selected(slot_id: StringName, is_out: bool)

# 数据
var _slots: Array = []  # Array[SlotData]，输入顺序保留作为初始位置
var _connections: Dictionary = {}  # 出口 id → 入口 id

# 视觉布局（id → Rect2 在控件本地坐标系）
var _slot_rects: Dictionary = {}
var _bead_out_pos: Dictionary = {}  # id → Vector2（控件局部）
var _bead_in_pos: Dictionary = {}

# 交互状态
var _selected_out_id: StringName = &""  # 当前选中的出口珠（空 = 无选中）

# orphan 缓存（每次 connections_changed 后重算）
var _orphan_ids: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(800, SLOT_HEIGHT + 2 * SLOT_PAD)


## 设置底座列表（基础底座必为第一个，扩展底座按输入顺序水平摆）
func set_slots(slots: Array) -> void:
	_slots = slots
	_clear_selection()
	_recompute_layout()
	_recompute_orphans()
	queue_redraw()


func get_connections() -> Dictionary:
	return _connections.duplicate()


func set_connections(conn: Dictionary) -> void:
	_connections = conn.duplicate()
	_recompute_orphans()
	queue_redraw()
	connections_changed.emit()


## 取出当前 orphan 底座 id 列表
func get_orphan_ids() -> Array:
	return _orphan_ids.keys()


# ─── 布局 ───────────────────────────────────────────────────────

func _recompute_layout() -> void:
	_slot_rects.clear()
	_bead_out_pos.clear()
	_bead_in_pos.clear()

	var x := SLOT_PAD
	var y := SLOT_PAD
	for s in _slots:
		var sd: SlotData = s
		var w := BASE_SLOT_W_PER_CELL * sd.slot_count
		_slot_rects[sd.id] = Rect2(x, y, w, SLOT_HEIGHT)
		if sd.has_bead_in:
			_bead_in_pos[sd.id] = Vector2(x, y + SLOT_HEIGHT * 0.5)
		if sd.has_bead_out:
			_bead_out_pos[sd.id] = Vector2(x + w, y + SLOT_HEIGHT * 0.5)
		x += w + SLOT_GAP

	# 控件最小宽度跟随
	var total_w := x + SLOT_PAD
	custom_minimum_size = Vector2(maxf(total_w, 800.0), SLOT_HEIGHT + 2 * SLOT_PAD)


# ─── 绘制 ───────────────────────────────────────────────────────

func _draw() -> void:
	# 1) 底座背景
	for s in _slots:
		var sd: SlotData = s
		var rect: Rect2 = _slot_rects[sd.id]
		var bg := SLOT_BG_ORPHAN_COLOR if _orphan_ids.has(sd.id) else SLOT_BG_COLOR
		draw_rect(rect, bg, true)
		# 边框（基础底座金色，扩展底座银灰）
		var border := Color(0.85, 0.7, 0.4, 0.9) if sd.is_base() else Color(0.6, 0.6, 0.6, 0.7)
		draw_rect(rect, border, false, 2.0)
		# 槽位 id（调试用，后续接 i18n 显示 display_name_key）
		var label_pos := rect.position + Vector2(8, 22)
		var font := ThemeDB.fallback_font
		draw_string(font, label_pos, str(sd.id), HORIZONTAL_ALIGNMENT_LEFT, -1, 14,
			Color(0.95, 0.92, 0.85, 0.95))

	# 2) 已存在的连线
	for src_id in _connections:
		var dst_id = _connections[src_id]
		if not _bead_out_pos.has(src_id) or not _bead_in_pos.has(dst_id):
			continue
		var p1: Vector2 = _bead_out_pos[src_id]
		var p2: Vector2 = _bead_in_pos[dst_id]
		_draw_curve(p1, p2)

	# 3) 选中态预览线（若有出口选中且鼠标在控件内）
	if _selected_out_id != &"" and _bead_out_pos.has(_selected_out_id):
		var p1: Vector2 = _bead_out_pos[_selected_out_id]
		var mp := get_local_mouse_position()
		_draw_curve(p1, mp, true)

	# 4) 珠子（在线条之上）
	for sd_var in _slots:
		var sd: SlotData = sd_var
		if sd.has_bead_out and _bead_out_pos.has(sd.id):
			var c := BEAD_OUT_SELECTED_COLOR if sd.id == _selected_out_id else BEAD_OUT_COLOR
			draw_circle(_bead_out_pos[sd.id], BEAD_SIZE * 0.5, c)
			draw_arc(_bead_out_pos[sd.id], BEAD_SIZE * 0.5, 0, TAU, 24,
				Color(0.1, 0.1, 0.1, 0.8), 1.5)
		if sd.has_bead_in and _bead_in_pos.has(sd.id):
			# 入口珠是否被使用（着色提示）
			var used := _is_in_used(sd.id)
			var c := BEAD_IN_SELECTED_COLOR if used else BEAD_IN_COLOR
			draw_circle(_bead_in_pos[sd.id], BEAD_SIZE * 0.5, c)
			draw_arc(_bead_in_pos[sd.id], BEAD_SIZE * 0.5, 0, TAU, 24,
				Color(0.1, 0.1, 0.1, 0.8), 1.5)


func _draw_curve(p1: Vector2, p2: Vector2, is_preview: bool = false) -> void:
	# 简单的二次贝塞尔，控制点 = 中点 + 下垂
	var mid := (p1 + p2) * 0.5
	var ctrl := mid + Vector2(0, 18)  # 略微下垂
	var pts := PackedVector2Array()
	const STEPS := 16
	for i in STEPS + 1:
		var t := float(i) / STEPS
		var omt := 1.0 - t
		var pt := omt * omt * p1 + 2.0 * omt * t * ctrl + t * t * p2
		pts.append(pt)
	var color := LINE_COLOR
	if is_preview:
		color = Color(LINE_COLOR.r, LINE_COLOR.g, LINE_COLOR.b, 0.45)
	draw_polyline(pts, color, LINE_WIDTH, true)


func _is_in_used(slot_id: StringName) -> bool:
	for src_id in _connections:
		if _connections[src_id] == slot_id:
			return true
	return false


# ─── 输入处理 ────────────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click(mb.position)
			accept_event()
	elif event is InputEventMouseMotion:
		# 选中态时让预览线跟着鼠标
		if _selected_out_id != &"":
			queue_redraw()
	elif event is InputEventKey:
		var ke: InputEventKey = event
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_clear_selection()
			queue_redraw()
			accept_event()


func _handle_click(pos: Vector2) -> void:
	# 1) 命中出口珠？
	for s in _slots:
		var sd: SlotData = s
		if sd.has_bead_out and _bead_out_pos.has(sd.id):
			if _bead_hit(_bead_out_pos[sd.id], pos):
				_on_out_clicked(sd.id)
				return
	# 2) 命中入口珠？
	for s in _slots:
		var sd: SlotData = s
		if sd.has_bead_in and _bead_in_pos.has(sd.id):
			if _bead_hit(_bead_in_pos[sd.id], pos):
				_on_in_clicked(sd.id)
				return
	# 3) 点空白：清选
	_clear_selection()
	queue_redraw()


func _bead_hit(bead_pos: Vector2, click: Vector2) -> bool:
	# 命中范围比绘制半径稍大，提升触摸可达性
	return click.distance_to(bead_pos) <= BEAD_SIZE * 0.75


func _on_out_clicked(out_id: StringName) -> void:
	# 若该出口珠已有连线 → 点击删除
	if _connections.has(out_id):
		_connections.erase(out_id)
		_recompute_orphans()
		_clear_selection()
		queue_redraw()
		connections_changed.emit()
		return
	# 否则进入选中态（取消旧选中再选）
	_selected_out_id = out_id
	bead_selected.emit(out_id, true)
	queue_redraw()


func _on_in_clicked(in_id: StringName) -> void:
	# 若入口已被使用 → 点击删除该连线（用户想撤）
	for src in _connections.keys():
		if _connections[src] == in_id:
			_connections.erase(src)
			_recompute_orphans()
			_clear_selection()
			queue_redraw()
			connections_changed.emit()
			return
	# 否则尝试连线
	if _selected_out_id == &"":
		return
	if not _validate_connection(_selected_out_id, in_id):
		_clear_selection()
		queue_redraw()
		return
	_connections[_selected_out_id] = in_id
	_clear_selection()
	_recompute_orphans()
	queue_redraw()
	connections_changed.emit()


## 校验连线合法性：
##   - 不能连自己
##   - 目标必须是扩展底座（基础底座不接入）
##   - 不允许产生分叉（一个入口已被指向）
##   - 不允许成环
func _validate_connection(out_id: StringName, in_id: StringName) -> bool:
	if out_id == in_id:
		return false
	# 找目标 SlotData
	var target: SlotData = null
	for s in _slots:
		if (s as SlotData).id == in_id:
			target = s
			break
	if target == null or target.is_base():
		return false
	# 分叉检查
	for src in _connections:
		if _connections[src] == in_id:
			return false
	# 环检查：模拟加入后从 out_id 走能不能回到 in_id 之前的祖先
	var trial := _connections.duplicate()
	trial[out_id] = in_id
	var visited := {}
	var cursor: StringName = out_id
	# 从 out_id 反向走（找谁指向 out_id），看能否走到 in_id（成环）
	# 但这里 connections 是 src→dst 单向；反向需要 inverse 索引
	# 简化版：从 in_id 正向走，看能否走回 out_id
	cursor = in_id
	while cursor != &"":
		if cursor == out_id:
			return false  # 成环
		if visited.has(cursor):
			break  # 已存在的环（先不处理，按"还是允许"通过 ChainComposer 兜底报 cycle）
		visited[cursor] = true
		cursor = trial.get(cursor, &"")
	return true


func _clear_selection() -> void:
	_selected_out_id = &""


# ─── orphan 重算 ────────────────────────────────────────────────

func _recompute_orphans() -> void:
	_orphan_ids.clear()
	# 找基础底座
	var base_id: StringName = &""
	for s in _slots:
		if (s as SlotData).is_base():
			base_id = (s as SlotData).id
			break
	if base_id == &"":
		# 无基础底座 → 全部 orphan
		for s in _slots:
			if (s as SlotData).is_extension():
				_orphan_ids[(s as SlotData).id] = true
		return
	# 沿连线遍历
	var reachable := {base_id: true}
	var cursor: StringName = base_id
	var safety := 100
	while _connections.has(cursor) and safety > 0:
		var nxt = _connections[cursor]
		if reachable.has(nxt):
			break  # 环（ChainComposer 会报错，这里只是终止遍历）
		reachable[nxt] = true
		cursor = nxt
		safety -= 1
	# 不在 reachable 里的扩展底座都是 orphan
	for s in _slots:
		var sd: SlotData = s
		if sd.is_extension() and not reachable.has(sd.id):
			_orphan_ids[sd.id] = true
