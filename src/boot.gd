# src/boot.gd
# 启动脚本 - 处理启动参数后跳转主菜单
extends Node

func _ready() -> void:
	# 用 call_deferred 避免在 _ready 中同步切换场景导致的 "busy adding/removing children" 警告
	call_deferred("_goto_main_menu")

func _goto_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
