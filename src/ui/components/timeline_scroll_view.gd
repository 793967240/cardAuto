class_name TimelineScrollView extends ScrollContainer

const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")
const TICK_WIDTH := 80
const TIMELINE_BG_PATH := "res://assets/style_anchors/xianxia_anchor_08_timeline.jpg"

@onready var timeline_container: Control = $TimelineContainer
@onready var cards_hbox: HBoxContainer = $TimelineContainer/CardsHBox
@onready var cursor_glow: Panel = $TimelineContainer/CursorGlow
@onready var recovery_overlay: ColorRect = $TimelineContainer/RecoveryOverlay
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_label: Label = $TooltipPanel/Margin/Label

var _combatant_id: StringName
var _chain: Chain
var _card_views: Array[CardView] = []
var _total_ticks: int = 0
var _recovery_duration: int = 0
var _is_player: bool = false
var _bg_texture: Texture2D
var _tick_font: Font
## 战斗时间轴引用，用于 60fps 平滑插值（cursor + 当前卡进度条）。
## 由 BattleScene 在 start_battle 后通过 bind_timeline() 注入，可能为 null。
var _timeline: Timeline

func _ready() -> void:
	timeline_container.draw.connect(_on_timeline_container_draw)
	tooltip_panel.hide()

	# 加载水墨卷轴底图（已存在 assets/style_anchors/）
	if ResourceLoader.exists(TIMELINE_BG_PATH):
		_bg_texture = load(TIMELINE_BG_PATH) as Texture2D

	# 用主题字体绘制刻度数字（思源宋体）
	var df := get_theme_default_font()
	if df:
		_tick_font = df
	else:
		_tick_font = ThemeDB.fallback_font

func setup(combatant_id: StringName, chain: Chain, is_player: bool = false) -> void:
	_combatant_id = combatant_id
	_chain = chain
	_is_player = is_player

	EventBus.battle_tick_advanced.connect(_on_tick_advanced)
	EventBus.card_fired.connect(_on_card_fired)
	EventBus.chain_recovery_started.connect(_on_recovery_started)
	EventBus.chain_recovery_ended.connect(_on_recovery_ended)

	_build_timeline()

## 由 BattleScene 在战斗启动后注入 Timeline 引用，开启 60fps 平滑刷新。
## 在调用本方法之前，UI 仍然能正常显示（按 tick 阶梯式刷新）。
func bind_timeline(timeline: Timeline) -> void:
	_timeline = timeline
	# 立即刷新一次，避免等到下一帧才显示初始位置
	_update_visuals()

func _build_timeline() -> void:
	for child in cards_hbox.get_children():
		child.queue_free()
	_card_views.clear()

	_total_ticks = 0
	for card in _chain.slots:
		var cost: int = card.data.cost
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		cards_hbox.add_child(view)
		view.setup(card, cost)

		view.mouse_entered.connect(_show_tooltip.bind(card, view))
		view.mouse_exited.connect(_hide_tooltip)

		_card_views.append(view)
		_total_ticks += cost

	# 适应 21:9 / 4K，最小宽度 = viewport 宽度，留尾部 padding 用于 recovery 阶段
	var min_w := get_viewport_rect().size.x
	timeline_container.custom_minimum_size.x = max(min_w, _total_ticks * TICK_WIDTH + 600)
	recovery_overlay.custom_minimum_size.x = timeline_container.custom_minimum_size.x

	timeline_container.queue_redraw()
	_update_visuals()

## 每帧驱动平滑刷新（绑定 Timeline 后启用 60fps 插值）。
func _process(_delta: float) -> void:
	if _chain == null or _timeline == null:
		return
	_update_visuals()

## Tick 信号回退路径：仅当未绑定 Timeline 时使用（保留兼容）。
## 已绑定时由 _process 每帧刷新，避免重复刷新。
func _on_tick_advanced(_tick: int) -> void:
	if _chain == null:
		return
	if _timeline != null:
		return
	_update_visuals()

func _on_card_fired(combatant_id: StringName, _card_id: StringName, index: int) -> void:
	if combatant_id != _combatant_id: return
	if index < _card_views.size() and index < _chain.slots.size():
		if _chain.slots[index].is_consumed:
			_card_views[index].mark_consumed()

func _on_recovery_started(combatant_id: StringName, duration: int) -> void:
	if combatant_id != _combatant_id: return
	_recovery_duration = duration
	recovery_overlay.show()
	timeline_container.queue_redraw()

func _on_recovery_ended(combatant_id: StringName) -> void:
	if combatant_id != _combatant_id: return
	recovery_overlay.hide()
	_build_timeline()

