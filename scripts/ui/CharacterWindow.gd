# CharacterWindow.gd
# =============================================================================
# Character stats window (the "C" window in Diablo 2).
# Displays:
#   • Primary stats (STR/DEX/INT/VIT) with allocation buttons
#   • Derived stats (HP, Mana, Damage, Armor, Crit, etc.)
#   • Unspent stat/skill point counters
#   • Equipment paperdoll (visual slot indicators)
#
# SCENE REQUIREMENTS (Labels named by convention):
#   Label  "StrValue", "DexValue", "IntValue", "VitValue"
#   Button "StrPlusBtn", "DexPlusBtn", "IntPlusBtn", "VitPlusBtn"
#   Label  "MaxHPValue", "MaxManaValue", "DmgValue", "ArmorValue"
#   Label  "CritValue", "AtkSpdValue", "MoveSpdValue"
#   Label  "StatPointsLabel", "SkillPointsLabel"
#   Label  "LevelValue", "XPBar" (TextureProgressBar or Label)
# =============================================================================
class_name CharacterWindow
extends Control

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var str_value: Label = get_node_or_null("Stats/StrValue")
@onready var dex_value: Label = get_node_or_null("Stats/DexValue")
@onready var int_value: Label = get_node_or_null("Stats/IntValue")
@onready var vit_value: Label = get_node_or_null("Stats/VitValue")

@onready var str_btn: Button = get_node_or_null("Stats/StrPlusBtn")
@onready var dex_btn: Button = get_node_or_null("Stats/DexPlusBtn")
@onready var int_btn: Button = get_node_or_null("Stats/IntPlusBtn")
@onready var vit_btn: Button = get_node_or_null("Stats/VitPlusBtn")

@onready var hp_value: Label = get_node_or_null("Derived/MaxHPValue")
@onready var mana_value: Label = get_node_or_null("Derived/MaxManaValue")
@onready var dmg_value: Label = get_node_or_null("Derived/DmgValue")
@onready var armor_value: Label = get_node_or_null("Derived/ArmorValue")
@onready var crit_value: Label = get_node_or_null("Derived/CritValue")
@onready var atk_spd_value: Label = get_node_or_null("Derived/AtkSpdValue")
@onready var mov_spd_value: Label = get_node_or_null("Derived/MovSpdValue")

@onready var stat_points_label: Label = get_node_or_null("Header/StatPointsLabel")
@onready var skill_points_label: Label = get_node_or_null("Header/SkillPointsLabel")
@onready var level_label: Label = get_node_or_null("Header/LevelValue")

# ─── State ────────────────────────────────────────────────────────────────────

var _player: PlayerCharacter = null

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	visible = false

	# Button connections.
	if str_btn: str_btn.pressed.connect(func(): _allocate_stat("strength"))
	if dex_btn: dex_btn.pressed.connect(func(): _allocate_stat("dexterity"))
	if int_btn: int_btn.pressed.connect(func(): _allocate_stat("intelligence"))
	if vit_btn: vit_btn.pressed.connect(func(): _allocate_stat("vitality"))

	# Subscribe to events.
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	EventBus.stat_changed.connect(_on_stat_changed)
	EventBus.character_leveled_up.connect(_on_level_up)
	EventBus.stat_points_available.connect(_on_stat_points_changed)
	EventBus.skill_points_available.connect(_on_skill_points_changed)

# ─── Population ──────────────────────────────────────────────────────────────

func _populate() -> void:
	_player = GameManager.player as PlayerCharacter
	if _player == null:
		return

	var stats := _player.stats

	if str_value: str_value.text = str(stats.strength)
	if dex_value: dex_value.text = str(stats.dexterity)
	if int_value: int_value.text = str(stats.intelligence)
	if vit_value: vit_value.text = str(stats.vitality)

	if hp_value: hp_value.text = "%.0f" % stats.get_stat("max_hp")
	if mana_value: mana_value.text = "%.0f" % stats.get_stat("max_mana")
	if dmg_value: dmg_value.text = "%.0f – %.0f" % [stats.get_stat("min_damage"), stats.get_stat("max_damage")]
	if armor_value: armor_value.text = "%.0f" % stats.get_stat("armor")
	if crit_value: crit_value.text = "%.1f%%" % stats.get_stat("crit_chance")
	if atk_spd_value: atk_spd_value.text = "%.2f" % stats.get_stat("attack_speed")
	if mov_spd_value: mov_spd_value.text = "%.0f" % stats.get_stat("movement_speed")

	if level_label: level_label.text = "Level %d" % stats.level
	if stat_points_label: stat_points_label.text = "Stat Points: %d" % _player.unspent_stat_points
	if skill_points_label: skill_points_label.text = "Skill Points: %d" % _player.unspent_skill_points

	_update_allocation_buttons()


func _update_allocation_buttons() -> void:
	var has_points := _player != null and _player.unspent_stat_points > 0
	str_btn.visible = has_points
	dex_btn.visible = has_points
	int_btn.visible = has_points
	vit_btn.visible = has_points

# ─── Event Handlers ───────────────────────────────────────────────────────────

func _on_panel_toggled(panel_id: String, is_visible: bool) -> void:
	if panel_id == "character":
		visible = is_visible
		if is_visible:
			_populate()


func _on_stat_changed(_character: Node, _stat_name: String, _old: float, _new: float) -> void:
	if visible:
		_populate()


func _on_level_up(_character: Node, _level: int) -> void:
	if visible:
		_populate()


func _on_stat_points_changed(points: int) -> void:
	if stat_points_label:
		stat_points_label.text = "Stat Points: %d" % points
	_update_allocation_buttons()


func _on_skill_points_changed(points: int) -> void:
	if skill_points_label:
		skill_points_label.text = "Skill Points: %d" % points

# ─── Allocation ──────────────────────────────────────────────────────────────

func _allocate_stat(stat_name: String) -> void:
	var player := GameManager.player as PlayerCharacter
	if player:
		player.allocate_stat_point(stat_name)
	_populate()
