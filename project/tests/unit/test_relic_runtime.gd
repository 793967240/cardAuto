extends GutTest

const RELIC_RUNTIME_SCRIPT = preload("res://src/core/relic_runtime.gd")

const DESIGN_RELIC_IDS := [
	&"sword_tassel", &"ancient_coin", &"cracked_jade_charm", &"loose_page", &"whetstone",
	&"cloth_bracer", &"small_elixir", &"bronze_bell", &"old_banner", &"wooden_sword_case",
	&"wind_return_jade", &"black_iron_scabbard", &"qi_gourd", &"heart_guard_mirror",
	&"ember_talisman", &"short_incense", &"star_sand_inkstone", &"jade_chain_ring",
	&"warding_umbrella", &"needle_compass", &"taixu_sword_seal", &"nine_turn_furnace",
	&"myriad_array_plate", &"flawless_golden_body", &"thunder_trial_wood",
	&"empty_seat_lantern", &"heavenly_river_case", &"yin_yang_fish_talisman",
	&"exquisite_pagoda", &"mind_cutting_lamp",
]

func _make_player(relic_ids: Array = []) -> Combatant:
	var player := Combatant.new(&"player", "Player", 80)
	player.tags = [&"sword"]
	var relics: Array[RelicData] = []
	for id in relic_ids:
		var relic := load("res://data/relics/%s.tres" % str(id)) as RelicData
		assert_not_null(relic, "load relic %s" % str(id))
		relics.append(relic)
	player.relic_runtime = RELIC_RUNTIME_SCRIPT.new(relics)
	return player

func _make_enemy(hp: int = 100) -> Combatant:
	return Combatant.new(&"enemy", "Enemy", hp)

func _make_attack_card(cost: int = 1, damage: int = 5) -> CardData:
	var card := CardData.new()
	card.id = &"test_attack"
	card.cost = cost
	card.card_type = CardData.CardType.ATTACK
	card.tags = [&"attack", &"sword"]
	var fx := EffectAttack.new()
	fx.damage = damage
	card.effect = fx
	return card

func _make_ruby_bonus(bonus: int) -> GemData:
	var fx := GemEffectDamageBonus.new()
	fx.bonus = bonus
	var gem := GemData.new()
	gem.id = &"test_ruby"
	gem.trigger = GemData.Trigger.PASSIVE
	gem.effect = fx
	return gem

func test_all_relic_designs_have_resources() -> void:
	var seen := {}
	for relic in RewardPool._load_relic_pool():
		seen[relic.id] = true
	for id in DESIGN_RELIC_IDS:
		assert_true(seen.has(id), "Relic design should be present in data/relics: %s" % str(id))

func test_sword_tassel_adds_attack_damage() -> void:
	var player := _make_player([&"sword_tassel"])
	var enemy := _make_enemy(20)
	var ctx := BattleContext.new(player, [enemy])
	player.chain.set_slots([CardRuntime.new(_make_attack_card(1, 5))])

	player.relic_runtime.on_battle_start(ctx, player)
	player.chain.on_tick(ctx)

	assert_eq(enemy.hp, 14, "Sword Tassel should add +1 attack damage")

func test_exquisite_pagoda_scales_passive_gem_value() -> void:
	var player := _make_player([&"exquisite_pagoda"])
	var enemy := _make_enemy(20)
	var ctx := BattleContext.new(player, [enemy])
	var slot := ChainSlot.new(CardRuntime.new(_make_attack_card(1, 5)), &"base_0")
	slot.gems.append(GemInstance.new(_make_ruby_bonus(2)))
	player.chain.set_layout([slot])

	player.relic_runtime.on_battle_start(ctx, player)
	player.chain.on_tick(ctx)

	assert_eq(enemy.hp, 12, "Pagoda should scale +2 gem damage to +3, for 8 total damage")

func test_nine_turn_furnace_prevents_first_death() -> void:
	var player := _make_player([&"nine_turn_furnace"])

	var dealt := player.take_damage(999)

	assert_eq(dealt, 999, "Incoming lethal damage still resolves as damage dealt")
	assert_eq(player.hp, 21, "Furnace should leave player at 1 and then heal 20")
	assert_true(player.is_alive(), "Player should survive the first lethal hit")