func _update_visuals() -> void:
	if _chain.slots.is_empty(): return

	var current_idx: int = _chain.current_index
	var current_prog: int = _chain.current_card_progress
	var is_recovering: bool = _chain.is_recovering()

	# 60fps 平滑：取 tick 内累积的小数进度（0.0~1.0）。
	# 未绑定 timeline 时 frac = 0，行为退化为按 tick 阶梯刷新。
	var frac: float = _timeline.get_tick_progress() if _timeline != null else 0.0

	var passed_ticks := 0
	for i in range(_card_views.size()):
		var view := _card_views[i]
		var cost: int = _chain.slots[i].data.cost

		view.set_active(i == current_idx and not is_recovering)
		view.set_recovering(is_recovering)

		if i < current_idx:
			view.update_progress_smooth(float(cost))
		elif i == current_idx:
			# 当前正在执行的卡牌：整数进度 + 小数部分（不超过 cost）
			if is_recovering:
				view.update_progress_smooth(0.0)
			else:
				view.update_progress_smooth(minf(float(cost), float(current_prog) + frac))
		else:
			view.update_progress_smooth(0.0)

		if i < current_idx:
			passed_ticks += cost

	# Cursor 跟随刻度，带左侧 padding（与 CardsHBox 的 offset_left 一致）。
	# 直接每帧 set position（按需求选择无 tween 平滑，60fps 由 _process 驱动）。
	const CARDS_PADDING_LEFT := 12.0
	var cursor_x: float = CARDS_PADDING_LEFT
	if not is_recovering:
		cursor_x += (float(passed_ticks + current_prog) + frac) * TICK_WIDTH
	else:
		var elapsed_recovery: float = float(_recovery_duration - _chain.recovery_remaining) + frac
		# 修整阶段最后一 tick 不再继续累积小数，避免越过 _recovery_duration
		elapsed_recovery = minf(elapsed_recovery, float(_recovery_duration))
		cursor_x += (float(_total_ticks) + elapsed_recovery) * TICK_WIDTH

	cursor_glow.position.x = cursor_x

	# 玩家时间轴自动滚动跟随 cursor
	if _is_player:
		var scroll_x := scroll_horizontal
		var view_w := size.x
		if cursor_x > scroll_x + view_w * 0.8:
			scroll_horizontal = int(cursor_x - view_w * 0.5)

func _on_timeline_container_draw() -> void:
	var c_size := timeline_container.size
	var rect := Rect2(0, 0, c_size.x, c_size.y)

	# 1) 米黄底色（统一基调）
	timeline_container.draw_rect(rect, Color(0.88, 0.82, 0.7, 1.0))

	# 2) 卷轴纹理叠加（半透明，避免抢戏）
	if _bg_texture:
		timeline_container.draw_texture_rect(_bg_texture, rect, true, Color(1, 0.95, 0.85, 0.35))

	# 3) 顶部 / 底部墨色边线
	timeline_container.draw_line(Vector2(0, 0), Vector2(c_size.x, 0), Color(0.32, 0.24, 0.18, 0.85), 2.0)
	timeline_container.draw_line(Vector2(0, c_size.y - 1), Vector2(c_size.x, c_size.y - 1), Color(0.32, 0.24, 0.18, 0.65), 1.5)

	# 4) 刻度线 + 数字（数字字号 16，思源宋体描边可读）
	const CARDS_PADDING_LEFT := 12.0
	var max_ticks: int = int((c_size.x - CARDS_PADDING_LEFT) / TICK_WIDTH) + 1
	for i in range(max_ticks):
		var x: float = CARDS_PADDING_LEFT + i * TICK_WIDTH
		if x > c_size.x: break
		var is_major: bool = (i % 5 == 0)
		var line_color := Color(0.32, 0.24, 0.18, 0.6 if is_major else 0.3)
		var line_len: float = 12.0 if is_major else 6.0
		timeline_container.draw_line(Vector2(x, 0), Vector2(x, line_len), line_color, 1.5)
		timeline_container.draw_line(Vector2(x, c_size.y - line_len), Vector2(x, c_size.y), line_color, 1.5)

		if is_major and _tick_font and i > 0:
			var label: String = str(i)
			var text_color := Color(0.28, 0.18, 0.12, 0.95)
			# 底部绘制刻度数字（更显眼，避免与顶栏冲突）
			timeline_container.draw_string(_tick_font, Vector2(x + 4, c_size.y - line_len - 4), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, text_color)

func _show_tooltip(card: CardRuntime, view: CardView) -> void:
	var t: String = "[%s]  Cost: %d\n" % [tr(card.data.display_name_key), card.data.cost]
	t += tr(card.data.desc_key)
	tooltip_label.text = t
	tooltip_panel.show()
	tooltip_panel.reset_size()
	# 定位 tooltip：卡牌正上方，留 12px 间距
	var view_global: Vector2 = view.global_position
	var tooltip_pos := view_global + Vector2(0, -tooltip_panel.size.y - 12)
	# 防止 tooltip 顶出屏幕顶部
	if tooltip_pos.y < 8:
		tooltip_pos.y = view_global.y + view.size.y + 8
	# 防止 tooltip 超出屏幕左右边界
	var viewport_w: float = get_viewport_rect().size.x
	tooltip_pos.x = clampf(tooltip_pos.x, 8.0, viewport_w - tooltip_panel.size.x - 8.0)
	tooltip_panel.global_position = tooltip_pos

func _hide_tooltip() -> void:
	tooltip_panel.hide()
