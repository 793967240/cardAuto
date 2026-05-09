class_name CardView extends Control

## 通用卡牌组件。支持三种显示模式：
##   - BATTLE：战斗时间线（按 cost 拉宽，显示进度条 / 高光 / 划线 / 恢复遮罩）
##   - BUILD_SLOT：构筑界面 6 个链条槽位
##       * 空槽：120×140，显示 "+"
##       * 非空：140×200，杀戮尖塔风格大卡
##         上=名称，中=卡面图（ArtRect/ArtTexture），下=类型横条+效果描述
##         边框颜色随 rarity 变化
##   - BUILD_DECK_ITEM：构筑界面卡组侧栏（固定 120×140，右下角库存角标 ×N/M）
##
## 拖拽：BUILD_SLOT(非空) / BUILD_DECK_ITEM 模式参与拖拽；BATTLE 不参与。
## 拖拽预览：与拖拽源同尺寸同布局（侧栏 → 120×140，链上 → 140×200）

enum Mode { BATTLE, BUILD_SLOT, BUILD_DECK_ITEM }

const BASE_WIDTH := 80
const BASE_HEIGHT := 120
const BUILD_DECK_WIDTH := 120
const BUILD_DECK_HEIGHT := 140
const BUILD_SLOT_WIDTH := 140
const BUILD_SLOT_HEIGHT := 200
const BUILD_SLOT_EMPTY_W := 120
const BUILD_SLOT_EMPTY_H := 140

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

## 稀有度 → 边框颜色（普通=不显示、稀有=蓝、史诗=金、传奇=紫）
const RARITY_BORDER_COLORS: Dictionary = {
	0: Color(0, 0, 0, 0),
	1: Color(0.32, 0.62, 0.92, 1.00),
	2: Color(1.00, 0.78, 0.32, 1.00),
	3: Color(0.78, 0.42, 0.92, 1.00),
}

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

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

# ─── BATTLE 模式 ─────────────────────────────────────────────────

func setup(card: CardRuntime, cost: int) -> void:
	mode = Mode.BATTLE
	card_runtime = card
	card_data = card.data
	is_empty_slot = false

	var card_name := tr(card.data.display_name_key)
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
	mode = Mode.BUILD_SLOT
	card_runtime = null
	card_data = card
	is_empty_slot = (card == null)
	stock_available = 0
	stock_total = 0

	# 空槽与非空槽尺寸不同
	if is_empty_slot:
		custom_minimum_size = Vector2(BUILD_SLOT_EMPTY_W, BUILD_SLOT_EMPTY_H)
	else:
		custom_minimum_size = Vector2(BUILD_SLOT_WIDTH, BUILD_SLOT_HEIGHT)

	progress_bar.hide()
	stock_badge.hide()
	strike_rect.hide()
	highlight_rect.hide()
	overlay_rect.hide()

	if is_empty_slot:
		# 空槽：背景半透明 + "+" 居中
		bg_panel.show()
		bg_panel.modulate = Color(1, 1, 1, 0.35)
		cost_badge.hide()
		name_label.text = ""
		empty_label.show()
		art_rect.hide()
		type_bar.hide()
		desc_label.hide()
		rarity_frame.hide()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		bg_panel.show()
		bg_panel.modulate = Color.WHITE
		cost_badge.show()
		empty_label.hide()

		# 名称放顶部
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
		name_label.size_flags_vertical = SIZE_FILL
		name_label.text = tr(card.display_name_key)
		cost_label.text = str(card.cost)
		_apply_name_font_for_build()

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

	tooltip_text = "" if card == null else tr(card.desc_key)

# ─── BUILD_DECK_ITEM 模式 ───────────────────────────────────────

