# src/ui/reward/reward_scene.gd
# 战斗胜利后的奖励界面 - 阶段 2：卡牌 / 宝石三选一
#
# 流程契约（必须满足）：
#   - 进入条件：BattleScene 正式战斗胜利后 _on_battle_ended 跳到此处
#                （此时 node_index 还未推进、未存档）
#   - 选择卡牌：加入 GameState.current_run.deck → _finalize() → 回 MapScene
#   - 选择宝石：加入 GameState.current_run.gems（独立实例）→ _finalize() → 回 MapScene
#   - 跳过：       不加入奖励 → _finalize() → 回 MapScene
#   - _finalize：node_index += 1，存档，跳转 map_scene
#
# 不变量：无论是否选牌、无论是否成功，最终一定推进 node_index 并跳回地图。
class_name RewardScene extends Control

const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")
const REWARD_COUNT: int = 3

@onready var title_label: Label = $Margin/VBox/TitleLabel
@onready var subtitle_label: Label = $Margin/VBox/SubtitleLabel
@onready var cards_container: HBoxContainer = $Margin/VBox/CardsArea/CardsRow
@onready var skip_btn: Button = $Margin/VBox/Footer/SkipBtn

var _options: Array[Dictionary] = []
var _picked: bool = false  # 防止双击重复推进

func _ready() -> void:
	if GameState.current_run == null:
		# 安全网：没有进行中的 Run，直接回主菜单
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	skip_btn.pressed.connect(_on_skip_pressed)

	_options = RewardPool.draw_options(GameState.current_run.character_id, REWARD_COUNT)
	_render_options()

	# 池子为空（极端情况）→ 退化为"按继续即可"
	if _options.is_empty():
		subtitle_label.text = tr("reward.empty")

func _update_texts() -> void:
	title_label.text = tr("reward.title")
	subtitle_label.text = tr("reward.subtitle")
	skip_btn.text = tr("reward.skip")

func _render_options() -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for option in _options:
		var reward_type: StringName = option.get("type", &"")
		var resource: Resource = option.get("resource", null)
		if reward_type == &"card" and resource is CardData:
			_render_card_option(resource as CardData)
		elif reward_type == &"gem" and resource is GemData:
			_render_gem_option(resource as GemData)

func _render_card_option(card: CardData) -> void:
	var view: CardView = CARD_VIEW_SCENE.instantiate()
	cards_container.add_child(view)
	view.setup_build_slot(card)
	view.pressed.connect(_on_card_pressed.bind(card))

func _render_gem_option(gem: GemData) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(180, 220)
	btn.text = "%s\n\n%s" % [
		tr(gem.get_name_key()),
		tr(gem.get_desc_key()),
	]
	btn.tooltip_text = tr("reward.gem.tooltip")
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.pressed.connect(_on_gem_pressed.bind(gem))
	cards_container.add_child(btn)

func _on_card_pressed(_button_index: int, card: CardData) -> void:
	if _picked:
		return
	_picked = true
	RewardScene.apply_reward(GameState.current_run, &"card", card)
	_finalize()

func _on_gem_pressed(gem: GemData) -> void:
	if _picked:
		return
	_picked = true
	RewardScene.apply_reward(GameState.current_run, &"gem", gem)
	_finalize()

func _on_skip_pressed() -> void:
	if _picked:
		return
	_picked = true
	_finalize()

## 推进 node_index、存档、跳回地图
## 不变量：无论选牌还是跳过，都要走完这套
func _finalize() -> void:
	var next_scene := RewardScene.finalize_run(GameState.current_run)
	get_tree().change_scene_to_file(next_scene)

static func apply_reward(run: RunState, reward_type: StringName, resource: Resource) -> void:
	if run == null:
		return
	if reward_type == &"card" and resource is CardData:
		run.deck.append(resource as CardData)
	elif reward_type == &"gem" and resource is GemData:
		run.gems.append(GemInstance.new(resource as GemData))

static func finalize_run(run: RunState) -> String:
	if run == null:
		return "res://scenes/main_menu.tscn"
	if GameState.pending_map_node_id != "":
		run.current_node_id = GameState.pending_map_node_id
		var node := MapGenerator.get_node_by_id(run.map_nodes, GameState.pending_map_node_id)
		run.node_index = int(node.get("floor", node.get("node_index", run.node_index + 1)))
		GameState.pending_map_node_id = ""
	else:
		run.node_index += 1
	var save := SaveSystem.new()
	save.save_run(run)

	# Boss 节点已经是最后一个；如果完成了最后节点，end_run 后回主菜单
	if run.node_index >= MapGenerator.FLOOR_COUNT:
		GameState.end_run(true)
		return "res://scenes/main_menu.tscn"

	return "res://scenes/map/map_scene.tscn"
