class_name CardView extends Control

## 通用卡牌组件。支持三种显示模式：
##   - BATTLE：战斗时间线（按 cost 拉宽，显示进度条 / 高光 / 划线 / 恢复遮罩）
##   - BUILD_SLOT：构筑界面链条槽位
##       * 空底座默认打击/非空：170×280，显示默认打击或杀戮尖塔风格大卡
##         上=名称，中=卡面图（ArtRect/ArtTexture），下=类型横条+效果描述
##         边框颜色随 rarity 变化
##   - BUILD_DECK_ITEM：构筑界面卡牌仓库卡（固定 184×276，右下角库存角标 ×N/M）
##
## 拖拽：BUILD_SLOT(非空) / BUILD_DECK_ITEM 模式参与拖拽；BATTLE 不参与。
## 拖拽预览：与拖拽源同尺寸同布局（卡牌仓库 → 184×276，链上 → 170×280）

enum Mode { BATTLE, BUILD_SLOT, BUILD_DECK_ITEM }

const BASE_WIDTH := 80
const BASE_HEIGHT := 120
const BUILD_DECK_WIDTH := 184
const BUILD_DECK_HEIGHT := 276
const BUILD_SLOT_WIDTH := 162
const BUILD_SLOT_HEIGHT := 276
const BUILD_SLOT_EMPTY_W := BUILD_SLOT_WIDTH
const BUILD_SLOT_EMPTY_H := BUILD_SLOT_HEIGHT
const BUILD_CHAIN_SLOT_WIDTH := 170
const BUILD_CHAIN_SLOT_HEIGHT := 280
const BUILD_CHAIN_SLOT_EMPTY_W := BUILD_CHAIN_SLOT_WIDTH
const BUILD_CHAIN_SLOT_EMPTY_H := BUILD_CHAIN_SLOT_HEIGHT

## 类型 → 卡面占位色（无 icon 时）
const TYPE_COLORS: Dictionary = {
	0: Color(0.55, 0.18, 0.15, 1),  # ATTACK 红
	1: Color(0.18, 0.32, 0.55, 1),  # DEFENSE 蓝
	2: Color(0.20, 0.45, 0.22, 1),  # BUFF 绿
	3: Color(0.40, 0.22, 0.50, 1),  # CONTROL 紫
	4: Color(0.55, 0.45, 0.15, 1),  # SUMMON 黄
	5: Color(0.30, 0.30, 0.35, 1),  # SPECIAL 灰
}

## 类型 → 显示文字（i18n key）
const TYPE_LABEL_KEYS: Dictionary = {
	0: "card.type.attack",
	1: "card.type.defense",
	2: "card.type.buff",
	3: "card.type.control",
	4: "card.type.summon",
	5: "card.type.special",
}

## 类型 → 横条颜色
const TYPE_BAR_COLORS: Dictionary = {
	0: Color(0.45, 0.13, 0.10, 0.95),
	1: Color(0.13, 0.25, 0.45, 0.95),
	2: Color(0.15, 0.38, 0.18, 0.95),
	3: Color(0.32, 0.16, 0.42, 0.95),
	4: Color(0.45, 0.36, 0.12, 0.95),
	5: Color(0.22, 0.22, 0.27, 0.95),
}

## 稀有度 → 边框颜色（普通=灰、罕见=蓝、稀有=金）
const RARITY_BORDER_COLORS: Dictionary = {
	0: Color(0.55, 0.55, 0.55, 1.00),
	1: Color(0.32, 0.62, 0.92, 1.00),
	2: Color(1.00, 0.78, 0.32, 1.00),
	3: Color(0.78, 0.42, 0.92, 1.00),
}

const BUILD_TEXT_COLOR := Color(1.0, 0.96, 0.84, 1.0)
const BUILD_TEXT_OUTLINE := Color(0.03, 0.02, 0.015, 0.95)
const DISABLED_TEXT_COLOR := Color(0.88, 0.82, 0.64, 1.0)
const DRAG_START_DISTANCE := 8.0

