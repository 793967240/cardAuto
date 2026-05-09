# src/ui/build/build_scene.gd
# 构筑界面 - 1×6 链条槽位 + 卡牌侧栏（拖拽 + 点击双模式）
class_name BuildScene extends Control

const SLOT_COUNT: int = 6
const TICK_DURATION: float = 0.5  # 与 Tuning.tick_duration_sec 一致
const CARD_VIEW_SCENE = preload("res://scenes/components/card_view.tscn")

@onready var slot_container: HBoxContainer = $VBox/SlotPanel/Margin/SlotHBox
@onready var deck_grid: GridContainer = $VBox/Body/DeckPanel/DeckMargin/DeckVBox/Scroll/DeckGrid
@onready var deck_label: Label = $VBox/Body/DeckPanel/DeckMargin/DeckVBox/DeckLabel
@onready var total_duration_label: Label = $VBox/Footer/TotalDurationLabel
@onready var simulate_btn: Button = $VBox/Footer/SimulateBtn
@onready var confirm_btn: Button = $VBox/Footer/ConfirmBtn
@onready var back_btn: Button = $VBox/Footer/BackBtn
@onready var title_label: Label = $VBox/Header/TitleLabel

## 当前选中的链条卡（与 RunState.chain_cards 同步）
var _chain_cards: Array[CardData] = []

## 当前选中的卡（用于"点击放入槽位"模式，作为拖拽的备用交互）
var _selected_card: CardData = null
var _selected_card_view: CardView = null


func _ready() -> void:
	_update_texts()
	EventBus.language_changed.connect(func(_l): _update_texts())
	simulate_btn.pressed.connect(_on_simulate_pressed)
	confirm_btn.pressed.connect(_on_confirm_pressed)
	back_btn.pressed.connect(_on_back_pressed)

	# 从 GameState 加载当前 RunState（如无则启动一个新 Run）
	if GameState.current_run == null:
		GameState.start_run(&"sword")

	_chain_cards = GameState.current_run.chain_cards.duplicate()
	# 确保槽数为 6
	while _chain_cards.size() < SLOT_COUNT:
		_chain_cards.append(null)

	_rebuild_slots()
	_rebuild_deck_list()
	_update_total_duration()

func _update_texts() -> void:
	title_label.text = tr("build.title")
	deck_label.text = tr("build.label.deck")
	simulate_btn.text = tr("build.button.simulate")
	confirm_btn.text = tr("build.button.confirm")
	back_btn.text = tr("ui.button.back")

# ─── 链条槽位 UI ────────────────────────────────────────────────

func _rebuild_slots() -> void:
	for child in slot_container.get_children():
		child.queue_free()

	for i in range(SLOT_COUNT):
		var view := CARD_VIEW_SCENE.instantiate() as CardView
		slot_container.add_child(view)
		view.setup_build_slot(_chain_cards[i])
		view.set_meta(&"slot_index", i)
		view.set_meta(&"on_drop", Callable(self, "_on_slot_drop"))
		view.pressed.connect(_on_slot_pressed.bind(i, view))

func _on_slot_pressed(button_index: int, slot_index: int, _view: CardView) -> void:
	if button_index == MOUSE_BUTTON_LEFT:
		# 左键：把当前点击选中的卡放进这个槽（拖拽的备用交互）
		if _selected_card != null:
			_place_card_in_slot(_selected_card, slot_index)
			_clear_selection()
	elif button_index == MOUSE_BUTTON_RIGHT:
		# 右键：把槽里的卡取出
		if _chain_cards[slot_index] != null:
			_chain_cards[slot_index] = null
			_refresh_all()

## 拖拽投放回调（由 CardView meta 触发）
##   target_slot_index: 目标槽位索引
##   payload: { source: "deck_item" | "slot", card: CardData, slot_index?: int }
func _on_slot_drop(target_slot_index: int, payload: Dictionary) -> void:
	if target_slot_index < 0 or target_slot_index >= SLOT_COUNT:
		return
	var card: CardData = payload.get("card", null)
	if card == null:
		return

	var source: String = payload.get("source", "")
	if source == "deck_item":
		# 从卡组拖入：放置（覆盖原有）
		_place_card_in_slot(card, target_slot_index)
	elif source == "slot":
		var src_index: int = int(payload.get("slot_index", -1))
		if src_index < 0 or src_index >= SLOT_COUNT or src_index == target_slot_index:
			return
		# 槽位间互换
		var tmp: CardData = _chain_cards[target_slot_index]
		_chain_cards[target_slot_index] = _chain_cards[src_index]
		_chain_cards[src_index] = tmp
		_refresh_all()

