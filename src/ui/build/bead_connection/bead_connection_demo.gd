# src/ui/build/bead_connection/bead_connection_demo.gd
# 阶段 2 §2.2 / TC-2-UI-002 BeadConnectionView 可视化 demo
# 用于手动 / UI 巡检验证：直接打开本场景即可摆弄连线
extends Control

@onready var view_host: Control = $VBox/Margin/ViewHost
@onready var status_label: Label = $VBox/Status
@onready var orphan_label: Label = $VBox/OrphanLabel

var _bead_view: BeadConnectionView


func _ready() -> void:
	_bead_view = BeadConnectionView.new()
	_bead_view.anchor_right = 1.0
	_bead_view.anchor_bottom = 1.0
	view_host.add_child(_bead_view)

	# 加载 4 个底座做演示：1 基础 + 3 扩展（1×1, 1×2, 1×3）
	var slots: Array = [
		load("res://data/slots/base/sword_base.tres"),
		load("res://data/slots/extended/ext_1x1_simple.tres"),
		load("res://data/slots/extended/ext_1x2_balanced.tres"),
		load("res://data/slots/extended/ext_1x3_long.tres"),
	]
	_bead_view.set_slots(slots)
	_bead_view.connections_changed.connect(_refresh_status)
	_refresh_status()


func _refresh_status() -> void:
	var conn := _bead_view.get_connections()
	if conn.is_empty():
		status_label.text = "Connections: {}"
	else:
		var parts: Array = []
		for src in conn:
			parts.append("%s→%s" % [src, conn[src]])
		status_label.text = "Connections: { " + ", ".join(parts) + " }"
	var orphans := _bead_view.get_orphan_ids()
	orphan_label.text = "Orphans: %s" % str(orphans) if not orphans.is_empty() else "Orphans: []"
