# src/input/input_router.gd
# 输入抽象层 - 统一键鼠/触屏/手柄
# AutoLoad 为 "InputRouter"
extends Node

enum Device { MOUSE_KEYBOARD, TOUCH, GAMEPAD }

## 高层语义事件
signal pointer_moved(world_pos: Vector2)
signal pointer_pressed(world_pos: Vector2, button: int)   # 0=主键, 1=次键
signal pointer_released(world_pos: Vector2, button: int)
signal pointer_dragged(from: Vector2, to: Vector2, button: int)
signal hover_entered(node: Node)          # PC only
signal hover_exited(node: Node)
signal action_triggered(action: StringName)

## 当前输入设备
var current_device: Device = Device.MOUSE_KEYBOARD
signal device_changed(new_device: Device)

var _last_drag_pos: Vector2

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_switch_device(Device.MOUSE_KEYBOARD)
		pointer_moved.emit(event.global_position)
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			pointer_dragged.emit(_last_drag_pos, event.global_position, 0)
		_last_drag_pos = event.global_position

	elif event is InputEventMouseButton:
		_switch_device(Device.MOUSE_KEYBOARD)
		var btn := 0 if event.button_index == MOUSE_BUTTON_LEFT else 1
		if event.pressed:
			_last_drag_pos = event.global_position
			pointer_pressed.emit(event.global_position, btn)
		else:
			pointer_released.emit(event.global_position, btn)

	elif event is InputEventScreenTouch:
		_switch_device(Device.TOUCH)
		if event.pressed:
			_last_drag_pos = event.position
			pointer_pressed.emit(event.position, 0)
		else:
			pointer_released.emit(event.position, 0)

	elif event is InputEventScreenDrag:
		_switch_device(Device.TOUCH)
		pointer_dragged.emit(_last_drag_pos, event.position, 0)
		_last_drag_pos = event.position

	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_switch_device(Device.GAMEPAD)

	elif event is InputEventKey and event.pressed and not event.echo:
		_switch_device(Device.MOUSE_KEYBOARD)
		_emit_action_from_key(event)

func _emit_action_from_key(event: InputEventKey) -> void:
	for action in ["pause_toggle", "speed_1x", "speed_2x", "speed_4x",
				   "gantt_toggle", "menu_back", "confirm", "surrender"]:
		if InputMap.has_action(action) and event.is_action(action):
			action_triggered.emit(StringName(action))

func _switch_device(device: Device) -> void:
	if current_device != device:
		current_device = device
		device_changed.emit(device)

func is_mouse_keyboard() -> bool:
	return current_device == Device.MOUSE_KEYBOARD
