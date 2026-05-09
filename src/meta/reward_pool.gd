# src/meta/reward_pool.gd
# 战斗奖励池 - 阶段 1 MVP（仅卡牌奖励）
#
# 后续阶段会扩展为多类型池（卡牌/底座/词条/遗物/金币），见 GDD §5.1。
# 当前实现：按角色 character_id 决定卡池目录，三选一不重复抽样。
class_name RewardPool extends RefCounted

## 角色 → 该角色可用的卡牌目录（不含起始卡专属限制；阶段 1 直接全池）
const CHARACTER_CARD_DIRS: Dictionary = {
	&"sword": "res://data/cards/sword/",
}

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

## 扫描卡牌目录，加载所有 .tres 卡牌资源
static func _load_pool(dir_path: String) -> Array[CardData]:
	var out: Array[CardData] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("RewardPool: 无法打开目录 %s" % dir_path)
		return out

	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res := load(dir_path + fname) as CardData
			if res != null:
				out.append(res)
		fname = dir.get_next()
	dir.list_dir_end()
	return out