func setup_deck_item(card: CardData, available: int, total: int) -> void:
	mode = Mode.BUILD_DECK_ITEM
	card_runtime = null
	card_data = card
	is_empty_slot = false
	stock_available = available
	stock_total = total

	custom_minimum_size = Vector2(BUILD_DECK_WIDTH, BUILD_DECK_HEIGHT)

	bg_panel.show()
	bg_panel.modulate = Color.WHITE
	cost_badge.show()
	empty_label.hide()
	progress_bar.hide()
	strike_rect.hide()
	highlight_rect.hide()

	# 不展开效果，紧凑显示
	art_rect.hide()
	type_bar.hide()
	desc_label.hide()
	rarity_frame.hide()

	# 名称居中（紧凑卡的原有形态）
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	name_label.size_flags_vertical = SIZE_EXPAND_FILL
	name_label.text = tr(card.display_name_key)
	cost_label.text = str(card.cost)
	_apply_name_font_for_build()

	stock_badge.show()
	stock_label.text = "×%d/%d" % [available, total]

	# 库存耗尽：整体变暗 + 不可拖
	var disabled := (available <= 0)
	if disabled:
		bg_panel.modulate = Color(0.5, 0.5, 0.5, 1)
		overlay_rect.show()
	else:
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
		# COMMON 不显示边框
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

func _apply_desc_font(text: String) -> void:
	# 描述文字：默认 12px，过长降到 11/10
	var fsize := 12
	if text.length() > 24:
		fsize = 11
	if text.length() > 40:
		fsize = 10
	desc_label.add_theme_font_size_override("font_size", fsize)

# ─── 通用名称字号 ───────────────────────────────────────────────

func _apply_name_font_for_build() -> void:
	var name_chars := name_label.text.length()
	var fsize := 18
	if mode == Mode.BUILD_SLOT and not is_empty_slot:
		# 链上大卡名字可以稍大
		if name_chars <= 4:
			fsize = 18
		elif name_chars <= 6:
			fsize = 16
		else:
			fsize = 14
	else:
		# 侧栏小卡
		if name_chars > 4:
			fsize = 14
		elif name_chars > 3:
			fsize = 16
	name_label.add_theme_font_size_override("font_size", fsize)

func _on_mouse_entered() -> void:
	if mode == Mode.BATTLE:
		# 详情 tooltip 由父级 TimelineScrollView 通过信号接管
		# 此处仅做轻量视觉反馈
		if not highlight_rect.visible:
			bg_panel.modulate = Color(1.15, 1.12, 1.05, 1)
	else:
		# 构筑模式：库存耗尽不响应 hover 高亮
		var disabled := (mode == Mode.BUILD_DECK_ITEM and stock_available <= 0)
		if not disabled and not highlight_rect.visible and not is_empty_slot:
			bg_panel.modulate = Color(1.15, 1.12, 1.05, 1)

func _on_mouse_exited() -> void:
	if mode == Mode.BUILD_DECK_ITEM and stock_available <= 0:
		bg_panel.modulate = Color(0.5, 0.5, 0.5, 1)
	elif mode == Mode.BUILD_SLOT and is_empty_slot:
		bg_panel.modulate = Color(1, 1, 1, 0.35)
	else:
		bg_panel.modulate = Color.WHITE

func _on_gui_input(event: InputEvent) -> void:
	if mode == Mode.BATTLE:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed:
		pressed.emit(mb.button_index)

# ─── 拖拽 ────────────────────────────────────────────────────────

## 拖拽载荷：
##   { "source": "deck_item" | "slot", "card": CardData, "slot_index": int (仅 slot) }

func _get_drag_data(_at_position: Vector2) -> Variant:
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

	# 拖拽预览：与拖拽源同尺寸同布局
	var preview := _make_drag_preview()
	set_drag_preview(preview)
	return payload

## 仅 BUILD_SLOT 接收拖入。BUILD_DECK_ITEM 不作为投放目标（卡组列表只读）。
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if mode != Mode.BUILD_SLOT:
		return false
	if not (data is Dictionary):
		return false
	return data.has("card") and data.has("source")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	# 实际处理在 BuildScene 里通过 meta 持有的回调完成，避免组件直接依赖场景
	# meta &"on_drop" = Callable(target_slot_index: int, payload: Dictionary)
	var on_drop: Callable = get_meta(&"on_drop", Callable())
	if on_drop.is_valid():
		var slot_index: int = int(get_meta(&"slot_index", -1))
		on_drop.call(slot_index, data)

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
		preview.call_deferred("setup_build_slot", card_data)

	return preview
