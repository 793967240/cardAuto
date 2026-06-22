class_name RelicBar extends PanelContainer

const PLACEHOLDER_ICON := preload("res://assets/ui/relics/relic_placeholder.png")
const TOOLTIP_STYLE_PATH := "res://assets/ui/themes/xianxia/tooltips/tooltip_frame_xianxia.tres"

@export var compact: bool = false
@export var show_title: bool = true
@export var empty_text_key: String = "relic.ui.empty"

var _content: BoxContainer


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_theme_stylebox_override(&"panel", _make_panel_style())
	_build_shell()
	if not EventBus.language_changed.is_connected(_on_language_changed):
		EventBus.language_changed.connect(_on_language_changed)
	refresh()


func refresh() -> void:
	if _content == null:
		return
	for child in _content.get_children():
		child.queue_free()

	var run := GameState.current_run
	if run == null or run.relics.is_empty():
		_content.add_child(_make_empty_label())
		return

	for relic in run.relics:
		if relic is RelicData:
			_content.add_child(_make_relic_button(relic as RelicData))


func _on_language_changed(_language: String) -> void:
	refresh()


func _build_shell() -> void:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override(&"margin_left", 8 if compact else 10)
	margin.add_theme_constant_override(&"margin_top", 5 if compact else 8)
	margin.add_theme_constant_override(&"margin_right", 8 if compact else 10)
	margin.add_theme_constant_override(&"margin_bottom", 5 if compact else 8)
	add_child(margin)

	var root: BoxContainer
	if compact:
		root = HBoxContainer.new()
	else:
		root = VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_theme_constant_override(&"separation", 7)
	margin.add_child(root)

	if show_title:
		var title := Label.new()
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.text = tr("relic.ui.title")
		title.add_theme_font_size_override(&"font_size", 14 if compact else 18)
		title.add_theme_color_override(&"font_color", Color(0.95, 0.82, 0.52, 1.0) if compact else Color(0.24, 0.16, 0.08, 0.96))
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		root.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(128, 44) if compact else Vector2(0, 56)
	scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.size_flags_vertical = SIZE_SHRINK_CENTER
	root.add_child(scroll)

	_content = HBoxContainer.new()
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_content)


func _make_relic_button(relic: RelicData) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.icon = relic.icon if relic.icon != null else PLACEHOLDER_ICON
	btn.expand_icon = true
	btn.custom_minimum_size = Vector2(42, 42) if compact else Vector2(48, 48)
	btn.tooltip_text = "%s\n%s" % [tr(relic.get_name_key()), tr(relic.get_desc_key())]
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override(&"normal", _make_icon_style(Color(0.16, 0.12, 0.08, 0.92), Color(0.70, 0.52, 0.24, 0.90)))
	btn.add_theme_stylebox_override(&"hover", _make_icon_style(Color(0.22, 0.16, 0.09, 0.98), Color(1.0, 0.78, 0.35, 1.0)))
	btn.add_theme_stylebox_override(&"pressed", _make_icon_style(Color(0.10, 0.08, 0.06, 1.0), Color(0.95, 0.66, 0.22, 1.0)))
	return btn


func _make_empty_label() -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = tr(empty_text_key)
	label.add_theme_font_size_override(&"font_size", 13 if compact else 14)
	label.add_theme_color_override(&"font_color", Color(0.74, 0.66, 0.50, 0.70) if compact else Color(0.44, 0.34, 0.22, 0.72))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(82, 36) if compact else Vector2(0, 42)
	return label


func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", _make_tooltip_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override(&"margin_left", 12)
	margin.add_theme_constant_override(&"margin_top", 9)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	box.add_theme_constant_override(&"separation", 5)
	margin.add_child(box)

	var parts := for_text.split("\n", false, 1)
	var name_label := Label.new()
	name_label.text = parts[0] if parts.size() > 0 else ""
	name_label.add_theme_font_size_override(&"font_size", 17)
	name_label.add_theme_color_override(&"font_color", Color(0.24, 0.36, 0.28, 1.0))
	box.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = parts[1] if parts.size() > 1 else ""
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override(&"font_size", 14)
	desc_label.add_theme_color_override(&"font_color", Color(0.28, 0.20, 0.12, 1.0))
	box.add_child(desc_label)

	return panel


func _make_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	if compact:
		sb.bg_color = Color(0.88, 0.97, 0.94, 0.52)
		sb.border_color = Color(0.42, 0.64, 0.58, 0.62)
	else:
		sb.bg_color = Color(0.90, 0.98, 0.95, 0.42)
		sb.border_color = Color(0.34, 0.58, 0.54, 0.46)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


static func _make_icon_style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 5
	sb.content_margin_top = 5
	sb.content_margin_right = 5
	sb.content_margin_bottom = 5
	return sb


static func _make_tooltip_style() -> StyleBox:
	var theme_style := load(TOOLTIP_STYLE_PATH) as StyleBox
	if theme_style != null:
		return theme_style
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.92, 0.99, 0.96, 0.96)
	sb.border_color = Color(0.34, 0.62, 0.56, 0.88)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_size = 8
	sb.shadow_color = Color(0.04, 0.16, 0.15, 0.18)
	return sb
