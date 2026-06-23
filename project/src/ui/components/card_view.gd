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
## 拖拽预览：与拖拽源同尺寸同布局（卡牌仓库 → 220×330，链上 → 220×364）

enum Mode { BATTLE, BUILD_SLOT, BUILD_DECK_ITEM }

const BASE_WIDTH := 80
const BASE_HEIGHT := 120
const BUILD_DECK_WIDTH := 220
const BUILD_DECK_HEIGHT := 330
const BUILD_SLOT_WIDTH := 206
const BUILD_SLOT_HEIGHT := 350
const BUILD_SLOT_EMPTY_W := BUILD_SLOT_WIDTH
const BUILD_SLOT_EMPTY_H := BUILD_SLOT_HEIGHT
const BUILD_CHAIN_SLOT_WIDTH := 220
const BUILD_CHAIN_SLOT_HEIGHT := 364
const BUILD_CHAIN_SLOT_EMPTY_W := BUILD_CHAIN_SLOT_WIDTH
const BUILD_CHAIN_SLOT_EMPTY_H := BUILD_CHAIN_SLOT_HEIGHT
const DEFAULT_TYPE_ART: Dictionary = {
	0: preload("res://assets/ui/cards/type_art/card_type_attack.png"),
	1: preload("res://assets/ui/cards/type_art/card_type_defense.png"),
	2: preload("res://assets/ui/cards/type_art/card_type_buff.png"),
	3: preload("res://assets/ui/cards/type_art/card_type_control.png"),
	4: preload("res://assets/ui/cards/type_art/card_type_summon.png"),
	5: preload("res://assets/ui/cards/type_art/card_type_special.png"),
}

## 类型 → 卡面占位色（无 icon 时）
const TYPE_COLORS: Dictionary = {
	0: Color(0.48, 0.15, 0.12, 1),  # ATTACK 朱砂
	1: Color(0.18, 0.30, 0.42, 1),  # DEFENSE 青黛
	2: Color(0.20, 0.38, 0.28, 1),  # BUFF 松绿
	3: Color(0.34, 0.24, 0.42, 1),  # CONTROL 暮紫
	4: Color(0.52, 0.40, 0.16, 1),  # SUMMON 金墨
	5: Color(0.30, 0.28, 0.24, 1),  # SPECIAL 淡墨
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
	0: Color(0.40, 0.10, 0.08, 0.95),
	1: Color(0.12, 0.22, 0.36, 0.95),
	2: Color(0.12, 0.30, 0.20, 0.95),
	3: Color(0.26, 0.15, 0.34, 0.95),
	4: Color(0.40, 0.30, 0.10, 0.95),
	5: Color(0.20, 0.19, 0.17, 0.95),
}

const BUILD_TEXT_COLOR := Color(0.03, 0.035, 0.032, 1.0)
const BUILD_TEXT_OUTLINE := Color(0.96, 0.98, 0.94, 0.72)
const DISABLED_TEXT_COLOR := Color(0.23, 0.24, 0.22, 1.0)
const BUILD_TYPE_COLORS := {
	0: Color(0.58, 0.34, 0.30, 1.0),
	1: Color(0.34, 0.48, 0.58, 1.0),
	2: Color(0.36, 0.58, 0.50, 1.0),
	3: Color(0.46, 0.40, 0.56, 1.0),
	4: Color(0.58, 0.50, 0.34, 1.0),
	5: Color(0.50, 0.52, 0.46, 1.0),
}
const BUILD_TEXT_COLOR_SOFT := BUILD_TEXT_COLOR
const BUILD_TEXT_OUTLINE_SOFT := BUILD_TEXT_OUTLINE
const DRAG_START_DISTANCE := 8.0
const DECK_COST_BADGE_SIZE := Vector2(87, 55)
const DECK_COST_BADGE_TOP_RIGHT := Vector2(-5, 29)
const BUILD_SLOT_COST_BADGE_SIZE := Vector2(83, 77)
const BUILD_SLOT_COST_BADGE_TOP_RIGHT := Vector2(-5, 29)
const BUILD_DESC_DOWN_OFFSET := 40.0
const KEYWORD_DEFS: Array[Dictionary] = [
	{"id": "innate", "color": "#b92525", "terms": ["固有", "Innate"], "name_key": "card.keyword.innate.name", "desc_key": "card.keyword.innate.desc"},
	{"id": "flow", "color": "#8a45bd", "terms": ["流转", "Flow"], "name_key": "card.keyword.flow.name", "desc_key": "card.keyword.flow.desc"},
	{"id": "vulnerable", "color": "#d33636", "terms": ["易伤", "Vulnerable"], "name_key": "card.keyword.vulnerable.name", "desc_key": "card.keyword.vulnerable.desc"},
	{"id": "slow", "color": "#2a70bd", "terms": ["迟滞", "Slow", "Slowed"], "name_key": "card.keyword.slow.name", "desc_key": "card.keyword.slow.desc"},
	{"id": "burn", "color": "#c44a1d", "terms": ["燃烧", "Burn"], "name_key": "card.keyword.burn.name", "desc_key": "card.keyword.burn.desc"},
	{"id": "haste", "color": "#0f8a7a", "terms": ["加速", "Haste"], "name_key": "card.keyword.haste.name", "desc_key": "card.keyword.haste.desc"},
	{"id": "strength", "color": "#b85518", "terms": ["力量", "Strength"], "name_key": "card.keyword.strength.name", "desc_key": "card.keyword.strength.desc"},
	{"id": "shield", "color": "#267c9e", "terms": ["护盾", "Shield"], "name_key": "card.keyword.shield.name", "desc_key": "card.keyword.shield.desc"},
	{"id": "charge", "color": "#8061c9", "terms": ["充能", "Charge", "Charge-consume"], "name_key": "card.keyword.charge.name", "desc_key": "card.keyword.charge.desc"},
	{"id": "consumable", "color": "#8f3f2d", "terms": ["一次性", "Consumable"], "name_key": "card.keyword.consumable.name", "desc_key": "card.keyword.consumable.desc"},
	{"id": "interrupt", "color": "#a02f78", "terms": ["打断", "Interrupt", "interrupt"], "name_key": "card.keyword.interrupt.name", "desc_key": "card.keyword.interrupt.desc"},
]