@onready var bg_panel: Panel = $BgPanel
@onready var margin: MarginContainer = $Margin
@onready var vbox: VBoxContainer = $Margin/VBox
@onready var name_label: Label = $Margin/VBox/NameLabel
@onready var cost_label: Label = $CostBadge/CostLabel
@onready var cost_badge: Panel = $CostBadge
@onready var progress_bar: ProgressBar = $Margin/VBox/ProgressBar
@onready var strike_rect: ColorRect = $StrikeRect
@onready var highlight_rect: Panel = $HighlightRect
@onready var overlay_rect: ColorRect = $OverlayRect
@onready var stock_badge: Panel = $StockBadge
@onready var stock_label: Label = $StockBadge/StockLabel
@onready var empty_label: Label = $EmptyLabel
@onready var art_rect: ColorRect = $ArtRect
@onready var art_texture: TextureRect = $ArtRect/ArtTexture
@onready var art_placeholder: Label = $ArtRect/ArtPlaceholder
@onready var build_name_label: Label = $BuildNameLabel
@onready var type_bar: Panel = $TypeBar
@onready var type_label: Label = $TypeBar/TypeLabel
@onready var desc_label: Label = $DescLabel
@onready var rarity_frame: Panel = $RarityFrame

## 点击信号（构筑模式用，battle 不发）
##   button_index 见 MOUSE_BUTTON_*
signal pressed(button_index: int)

var mode: int = Mode.BATTLE
var card_data: CardData
var card_runtime: CardRuntime      # 仅 BATTLE 模式使用
var stock_available: int = 0       # 仅 BUILD_DECK_ITEM
var stock_total: int = 0           # 仅 BUILD_DECK_ITEM
var is_empty_slot: bool = false    # 仅 BUILD_SLOT，true 时显示 "+"
var is_compact_build_slot: bool = false
var shows_default_empty_card: bool = false
var _press_button: int = 0
var _press_pos: Vector2 = Vector2.ZERO
var _drag_started: bool = false

func _ready() -> void:
	_bind_nodes()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func _bind_nodes() -> void:
	if bg_panel != null:
		return
	bg_panel = $BgPanel
	margin = $Margin
	vbox = $Margin/VBox
	name_label = $Margin/VBox/NameLabel
	cost_label = $CostBadge/CostLabel
	cost_badge = $CostBadge
	progress_bar = $Margin/VBox/ProgressBar
	strike_rect = $StrikeRect
	highlight_rect = $HighlightRect
	overlay_rect = $OverlayRect
	stock_badge = $StockBadge
	stock_label = $StockBadge/StockLabel
	empty_label = $EmptyLabel
	art_rect = $ArtRect
	art_texture = $ArtRect/ArtTexture
	art_placeholder = $ArtRect/ArtPlaceholder
	build_name_label = $BuildNameLabel
	type_bar = $TypeBar
	type_label = $TypeBar/TypeLabel
	desc_label = $DescLabel
	rarity_frame = $RarityFrame

# ─── BATTLE 模式 ─────────────────────────────────────────────────

func setup(card: CardRuntime, cost: int) -> void:
	_bind_nodes()
	mode = Mode.BATTLE
	card_runtime = card
	card_data = card.data
	is_empty_slot = false
	modulate = Color.WHITE

	var card_name := tr(card.data.display_name_key)
	name_label.show()
	name_label.text = card_name
	cost_label.text = str(cost)

	# 卡牌宽度 = max(BASE_WIDTH, cost * BASE_WIDTH)
	var w := maxi(BASE_WIDTH, cost * BASE_WIDTH)
	custom_minimum_size = Vector2(w, BASE_HEIGHT)

	# 字号自适应：cost=1（80 宽）容纳 2 字 16px；3+ 字时降到 13px
	var name_chars := card_name.length()
	var fsize := 16
	if w <= BASE_WIDTH and name_chars > 2:
		fsize = 13
	elif w <= BASE_WIDTH * 2 and name_chars > 4:
		fsize = 14
	name_label.add_theme_font_size_override("font_size", fsize)

	# BATTLE 用 VBox 居中布局（保持原有视觉）
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	name_label.size_flags_vertical = SIZE_EXPAND_FILL

	# 关闭所有构筑专用元素
	build_name_label.hide()
	art_rect.hide()
	type_bar.hide()
	desc_label.hide()
	rarity_frame.hide()
	stock_badge.hide()
	empty_label.hide()

	progress_bar.show()
	progress_bar.max_value = cost
	progress_bar.value = 0

	cost_badge.show()
	bg_panel.show()
	bg_panel.modulate = Color.WHITE
	strike_rect.hide()
	highlight_rect.hide()
	overlay_rect.hide()

	if card.is_consumed:
		mark_consumed()

