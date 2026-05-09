# src/ui/reward/reward_scene.gd
# 战斗胜利后的"三选一卡牌奖励"界面 - 阶段 1 MVP
#
# 流程契约（必须满足）：
#   - 进入条件：BattleScene 正式战斗胜利后 _on_battle_ended 跳到此处
#                （此时 node_index 还未推进、未存档）
#   - 选择卡牌：加入 GameState.current_run.deck → _finalize() → 回 MapScene
#   - 跳过：       不加入卡牌 → _finalize() → 回 MapScene
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

var _options: Array[CardData] = []
var _picked: bool = false  # 防止双击重复推进

func _ready() -> void:
	if GameState.current_run == null:
		# 安全网：没有进行中的 Run，直接回主菜单
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	skip_btn.pressed.connect(_on_skip_pressed)

	_options = RewardPool.draw(GameState.current_run.character_id, REWARD_COUNT)
	_render_cards()

	# 池子为空（极端情况）→ 退化为"按继续即可"
	if _options.is_empty():
		subtitle_label.text = tr("reward.empty")

func _update_texts() -> void:
	title_label.text = tr("reward.title")
	subtitle_label.text = tr("reward.subtitle")
	skip_btn.text = tr("reward.skip")

func _render_cards() -> void:
	for child in cards_container.get_children():
		child.queue_free()

	for card in _options:
		var view: CardView = CARD_VIEW_SCENE.instantiate()
		cards_container.add_child(view)
		view.setup_build_slot(card)
		view.pressed.connect(_on_card_pressed.bind(card))

func _on_card_pressed(_button_index: int, card: CardData) -> void:
	if _picked:
		return
	_picked = true
	GameState.current_run.deck.append(card)
	_finalize()

func _on_skip_pressed() -> void:
	if _picked:
		return
	_picked = true
	_finalize()

## 推进 node_index、存档、跳回地图
## 不变量：无论选牌还是跳过，都要走完这套
func _finalize() -> void:
	var run := GameState.current_run
	run.node_index += 1
	var save := SaveSystem.new()
	save.save_run(run)

	# Boss 节点已经是最后一个；如果完成了最后节点，end_run 后回主菜单
	if run.node_index >= run.map_nodes.size():
		GameState.end_run(true)
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return

	get_tree().change_scene_to_file("res://scenes/map/map_scene.tscn")
