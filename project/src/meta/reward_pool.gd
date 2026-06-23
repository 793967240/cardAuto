# src/meta/reward_pool.gd
# 战斗奖励池 - 阶段 2（卡牌 / 宝石奖励）
#
# 后续阶段会扩展为多类型池（卡牌/宝石/遗物/金币/裁切服务），见 GDD §5.1。
class_name RewardPool extends RefCounted

const RESOURCE_CATALOG = preload("res://src/meta/resource_catalog.gd")

## 角色 → 该角色可用的卡牌目录（不含起始卡专属限制；阶段 1 直接全池）
const CHARACTER_CARD_DIRS: Dictionary = {
	&"sword": "res://data/cards/sword/",
}
const GEM_DIR := "res://data/gems/"
const RELIC_DIR := "res://data/relics/"

## 抽取 N 张不重复卡牌作为奖励（默认 3 张）。
## - character_id：当前 Run 角色（决定卡池）
## - count：要抽几张（默认 3）
## - rng_seed：可选，传入固定 seed 便于测试；0 表示用 Time-based 随机
##
## 返回：Array[CardData]（可能少于 count，如果池子不够大）
static func draw(character_id: StringName, count: int = 3, rng_seed: int = 0) -> Array[CardData]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())

	var empty: Array[CardData] = []
	var dir_path: String = CHARACTER_CARD_DIRS.get(character_id, "")
	if dir_path == "":
		push_warning("RewardPool.draw: 未知角色 %s，无奖励池" % character_id)
		return empty

	var pool := _load_pool(dir_path)
	if pool.is_empty():
		return empty

	# Fisher-Yates 不重复抽样（用本地 RNG，保证 seed 可复现）
	var n := mini(count, pool.size())
	var out: Array[CardData] = []
	for i in range(n):
		var pick_idx := rng.randi_range(i, pool.size() - 1)
		var tmp: CardData = pool[i]
		pool[i] = pool[pick_idx]
		pool[pick_idx] = tmp
		out.append(pool[i])
	return out

## 抽取混合奖励。当前阶段保证至少 1 个宝石候选，剩余为卡牌。
## 返回元素格式：
##   { "type": &"card", "resource": CardData }
##   { "type": &"gem",  "resource": GemData }
static func draw_options(character_id: StringName, count: int = 3, rng_seed: int = 0) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())

	var cards := _load_card_pool(character_id)
	var gems := _load_gem_pool()
	var options: Array[Dictionary] = []

	if not gems.is_empty() and count > 0:
		var gem := _pick_remove(gems, rng) as GemData
		options.append({"type": &"gem", "resource": gem})

	while options.size() < count and not cards.is_empty():
		var card := _pick_remove(cards, rng) as CardData
		options.append({"type": &"card", "resource": card})

	while options.size() < count and not gems.is_empty():
		var gem := _pick_remove(gems, rng) as GemData
		options.append({"type": &"gem", "resource": gem})

	_shuffle_options(options, rng)
	return options

## 宝箱奖励：直接给 1 个遗物或宝石。遗物优先但可随机出宝石。
static func draw_chest(rng_seed: int = 0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_unix_time_from_system())
	var relics := _load_relic_pool()
	var gems := _load_gem_pool()
	var can_pick_relic := not relics.is_empty()
	var can_pick_gem := not gems.is_empty()
	if can_pick_relic and (not can_pick_gem or rng.randf() < 0.6):
		return {"type": &"relic", "resource": _pick_remove(relics, rng)}
	if can_pick_gem:
		return {"type": &"gem", "resource": _pick_remove(gems, rng)}
	return {}

## 扫描卡牌目录，加载所有 .tres 卡牌资源
static func _load_pool(dir_path: String) -> Array[CardData]:
	var out: Array[CardData] = []
	var paths := _paths_for_card_dir(dir_path)
	if paths.is_empty():
		push_warning("RewardPool: 未找到卡牌清单 %s" % dir_path)
		return out

	for path in paths:
		var res := load(path) as CardData
		if res != null:
			out.append(res)
		else:
			push_warning("RewardPool: 无法加载卡牌资源 %s" % path)
	return out

static func _load_card_pool(character_id: StringName) -> Array[CardData]:
	var empty: Array[CardData] = []
	var dir_path: String = CHARACTER_CARD_DIRS.get(character_id, "")
	if dir_path == "":
		push_warning("RewardPool.draw_options: 未知角色 %s，无卡牌奖励池" % character_id)
		return empty
	return _load_pool(dir_path)

static func _load_gem_pool() -> Array[GemData]:
	var out: Array[GemData] = []
	for path in RESOURCE_CATALOG.gem_paths():
		var res := load(path) as GemData
		if res != null:
			out.append(res)
		else:
			push_warning("RewardPool: 无法加载宝石资源 %s" % path)
	return out

static func _load_relic_pool() -> Array[RelicData]:
	var out: Array[RelicData] = []
	for path in RESOURCE_CATALOG.relic_paths():
		var res := load(path) as RelicData
		if res != null:
			out.append(res)
		else:
			push_warning("RewardPool: 无法加载遗物资源 %s" % path)
	return out

static func _paths_for_card_dir(dir_path: String) -> Array[String]:
	for character_id in CHARACTER_CARD_DIRS:
		if CHARACTER_CARD_DIRS[character_id] == dir_path:
			return RESOURCE_CATALOG.card_paths(character_id)
	return []

static func _pick_remove(pool: Array, rng: RandomNumberGenerator) -> Variant:
	var pick_idx := rng.randi_range(0, pool.size() - 1)
	var item = pool[pick_idx]
	pool.remove_at(pick_idx)
	return item

static func _shuffle_options(options: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	for i in range(options.size()):
		var pick_idx := rng.randi_range(i, options.size() - 1)
		var tmp := options[i]
		options[i] = options[pick_idx]
		options[pick_idx] = tmp