## 放置一张卡到指定槽（用于点击 / 拖入）；会覆盖该槽原有内容
func _place_card_in_slot(card: CardData, slot_index: int) -> void:
	_chain_cards[slot_index] = card
	_refresh_all()

func _refresh_all() -> void:
	_rebuild_slots()
	_rebuild_deck_list()
	_update_total_duration()

# ─── 卡组侧栏 UI ─────────────────────────────────────────────────

func _rebuild_deck_list() -> void:
	for child in deck_grid.get_children():
		child.queue_free()

	# 统计卡组里每张卡的总数和已使用数
	var deck := GameState.current_run.deck
	var used_counts: Dictionary = {}
	for c in _chain_cards:
		if c != null:
			used_counts[c.id] = int(used_counts.get(c.id, 0)) + 1

	var deck_counts: Dictionary = {}
	for c in deck:
		deck_counts[c.id] = int(deck_counts.get(c.id, 0)) + 1

	var displayed: Dictionary = {}
	for c in deck:
		if displayed.has(c.id):
			continue
		displayed[c.id] = true
		var total: int = deck_counts[c.id]
		var used: int = int(used_counts.get(c.id, 0))
		var available: int = total - used

		var view := CARD_VIEW_SCENE.instantiate() as CardView
		deck_grid.add_child(view)
		view.setup_deck_item(c, available, total)
		view.pressed.connect(_on_deck_card_pressed.bind(c, view, available))

func _on_deck_card_pressed(button_index: int, card: CardData, view: CardView, available: int) -> void:
	if button_index != MOUSE_BUTTON_LEFT:
		return
	if available <= 0:
		return
	# 点击选中：作为拖拽的备用交互（点选 + 点击空槽放入）
	_clear_selection()
	_selected_card = card
	_selected_card_view = view
	view.set_selected(true)

func _clear_selection() -> void:
	if is_instance_valid(_selected_card_view):
		_selected_card_view.set_selected(false)
	_selected_card = null
	_selected_card_view = null

# ─── 链条总时长 ──────────────────────────────────────────────────

func _update_total_duration() -> void:
	var total_ticks: int = 0
	for c in _chain_cards:
		if c != null:
			total_ticks += c.cost
	# 加上修整时长（默认 2 tick）
	total_ticks += 2
	var seconds: float = total_ticks * TICK_DURATION
	total_duration_label.text = tr("build.label.total_duration") + ": %d tick (%.1fs)" % [total_ticks, seconds]

# ─── 按钮事件 ────────────────────────────────────────────────────

func _on_simulate_pressed() -> void:
	# 模拟战斗：当前链条进入 BattleScene 试打一场，结果不影响存档/血量/进度
	# 把当前链条同步到 RunState，让 BattleScene 能用同一套读取逻辑构建玩家链
	GameState.current_run.chain_cards = _chain_cards.duplicate()
	GameState.is_simulation = true
	# 选取下一个未通关的 BATTLE/BOSS 节点的敌人；如下个不是战斗节点则 fallback
	GameState.next_battle_enemy_id = _pick_simulation_enemy_id()
	get_tree().change_scene_to_file("res://scenes/battle/battle_scene.tscn")

func _on_confirm_pressed() -> void:
	GameState.current_run.chain_cards = _chain_cards.duplicate()
	# 保存
	var save := SaveSystem.new()
	save.save_run(GameState.current_run)
	# 回到进来的地方（地图 / 主菜单等），由调用方在跳进 BuildScene 前设置
	get_tree().change_scene_to_file(GameState.build_return_scene)

func _on_back_pressed() -> void:
	# "返回"语义上等于不保存改动地退出。同样回到进来的地方。
	get_tree().change_scene_to_file(GameState.build_return_scene)

## 选模拟战斗的敌人：从下一个未通关的 BATTLE/BOSS 节点取 enemy_id
## 找不到则返回 "slime" 兜底
func _pick_simulation_enemy_id() -> String:
	return BuildScene.pick_simulation_enemy_id(GameState.current_run)

## 静态版（便于测试）：给定 RunState，返回应该模拟的敌人 id
##   - run 为 null / 没有未通关战斗节点 → "slime"
##   - 否则 → 从 run.node_index+1 起，第一个非空 enemy_id 节点的 enemy_id
static func pick_simulation_enemy_id(run: RunState) -> String:
	if run == null or run.map_nodes == null:
		return "slime"
	var start_idx: int = run.node_index + 1  # 下一个未通关节点
	for i in range(start_idx, run.map_nodes.size()):
		var n: Dictionary = run.map_nodes[i]
		var enemy_id: String = n.get("enemy_id", "")
		if enemy_id != "":
			return enemy_id
	return "slime"