# ─── BUILD_SLOT 模式 ────────────────────────────────────────────

## card 可为 null，表示空槽位（显示 "+"）
func setup_build_slot(card: CardData) -> void:
	_setup_build_slot(card, false)

func setup_build_chain_slot(card: CardData) -> void:
	_setup_build_slot(card, true)

func _setup_build_slot(card: CardData, compact: bool) -> void:
	_bind_nodes()
	mode = Mode.BUILD_SLOT
	card_runtime = null
	card_data = card
	is_empty_slot = (card == null)
	is_compact_build_slot = compact
	shows_default_empty_card = is_empty_slot
	stock_available = 0
	stock_total = 0
	modulate = Color.WHITE
	_apply_build_text_contrast()
	_apply_build_geometry()

	# 空槽与非空槽尺寸不同
	if is_empty_slot:
		custom_minimum_size = Vector2(
			BUILD_CHAIN_SLOT_EMPTY_W if compact else BUILD_SLOT_EMPTY_W,
			BUILD_CHAIN_SLOT_EMPTY_H if compact else BUILD_SLOT_EMPTY_H
		)
	else:
		custom_minimum_size = Vector2(
			BUILD_CHAIN_SLOT_WIDTH if compact else BUILD_SLOT_WIDTH,
			BUILD_CHAIN_SLOT_HEIGHT if compact else BUILD_SLOT_HEIGHT
		)

	progress_bar.hide()
	stock_badge.hide()
	strike_rect.hide()
	highlight_rect.hide()
	overlay_rect.hide()

	if is_empty_slot:
		bg_panel.show()
		bg_panel.modulate = Color.WHITE
		cost_badge.show()
		empty_label.hide()
		var fallback := ChainComposer.get_default_strike_card()
		name_label.text = tr(fallback.display_name_key)
		build_name_label.text = name_label.text
		name_label.hide()
		cost_label.text = str(fallback.cost)
		_apply_name_font_for_build()
		build_name_label.show()
		art_rect.show()
		_apply_card_art(fallback)
		type_bar.show()
		_apply_type_bar(fallback)
		desc_label.show()
		desc_label.text = tr(fallback.desc_key)
		_apply_desc_font(desc_label.text)
		rarity_frame.hide()
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	else:
		bg_panel.show()
		bg_panel.modulate = Color.WHITE
		cost_badge.show()
		empty_label.hide()

		# 名称放顶部
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		name_label.size_flags_vertical = SIZE_FILL
		name_label.text = tr(card.display_name_key)
		build_name_label.text = name_label.text
		name_label.hide()
		cost_label.text = str(card.cost)
		_apply_name_font_for_build()
		build_name_label.show()

		# 卡面图区
		art_rect.show()
		_apply_card_art(card)

		# 类型横条
		type_bar.show()
		_apply_type_bar(card)

		# 效果描述
		desc_label.show()
		desc_label.text = tr(card.desc_key)
		_apply_desc_font(desc_label.text)

		# 稀有度边框
		_apply_rarity_frame(card)

	tooltip_text = tr(ChainComposer.get_default_strike_card().desc_key) if card == null else tr(card.desc_key)

# ─── BUILD_DECK_ITEM 模式 ───────────────────────────────────────