@onready var bg_panel: Panel = $BgPanel
@onready var frame_texture: TextureRect = $FrameTexture
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
@onready var desc_label: RichTextLabel = $DescLabel
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
		_apply_layer_order()
		return
	bg_panel = $BgPanel
	frame_texture = $FrameTexture
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
	_apply_layer_order()

func _apply_layer_order() -> void:
	art_rect.z_index = 1
	frame_texture.z_index = 5
	build_name_label.z_index = 8
	type_bar.z_index = 8
	desc_label.z_index = 8
	cost_badge.z_index = 8
	highlight_rect.z_index = 10
	overlay_rect.z_index = 11
	strike_rect.z_index = 12

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
	frame_texture.hide()
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
	_apply_cost_badge_chrome(false)
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
	_apply_cost_badge_chrome(true)

	if is_empty_slot:
		bg_panel.show()
		frame_texture.show()
		bg_panel.modulate = Color(1, 1, 1, 0)
		cost_badge.show()
		empty_label.hide()
		var fallback := ChainComposer.get_default_strike_card()
		name_label.text = tr(fallback.display_name_key)
		build_name_label.text = name_label.text
		name_label.hide()
		cost_label.text = str(fallback.cost)
		_apply_name_font_for_build()
		build_name_label.show()
		_apply_card_frame(fallback)
		art_rect.show()
		_apply_card_art(fallback)
		type_bar.show()
		_apply_type_bar(fallback)
		desc_label.show()
		_set_card_description(fallback)
		_apply_desc_font(desc_label.text)
		rarity_frame.hide()
		vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	else:
		bg_panel.show()
		frame_texture.show()
		bg_panel.modulate = Color(1, 1, 1, 0)
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
		_apply_card_frame(card)

		# 卡面图区
		art_rect.show()
		_apply_card_art(card)

		# 类型横条
		type_bar.show()
		_apply_type_bar(card)

		# 效果描述
		desc_label.show()
		_set_card_description(card)
		_apply_desc_font(desc_label.text)

		# 稀有度边框
		_apply_rarity_frame(card)

	tooltip_text = _keyword_tooltip_for_card(ChainComposer.get_default_strike_card() if card == null else card)

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
	frame_texture.show()
	bg_panel.modulate = Color(1, 1, 1, 0)
	cost_badge.show()
	_apply_cost_badge_chrome(true)
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
	_set_card_description(card)
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
	_apply_card_frame(card)

	stock_badge.hide()
	stock_label.text = ""

	# 库存耗尽：整体变暗 + 不可拖
	var disabled := (available <= 0)
	if disabled:
		frame_texture.modulate = Color(0.42, 0.40, 0.36, 1)
		name_label.add_theme_color_override(&"font_color", DISABLED_TEXT_COLOR)
		build_name_label.add_theme_color_override(&"font_color", DISABLED_TEXT_COLOR)
		overlay_rect.hide()
	else:
		frame_texture.modulate = Color.WHITE
		name_label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		build_name_label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		overlay_rect.hide()
	mouse_default_cursor_shape = (Control.CURSOR_ARROW
		if disabled else Control.CURSOR_POINTING_HAND)

	tooltip_text = _keyword_tooltip_for_card(card)

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
		var t: int = int(card.card_type)
		var default_art := DEFAULT_TYPE_ART.get(t) as Texture2D
		if default_art != null:
			art_texture.texture = default_art
			art_texture.show()
			art_placeholder.hide()
			art_rect.color = Color(0, 0, 0, 0)
		else:
			art_texture.hide()
			art_placeholder.show()
			if mode == Mode.BUILD_SLOT or mode == Mode.BUILD_DECK_ITEM:
				art_rect.color = BUILD_TYPE_COLORS.get(t, Color(0.50, 0.52, 0.46, 1.0))
			else:
				art_rect.color = TYPE_COLORS.get(t, Color(0.30, 0.25, 0.20, 1))

