class_name EnemyView extends PanelContainer

@onready var name_label: Label = $VBox/NameLabel
@onready var texture_rect: TextureRect = $VBox/TextureRect
@onready var hp_bar: ProgressBar = $VBox/HpBar
@onready var hp_label: Label = $VBox/HpBar/HpLabel
@onready var intent_label: Label = $VBox/IntentPanel/IntentMargin/IntentVBox/IntentHeader/IntentLabel
@onready var countdown_label: Label = $VBox/IntentPanel/IntentMargin/IntentVBox/IntentHeader/CountdownLabel
@onready var intent_progress: ProgressBar = $VBox/IntentPanel/IntentMargin/IntentVBox/IntentProgress
@onready var intent_desc_label: Label = $VBox/IntentPanel/IntentMargin/IntentVBox/IntentDescLabel

var combatant_id: StringName
var _chain: Chain
var _max_hp: int
var _enemy_name_key: String = ""
var _timeline: Timeline

signal clicked(combatant_id: StringName)

func _ready() -> void:
	gui_input.connect(_on_self_gui_input)
	mouse_filter = Control.MOUSE_FILTER_PASS

func setup(combatant: Combatant) -> void:
	combatant_id = combatant.combatant_id
	_chain = combatant.chain
	_max_hp = combatant.max_hp

	name_label.text = combatant.display_name

	_load_portrait(combatant.combatant_id)

	hp_bar.max_value = _max_hp
	hp_bar.value = combatant.hp
	_update_hp_label(combatant.hp, _max_hp)

	EventBus.combatant_hp_changed.connect(_on_hp_changed)
	EventBus.combatant_died.connect(_on_died)
	EventBus.battle_tick_advanced.connect(_on_tick_advanced)

	_update_intent()

func bind_timeline(timeline: Timeline) -> void:
	_timeline = timeline
	_update_intent()

func _process(_delta: float) -> void:
	if _chain == null or _timeline == null:
		return
	_update_intent()

func _load_portrait(id: StringName) -> void:
	if has_meta("portrait"):
		var meta_portrait := get_meta("portrait") as Texture2D
		if meta_portrait != null:
			texture_rect.texture = meta_portrait
			texture_rect.modulate = Color.WHITE
			return
	var path := "res://assets/enemies/%s.png" % str(id)
	if ResourceLoader.exists(path):
		var tex := load(path) as Texture2D
		if tex:
			texture_rect.texture = tex
			texture_rect.modulate = Color.WHITE
			return
	var grad := Gradient.new()
	grad.set_color(0, Color(0.32, 0.28, 0.22, 0.9))
	grad.set_color(1, Color(0.18, 0.14, 0.10, 0.9))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 220
	tex.height = 200
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	texture_rect.texture = tex
	texture_rect.modulate = Color.WHITE

func _update_intent() -> void:
	if _chain == null or _chain.slots.is_empty():
		intent_label.text = "—"
		countdown_label.text = ""
		intent_progress.value = 0
		intent_desc_label.text = ""
		return

	var idx: int = _chain.current_index
	if idx < 0 or idx >= _chain.slots.size():
		return
	var card: CardRuntime = _chain.slots[idx]
	var cost: int = card.data.cost
	var prog: int = _chain.current_card_progress
	var remaining: int = max(0, cost - prog)

	intent_label.text = tr(card.data.display_name_key)
	countdown_label.text = "%dt" % remaining
	intent_progress.max_value = cost
	var frac: float = _timeline.get_tick_progress() if _timeline != null else 0.0
	intent_progress.value = minf(float(cost), float(prog) + frac)
	intent_desc_label.text = tr(card.data.desc_key)

func _on_hp_changed(id: StringName, _old_hp: int, new_hp: int) -> void:
	if id != combatant_id: return
	hp_bar.value = new_hp
	_update_hp_label(new_hp, _max_hp)

func _on_died(id: StringName) -> void:
	if id != combatant_id: return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _on_tick_advanced(_tick: int) -> void:
	if _timeline != null:
		return
	_update_intent()

func _update_hp_label(current: int, maximum: int) -> void:
	hp_label.text = "%d / %d" % [current, maximum]

func _on_self_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit(combatant_id)