func setup_deck_item(card: CardData, available: int, total: int) -> void:
	_bind_nodes()
	mode = Mode.BUILD_DECK_ITEM
	card_runtime = null
	card_data = card
	is_empty_slot = false
	is_compact_build_slot = false
	shows_default_empty_card = false
	stock_available = available
	stock_total = total
	modulate = Color.WHITE
	_apply_build_text_contrast()
	_apply_build_geometry()

	custom_minimum_size = Vector2(BUILD_DECK_WIDTH, BUILD_DECK_HEIGHT)

	bg_panel.show()
	bg_panel.modulate = Color.WHITE
	cost_badge.show()
	empty_label.hide()
	progress_bar.hide()
	strike_rect.hide()
	highlight_rect.hide()

	# 卡牌仓库卡比链条更大，直接显示卡面和描述，方便辨认。
	art_rect.show()
	_apply_card_art(card)
	type_bar.show()
	_apply_type_bar(card)
	desc_label.show()
	desc_label.text = tr(card.desc_key)
	_apply_desc_font(desc_label.text)
	_apply_rarity_frame(card)

	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	name_label.size_flags_vertical = SIZE_FILL
	name_label.text = tr(card.display_name_key)
	build_name_label.text = name_label.text
	name_label.hide()
	cost_label.text = str(card.cost)
	_apply_name_font_for_build()
	build_name_label.show()

	stock_badge.hide()
	stock_label.text = ""

	# 库存耗尽：整体变暗 + 不可拖
	var disabled := (available <= 0)
	if disabled:
		bg_panel.modulate = Color(0.42, 0.40, 0.36, 1)
		name_label.add_theme_color_override(&"font_color", DISABLED_TEXT_COLOR)
		build_name_label.add_theme_color_override(&"font_color", DISABLED_TEXT_COLOR)
		overlay_rect.hide()
	else:
		name_label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		build_name_label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		overlay_rect.hide()
	mouse_default_cursor_shape = (Control.CURSOR_ARROW
		if disabled else Control.CURSOR_POINTING_HAND)

	tooltip_text = tr(card.desc_key)

# ─── 通用状态 ────────────────────────────────────────────────────

func set_active(active: bool) -> void:
	highlight_rect.visible = active

func set_selected(selected: bool) -> void:
	# 选中态：复用 HighlightRect（金色描边）
	highlight_rect.visible = selected

func set_recovering(recovering: bool) -> void:
	if mode != Mode.BATTLE:
		return
	if not card_runtime.is_consumed:
		overlay_rect.visible = recovering

func update_progress(val: int) -> void:
	if mode == Mode.BATTLE:
		progress_bar.value = val

## 平滑（小数）进度。BATTLE 模式下用于 60fps 插值刷新。
func update_progress_smooth(val: float) -> void:
	if mode == Mode.BATTLE:
		progress_bar.value = val

func mark_consumed() -> void:
	strike_rect.show()
	overlay_rect.show()

# ─── BUILD_SLOT 内部辅助 ────────────────────────────────────────

func _apply_card_art(card: CardData) -> void:
	if card.icon != null:
		art_texture.texture = card.icon
		art_texture.show()
		art_placeholder.hide()
		art_rect.color = Color(0, 0, 0, 0)  # 让贴图裸露
	else:
		art_texture.hide()
		art_placeholder.show()
		var t: int = int(card.card_type)
		art_rect.color = TYPE_COLORS.get(t, Color(0.30, 0.25, 0.20, 1))