func _apply_card_frame(card: CardData) -> void:
	if frame_texture.has_method("setup_for_rarity"):
		frame_texture.call("setup_for_rarity", 0)

func _apply_cost_badge_chrome(build_mode: bool) -> void:
	if build_mode:
		cost_badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		cost_badge.anchor_left = 1.0
		cost_badge.anchor_right = 1.0
		cost_badge.anchor_top = 0.0
		cost_badge.anchor_bottom = 0.0
		var badge_size := DECK_COST_BADGE_SIZE if mode == Mode.BUILD_DECK_ITEM else BUILD_SLOT_COST_BADGE_SIZE
		var top_right := DECK_COST_BADGE_TOP_RIGHT if mode == Mode.BUILD_DECK_ITEM else BUILD_SLOT_COST_BADGE_TOP_RIGHT
		cost_badge.offset_right = top_right.x
		cost_badge.offset_top = top_right.y
		cost_badge.offset_left = cost_badge.offset_right - badge_size.x
		cost_badge.offset_bottom = cost_badge.offset_top + badge_size.y
		cost_label.add_theme_font_size_override("font_size", 15)
		cost_label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
		cost_label.add_theme_color_override(&"font_outline_color", BUILD_TEXT_OUTLINE)
		cost_label.add_theme_constant_override(&"outline_size", 2)
	else:
		cost_badge.remove_theme_stylebox_override("panel")
		cost_badge.anchor_left = 1.0
		cost_badge.anchor_right = 1.0
		cost_badge.anchor_top = 0.0
		cost_badge.anchor_bottom = 0.0
		cost_badge.offset_left = -22.0
		cost_badge.offset_top = -2.0
		cost_badge.offset_right = 2.0
		cost_badge.offset_bottom = 22.0
		cost_label.add_theme_font_size_override("font_size", 16)
		cost_label.add_theme_color_override(&"font_color", Color(0.12, 0.08, 0.04, 1.0))
		cost_label.remove_theme_color_override(&"font_outline_color")
		cost_label.remove_theme_constant_override(&"outline_size")

func _apply_build_geometry() -> void:
	if mode == Mode.BUILD_DECK_ITEM:
		build_name_label.offset_left = 60.0
		build_name_label.offset_top = 29.0
		build_name_label.offset_right = -62.0
		build_name_label.offset_bottom = 84.0
		art_rect.offset_left = 34.0
		art_rect.offset_top = 58.0
		art_rect.offset_right = -34.0
		art_rect.offset_bottom = 190.0
		type_bar.offset_left = 62.0
		type_bar.offset_top = 181.0
		type_bar.offset_right = -62.0
		type_bar.offset_bottom = 209.0
		desc_label.offset_left = 45.0
		desc_label.offset_top = -156.0 + BUILD_DESC_DOWN_OFFSET
		desc_label.offset_right = -45.0
		desc_label.offset_bottom = -28.0 + BUILD_DESC_DOWN_OFFSET
		margin.add_theme_constant_override(&"margin_left", 8)
		margin.add_theme_constant_override(&"margin_top", 8)
		margin.add_theme_constant_override(&"margin_right", 8)
		margin.add_theme_constant_override(&"margin_bottom", BUILD_DECK_HEIGHT - 38)
	elif mode == Mode.BUILD_SLOT:
		build_name_label.offset_left = 60.0
		build_name_label.offset_top = 43.0
		build_name_label.offset_right = -61.0
		build_name_label.offset_bottom = 92.0
		art_rect.offset_left = 31.0
		art_rect.offset_top = 64.0
		art_rect.offset_right = -31.0
		art_rect.offset_bottom = 208.0
		type_bar.offset_left = 60.0
		type_bar.offset_top = 198.0
		type_bar.offset_right = -60.0
		type_bar.offset_bottom = 229.0
		desc_label.offset_left = 45.0
		desc_label.offset_top = -178.0 + BUILD_DESC_DOWN_OFFSET
		desc_label.offset_right = -45.0
		desc_label.offset_bottom = -31.0 + BUILD_DESC_DOWN_OFFSET
		margin.add_theme_constant_override(&"margin_left", 7)
		margin.add_theme_constant_override(&"margin_top", 8)
		margin.add_theme_constant_override(&"margin_right", 7)
		margin.add_theme_constant_override(&"margin_bottom",
			(BUILD_CHAIN_SLOT_HEIGHT if is_compact_build_slot else BUILD_SLOT_HEIGHT) - 38)

