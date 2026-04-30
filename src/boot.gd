# src/boot.gd
# 启动脚本 - 处理启动参数后跳转主菜单
extends Node

func _ready() -> void:
	if GameState.is_smoke_test:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