func _apply_build_geometry() -> void:
	if mode == Mode.BUILD_DECK_ITEM:
		build_name_label.offset_left = 28.0
		build_name_label.offset_top = 8.0
		build_name_label.offset_right = -28.0
		build_name_label.offset_bottom = 46.0
		art_rect.offset_left = 10.0
		art_rect.offset_top = 52.0
		art_rect.offset_right = -10.0
		art_rect.offset_bottom = 126.0
		type_bar.offset_left = 6.0
		type_bar.offset_top = 132.0
		type_bar.offset_right = -6.0
		type_bar.offset_bottom = 152.0
		desc_label.offset_left = 10.0
		desc_label.offset_top = -116.0
		desc_label.offset_right = -10.0
		desc_label.offset_bottom = -10.0
		margin.add_theme_constant_override(&"margin_left", 8)
		margin.add_theme_constant_override(&"margin_top", 8)
		margin.add_theme_constant_override(&"margin_right", 8)
		margin.add_theme_constant_override(&"margin_bottom", BUILD_DECK_HEIGHT - 38)
	elif mode == Mode.BUILD_SLOT:
		build_name_label.offset_left = 28.0
		build_name_label.offset_top = 8.0
		build_name_label.offset_right = -28.0
		build_name_label.offset_bottom = 46.0
		art_rect.offset_left = 8.0
		art_rect.offset_top = 52.0
		art_rect.offset_right = -8.0
		art_rect.offset_bottom = 126.0
		type_bar.offset_left = 6.0
		type_bar.offset_top = 132.0
		type_bar.offset_right = -6.0
		type_bar.offset_bottom = 152.0
		desc_label.offset_left = 10.0
		desc_label.offset_top = -116.0
		desc_label.offset_right = -10.0
		desc_label.offset_bottom = -10.0
		margin.add_theme_constant_override(&"margin_left", 7)
		margin.add_theme_constant_override(&"margin_top", 8)
		margin.add_theme_constant_override(&"margin_right", 7)
		margin.add_theme_constant_override(&"margin_bottom",
			(BUILD_CHAIN_SLOT_HEIGHT if is_compact_build_slot else BUILD_SLOT_HEIGHT) - 38)

func _apply_type_bar(card: CardData) -> void:
	var t: int = int(card.card_type)
	# 给 TypeBar 一个 stylebox 并按 type 上色（避免污染共享资源）
	var sb := StyleBoxFlat.new()
	sb.bg_color = TYPE_BAR_COLORS.get(t, Color(0.25, 0.25, 0.30, 0.9))
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	type_bar.add_theme_stylebox_override("panel", sb)
	type_bar.modulate = Color.WHITE

	type_label.text = tr(TYPE_LABEL_KEYS.get(t, "card.type.special"))

func _apply_rarity_frame(card: CardData) -> void:
	var r: int = int(card.rarity)
	var color: Color = RARITY_BORDER_COLORS.get(r, Color(0, 0, 0, 0))
	if color.a <= 0.0:
		rarity_frame.hide()
		return
	rarity_frame.show()
	# 复制基础 stylebox 后修改边框色，避免污染共享资源
	var src := rarity_frame.get_theme_stylebox("panel") as StyleBoxFlat
	if src == null:
		return
	var sb: StyleBoxFlat = src.duplicate() as StyleBoxFlat
	sb.border_color = color
	rarity_frame.add_theme_stylebox_override("panel", sb)

func _apply_desc_font(_text: String) -> void:
	var fsize := 14
	if mode == Mode.BUILD_SLOT and not is_compact_build_slot:
		fsize = 13
	desc_label.add_theme_font_size_override("font_size", fsize)

# ─── 通用名称字号 ───────────────────────────────────────────────

func _apply_name_font_for_build() -> void:
	var name_chars := name_label.text.length()
	var fsize := 18
	if mode == Mode.BUILD_SLOT and not is_empty_slot:
		# 链上大卡名字可以稍大
		if is_compact_build_slot:
			if name_chars <= 4:
				fsize = 15
			elif name_chars <= 6:
				fsize = 13
			else:
				fsize = 12
		elif name_chars <= 4:
			fsize = 18
		elif name_chars <= 6:
			fsize = 16
		else:
			fsize = 14
	else:
		# 卡牌仓库卡更大，名字也相应放大。
		fsize = 20
		if name_chars > 6:
			fsize = 16
		elif name_chars > 4:
			fsize = 18
	name_label.add_theme_font_size_override("font_size", fsize)
	build_name_label.add_theme_font_size_override("font_size", fsize)

func _on_mouse_entered() -> void:
	if mode == Mode.BATTLE:
		# 详情 tooltip 由父级 TimelineScrollView 通过信号接管
		# 此处仅做轻量视觉反馈
		if not highlight_rect.visible:
			bg_panel.modulate = Color(1.15, 1.12, 1.05, 1)
	else:
		# 构筑模式：库存耗尽不响应 hover 高亮
		var disabled := (mode == Mode.BUILD_DECK_ITEM and stock_available <= 0)
		if not disabled and not highlight_rect.visible:
			bg_panel.modulate = Color(1.15, 1.12, 1.05, 1)

