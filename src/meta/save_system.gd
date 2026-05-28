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
	var stored: String = str(data["checksum"])
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
	var state := RunState.from_dict(data)
	_rehydrate(state, data)
	return state

func _rehydrate(state: RunState, data: Dictionary) -> void:
	var card_index := _build_card_index()
	var gem_index := _build_gem_index()

	var deck_ids: Array = data.get("deck", [])
	state.deck.clear()
	for cid in deck_ids:
		if cid != "" and card_index.has(cid):
			state.deck.append(card_index[cid])

	var chain_ids: Array = data.get("chain", [])
	state.chain_cards.clear()
	for cid in chain_ids:
		if cid != "" and card_index.has(cid):
			state.chain_cards.append(card_index[cid])

	var tuning := Tuning.get_default()
	var base_slot := load(GameState.BASE_SLOT_PATH) as SlotData
	if base_slot == null:
		base_slot = SlotData.new()
		base_slot.id = &"base_slot"
		base_slot.gem_socket_count = 1

	var base_ids: Array = data.get("bases", [])
	state.bases.clear()
	for i in range(base_ids.size()):
		var slot := base_slot.duplicate() as SlotData
		slot.id = StringName(base_ids[i])
		state.bases.append(slot)

	if state.bases.is_empty():
		for i in range(tuning.base_count):
			var slot := base_slot.duplicate() as SlotData
			slot.id = StringName("base_%d" % i)
			state.bases.append(slot)

	var raw_base_cards: Dictionary = data.get("base_cards", {})
	state.base_cards.clear()
	for k in raw_base_cards:
		var cid: String = raw_base_cards[k]
		var bid := StringName(k)
		if cid != "" and card_index.has(cid):
			state.base_cards[bid] = card_index[cid]
		else:
			state.base_cards[bid] = null

	var raw_base_gems: Dictionary = data.get("base_gems", {})
	state.base_gems.clear()
	for s in state.bases:
		state.base_gems[s.id] = []
	for k in raw_base_gems:
		var bid := StringName(k)
		var gem_ids_arr: Array = raw_base_gems[k]
		var arr: Array = []
		for gid in gem_ids_arr:
			if gid != "" and gem_index.has(gid):
				arr.append(gem_index[gid])
		state.base_gems[bid] = arr

	var gem_ids: Array = data.get("gems", [])
	state.gems.clear()
	for gid in gem_ids:
		if gid != "" and gem_index.has(gid):
			state.gems.append(gem_index[gid])

func _build_card_index() -> Dictionary:
	var index: Dictionary = {}
	var dirs := ["res://data/cards/sword/"]
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir() and fname.ends_with(".tres"):
				var res := load(dir_path + fname) as CardData
				if res and res.id != &"":
					index[str(res.id)] = res
			fname = dir.get_next()
		dir.list_dir_end()
	return index

func _build_gem_index() -> Dictionary:
	var index: Dictionary = {}
	var dir_path := "res://data/gems/"
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return index
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res := load(dir_path + fname) as GemData
			if res and res.id != &"":
				index[str(res.id)] = res
		fname = dir.get_next()
	dir.list_dir_end()
	return index