func _apply_type_bar(card: CardData) -> void:
	var t: int = int(card.card_type)
	type_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	type_bar.modulate = Color.WHITE

	type_label.text = tr(TYPE_LABEL_KEYS.get(t, "card.type.special"))

func _apply_rarity_frame(card: CardData) -> void:
	rarity_frame.hide()

func _apply_desc_font(_text: String) -> void:
	var fsize := 12
	if mode == Mode.BUILD_SLOT and not is_compact_build_slot:
		fsize = 11
	desc_label.add_theme_font_size_override("font_size", fsize)

func _set_card_description(card: CardData) -> void:
	var raw := tr(card.desc_key)
	desc_label.text = _colorize_keywords(raw)

static func _colorize_keywords(raw: String) -> String:
	var out := ""
	var i := 0
	while i < raw.length():
		var match_term := ""
		var match_color := ""
		for def in KEYWORD_DEFS:
			for term in def.get("terms", []):
				var term_text := str(term)
				if term_text == "":
					continue
				if raw.substr(i, term_text.length()) == term_text and term_text.length() > match_term.length():
					match_term = term_text
					match_color = str(def.get("color", "#b92525"))
		if match_term != "":
			out += "[color=%s]%s[/color]" % [match_color, _bbcode_escape(match_term)]
			i += match_term.length()
		else:
			out += _bbcode_escape(raw.substr(i, 1))
			i += 1
	return out

static func _keyword_tooltip_for_card(card: CardData) -> String:
	if card == null:
		return ""
	var desc := _translate(card.desc_key)
	var lines: Array[String] = []
	var seen: Dictionary = {}
	for def in KEYWORD_DEFS:
		var keyword_id := str(def.get("id", ""))
		if seen.has(keyword_id):
			continue
		if _description_has_keyword(desc, def):
			seen[keyword_id] = true
			lines.append("%s：%s" % [_translate(str(def.get("name_key", ""))), _translate(str(def.get("desc_key", "")))])
	return "\n".join(lines)

static func _description_has_keyword(desc: String, def: Dictionary) -> bool:
	for term in def.get("terms", []):
		if desc.contains(str(term)):
			return true
	return false

static func _bbcode_escape(text: String) -> String:
	return text.replace("[", "[lb]").replace("]", "[rb]")

static func keyword_tooltip_for(card: CardData) -> String:
	return _keyword_tooltip_for_card(card)

static func _translate(key: String) -> String:
	return TranslationServer.translate(key)

# ─── 通用名称字号 ───────────────────────────────────────────────

func _apply_name_font_for_build() -> void:
	var name_chars := name_label.text.length()
	var fsize := 18
	if mode == Mode.BUILD_SLOT and not is_empty_slot:
		# 链上大卡名字可以稍大
		if is_compact_build_slot:
			if name_chars <= 4:
				fsize = 13
			elif name_chars <= 6:
				fsize = 12
			else:
				fsize = 11
		elif name_chars <= 4:
			fsize = 15
		elif name_chars <= 6:
			fsize = 14
		else:
			fsize = 12
	else:
		# 卡牌仓库卡更大，名字也相应放大。
		fsize = 16
		if name_chars > 6:
			fsize = 13
		elif name_chars > 4:
			fsize = 15
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
			frame_texture.modulate = Color(1.08, 1.06, 1.02, 1)

func _on_mouse_exited() -> void:
	if mode == Mode.BUILD_DECK_ITEM and stock_available <= 0:
		frame_texture.modulate = Color(0.42, 0.40, 0.36, 1)
	elif mode == Mode.BUILD_SLOT and is_empty_slot:
		frame_texture.modulate = Color.WHITE
	else:
		bg_panel.modulate = Color.WHITE if mode == Mode.BATTLE else Color(1, 1, 1, 0)
		frame_texture.modulate = Color.WHITE

func _apply_build_text_contrast() -> void:
	for label in [name_label, build_name_label, type_label, art_placeholder, stock_label]:
		if mode == Mode.BUILD_SLOT:
			label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR_SOFT)
			label.add_theme_color_override(&"font_outline_color", BUILD_TEXT_OUTLINE_SOFT)
			label.add_theme_constant_override(&"outline_size", 2)
		else:
			label.add_theme_color_override(&"font_color", BUILD_TEXT_COLOR)
			label.add_theme_color_override(&"font_outline_color", BUILD_TEXT_OUTLINE)
			label.add_theme_constant_override(&"outline_size", 4)
	desc_label.add_theme_color_override(&"default_color", BUILD_TEXT_COLOR_SOFT if mode == Mode.BUILD_SLOT else BUILD_TEXT_COLOR)

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