func _on_mouse_exited() -> void:
	if mode == Mode.BUILD_DECK_ITEM and stock_available <= 0:
		bg_panel.modulate = Color(0.42, 0.40, 0.36, 1)
	elif mode == Mode.BUILD_SLOT and is_empty_slot:
		bg_panel.modulate = Color.WHITE
	else:
		bg_panel.modulate = Color.WHITE

func _apply_build_text_contrast() -> void:
	for label in [name_label, build_name_label, desc_label, type_label, art_placeholder, stock_label]:
		label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		label.add_theme_color_override(&"font_outline_color", BUILD_TEXT_OUTLINE)
		label.add_theme_constant_override(&"outline_size", 4)

func _on_gui_input(event: InputEvent) -> void:
	if mode == Mode.BATTLE:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_RIGHT:
			return
		if mb.pressed:
			_press_button = mb.button_index
			_press_pos = mb.position
			_drag_started = false
			accept_event()
			return
		if _press_button == mb.button_index:
			if not _drag_started:
				pressed.emit(mb.button_index)
			_press_button = 0
			_drag_started = false
			accept_event()
			return
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _press_button != MOUSE_BUTTON_LEFT or _drag_started:
			return
		if _press_pos.distance_to(motion.position) < DRAG_START_DISTANCE:
			return
		var payload: Variant = _make_drag_payload()
		if payload == null:
			return
		_drag_started = true
		force_drag(payload, _make_drag_preview())
		accept_event()

# ─── 拖拽 ────────────────────────────────────────────────────────

## 拖拽载荷：
##   { "source": "deck_item" | "slot", "card": CardData, "slot_index": int (仅 slot) }

func _get_drag_data(_at_position: Vector2) -> Variant:
	var payload: Variant = _make_drag_payload()
	if payload != null:
		set_drag_preview(_make_drag_preview())
	return payload

func _make_drag_payload() -> Variant:
	if mode == Mode.BATTLE:
		return null
	if is_empty_slot:
		return null
	if mode == Mode.BUILD_DECK_ITEM and stock_available <= 0:
		return null

	var payload: Dictionary = {"card": card_data}
	if mode == Mode.BUILD_DECK_ITEM:
		payload["source"] = "deck_item"
	else:
		payload["source"] = "slot"
		payload["slot_index"] = int(get_meta(&"slot_index", -1))

	return payload

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	var source := String(data.get("source", ""))
	if mode == Mode.BUILD_SLOT:
		return data.has("card") and data.has("source")
	if mode == Mode.BUILD_DECK_ITEM:
		return source == "slot" and int(data.get("slot_index", -1)) >= 0
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# 实际处理在 BuildScene 里通过 meta 持有的回调完成，避免组件直接依赖场景
	# meta &"on_drop" = Callable(target_slot_index: int, payload: Dictionary)
	var on_drop: Callable = get_meta(&"on_drop", Callable())
	if on_drop.is_valid():
		if mode == Mode.BUILD_SLOT:
			var slot_index: int = int(get_meta(&"slot_index", -1))
			on_drop.call(slot_index, data)
		elif mode == Mode.BUILD_DECK_ITEM:
			on_drop.call(data)

## 拖拽预览：实例化新的 CardView 并按当前模式 setup（自动获得对应尺寸 / 布局）
func _make_drag_preview() -> Control:
	var scn: PackedScene = load("res://scenes/components/card_view.tscn")
	var preview: CardView = scn.instantiate()
	preview.modulate = Color(1, 1, 1, 0.85)

	# set_drag_preview 把 preview 加到 viewport 后才会触发 _ready 中的 @onready 绑定
	# 因此 setup 必须延迟到 _ready 完成后
	if mode == Mode.BUILD_DECK_ITEM:
		preview.call_deferred("setup_deck_item", card_data, stock_available, stock_total)
	elif mode == Mode.BUILD_SLOT and not is_empty_slot:
		preview.call_deferred("setup_build_chain_slot", card_data)

	return preview
