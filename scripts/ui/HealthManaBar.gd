# HealthManaBar.gd
# =============================================================================
# HUD component displaying HP and mana orbs / bars.
# Subscribes to EventBus signals — never holds a direct character reference.
# Suitable for both player and enemy health bars (via show_mana = false).
#
# SCENE REQUIREMENTS:
#   TextureProgressBar  "HPBar"
#   TextureProgressBar  "ManaBar"
#   Label               "HPLabel"
#   Label               "ManaLabel"
# =============================================================================
class_name HealthManaBar
extends Control

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var hp_bar: TextureProgressBar = get_node_or_null("HPBar")
@onready var mana_bar: TextureProgressBar = get_node_or_null("ManaBar")
@onready var hp_label: Label = get_node_or_null("HPLabel")
@onready var mana_label: Label = get_node_or_null("ManaLabel")

# ─── Configuration ────────────────────────────────────────────────────────────

## If false, the mana bar is hidden (for enemies that have no mana).
@export var show_mana: bool = true

## If set, this bar tracks a specific character node.
## If null, it auto-tracks the registered player via GameManager.
@export var tracked_character: NodePath = NodePath("")

var _target: BaseCharacter = null

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	if mana_bar:
		mana_bar.visible = show_mana
	if mana_label:
		mana_label.visible = show_mana

	if tracked_character != NodePath(""):
		_target = get_node(tracked_character) as BaseCharacter
		if _target:
			_connect_to_character(_target)
	else:
		# Wait for player registration.
		EventBus.character_leveled_up.connect(_on_player_changed)
		GameManager.phase_changed.connect(_on_phase_changed)
		call_deferred("_try_find_player")


func _try_find_player() -> void:
	var player := GameManager.player as BaseCharacter
	if player and player != _target:
		_target = player
		_connect_to_character(_target)


func _on_phase_changed(_old: int, _new: int) -> void:
	_try_find_player()


func _on_player_changed(_character: Node, _level: int) -> void:
	_try_find_player()

# ─── Character Connection ─────────────────────────────────────────────────────

func _connect_to_character(character: BaseCharacter) -> void:
	character.stats.hp_changed.connect(_on_hp_changed)
	character.stats.mana_changed.connect(_on_mana_changed)

	# Initialise display with current values.
	_on_hp_changed(character.stats.current_hp, character.stats.get_stat("max_hp"))
	_on_mana_changed(character.stats.current_mana, character.stats.get_stat("max_mana"))

# ─── Stat Handlers ────────────────────────────────────────────────────────────

func _on_hp_changed(current: float, maximum: float) -> void:
	if maximum <= 0.0:
		return
	if hp_bar:
		hp_bar.max_value = maximum
		hp_bar.value = current
	if hp_label:
		hp_label.text = "%d / %d" % [int(current), int(maximum)]


func _on_mana_changed(current: float, maximum: float) -> void:
	if not show_mana or maximum <= 0.0:
		return
	if mana_bar:
		mana_bar.max_value = maximum
		mana_bar.value = current
	if mana_label:
		mana_label.text = "%d / %d" % [int(current), int(maximum)]
