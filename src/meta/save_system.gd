# src/meta/save_system.gd
# 存档系统 - 支持 Run 存档、元进度、损坏恢复
class_name SaveSystem extends RefCounted

const RUN_SAVE_PATH := "user://run.save"
const META_SAVE_PATH := "user://meta.save"
const BACKUP_COUNT := 3

## 保存当前 Run
func save_run(state: RunState) -> bool:
	var data := state.serialize()
	data["checksum"] = _compute_checksum(data)

	# 先写临时文件，校验后原子 rename
	var tmp_path := RUN_SAVE_PATH + ".tmp"
	if not _write_compressed(tmp_path, data):
		push_error("SaveSystem: failed to write tmp save")
		return false

	# 校验临时文件
	var verify_data = _load_compressed(tmp_path)
	if not verify_data or not _verify_checksum(verify_data):
		push_error("SaveSystem: tmp save verify failed")
		return false

	# 备份旧存档
	_rotate_backups()

	# 移动临时文件到正式路径
	DirAccess.rename_absolute(tmp_path, RUN_SAVE_PATH)
	return true

## 加载当前 Run
func load_run() -> RunState:
	if not FileAccess.file_exists(RUN_SAVE_PATH):
		return null

	var data = _load_compressed(RUN_SAVE_PATH)
	if not data or not _verify_checksum(data):
		push_warning("SaveSystem: save corrupted, attempting backup recovery")
		return _try_load_backup()

	return _migrate_if_needed(data)

## 删除当前 Run 存档（Run 结束时）
func delete_run() -> void:
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.remove_absolute(RUN_SAVE_PATH)

## 是否有进行中的 Run
func has_active_run() -> bool:
	return FileAccess.file_exists(RUN_SAVE_PATH)

# ─── 私有方法 ────────────────────────────────────────────────

func _write_compressed(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open_compressed(path, FileAccess.WRITE,
		FileAccess.COMPRESSION_GZIP)
	if not file:
		return false
	file.store_var(data)
	return true

func _load_compressed(path: String):
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open_compressed(path, FileAccess.READ,
		FileAccess.COMPRESSION_GZIP)
	if not file:
		return null
	return file.get_var()

func _compute_checksum(data: Dictionary) -> String:
	# 简单校验：序列化字符串的 hash
	var without_checksum := data.duplicate()
	without_checksum.erase("checksum")
	return str(str(without_checksum).hash())

func _verify_checksum(data: Dictionary) -> bool:
	if not data.has("checksum"):
		return false
	var stored := data["checksum"]
	return stored == _compute_checksum(data)

func _rotate_backups() -> void:
	for i in range(BACKUP_COUNT - 1, 0, -1):
		var src := "%s.bak%d" % [RUN_SAVE_PATH, i]
		var dst := "%s.bak%d" % [RUN_SAVE_PATH, i + 1]
		if FileAccess.file_exists(src):
			DirAccess.rename_absolute(src, dst)
	if FileAccess.file_exists(RUN_SAVE_PATH):
		DirAccess.rename_absolute(RUN_SAVE_PATH, RUN_SAVE_PATH + ".bak1")

func _try_load_backup() -> RunState:
	for i in range(1, BACKUP_COUNT + 1):
		var backup_path := "%s.bak%d" % [RUN_SAVE_PATH, i]
		if not FileAccess.file_exists(backup_path):
			continue
		var data = _load_compressed(backup_path)
		if data and _verify_checksum(data):
			push_warning("SaveSystem: recovered from backup bak%d" % i)
			return _migrate_if_needed(data)
	push_error("SaveSystem: all backups failed")
	return null

func _migrate_if_needed(data: Dictionary) -> RunState:
	var version: int = data.get("version", 1)
	# 版本迁移（随版本号增加）
	# if version < 2: data = _migrate_v1_to_v2(data)
	return RunState.from_dict(data)
