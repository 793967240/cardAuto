extends GutTest

func test_campfire_upgrade_replaces_only_selected_deck_instance() -> void:
	var run := RunState.new()
	var zhan := load("res://data/cards/sword/zhan.tres") as CardData
	assert_not_null(zhan, "load zhan")
	assert_not_null(zhan.upgrade, "zhan should have upgrade")
	if zhan == null or zhan.upgrade == null:
		return

	run.deck = [zhan, zhan]
	run.chain_cards = [zhan, zhan]
	var base0 := StringName("base_0")
	var base1 := StringName("base_1")
	run.base_cards = {
		base0: zhan,
		base1: zhan,
	}

	var ok := MapScene.upgrade_card_instance(run, 1)

	assert_true(ok, "upgrade should succeed")
	assert_eq(run.deck[0].id, zhan.id, "First copy should remain unupgraded")
	assert_eq(run.deck[1].id, zhan.upgrade.id, "Selected second copy should upgrade")
	assert_eq(run.chain_cards[0].id, zhan.upgrade.id, "First matching chain copy should upgrade")
	assert_eq(run.chain_cards[1].id, zhan.id, "Other chain copy should remain")
	assert_eq(run.base_cards[base0].id, zhan.upgrade.id, "First matching base copy should upgrade")
	assert_eq(run.base_cards[base1].id, zhan.id, "Other base copy should remain")
