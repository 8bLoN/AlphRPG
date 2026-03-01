# BaseCharacter.gd
# =============================================================================
# Abstract base node for ALL characters (player and enemies).
# Handles: stat component, state machine, skill dispatching, effect system,
#          damage reception, death, and regeneration.
#
# SCENE TREE REQUIREMENTS (children expected by this script):
#   NavigationAgent3D   – "NavigationAgent3D"
#   AnimationPlayer     – "AnimationPlayer"
#   Node3D              – "VisualRoot"  (parent of all mesh layers)
#   Area3D              – "Hitbox"
#   CollisionShape3D    – "CollisionShape3D"
#
# SCALE CONVENTION:
#   WORLD_SCALE = 0.1 — multiply all stat distances by this in code.
#   Stat values (movement_speed=130, aggro_radius=280, etc.) stay unchanged
#   in data files; all movement/distance calculations multiply by WORLD_SCALE.
#
# EXTENDING:
#   PlayerCharacter  – adds mouse input, inventory, XP system
#   EnemyCharacter   – adds EnemyData loading and AI controller
# =============================================================================
class_name BaseCharacter
extends CharacterBody3D

## Scale factor converting legacy pixel-unit stat values to 3D world units.
const WORLD_SCALE: float = 0.1

# ─── Node References ─────────────────────────────────────────────────────────

@onready var navigation_agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var visual_root: Node3D = get_node_or_null("VisualRoot")
@onready var hitbox: Area3D = get_node_or_null("Hitbox")

# ─── Configuration ────────────────────────────────────────────────────────────

## Internal class id ("warrior", "mage", "rogue", "skeleton", …).
@export var character_class: String = ""

## Name shown in health bars and tooltips.
@export var display_name: String = "Character"

## Faction: 0 = player, 1 = enemy, 2 = neutral.
## Used by targeting systems to determine valid targets.
@export var faction: int = 1

# ─── Core Components ─────────────────────────────────────────────────────────

## All statistics for this character. Initialised in _initialize_stats().
var stats: CharacterStats = CharacterStats.new()

## Manages learned skills, ranks, and cooldowns.
var skill_tree: SkillTree = null

## Currently executing skill node (null when idle).
var active_skill: BaseSkill = null

## The world position the active skill is aimed at.
var _skill_target_pos: Vector3 = Vector3.ZERO

## The world position the character aims an auto-attack at.
var _attack_target_pos: Vector3 = Vector3.ZERO

## State machine (populated in _setup_state_machine).
var state_machine: StateMachine = null

## Whether this character is alive.
var is_alive: bool = true

## Direct movement target (used as fallback when NavigationAgent3D has no path).
var _move_target: Vector3 = Vector3.ZERO

# ─── Active Effect Registry ───────────────────────────────────────────────────
## Key: effect_id (String)
## Value: { "data": Dictionary, "remaining": float, "tick_timer": float }
var _active_effects: Dictionary = {}

# ─── Regen Tracking ───────────────────────────────────────────────────────────
## Accumulate delta and tick regen every REGEN_INTERVAL seconds.
const REGEN_INTERVAL: float = 0.5
var _regen_timer: float = 0.0

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	_initialize_stats()
	_setup_skill_tree()
	_setup_state_machine()
	_connect_signals()
	_on_ready()


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	# Regeneration tick.
	_regen_timer += delta
	if _regen_timer >= REGEN_INTERVAL:
		_regen_timer -= REGEN_INTERVAL
		stats.tick_regen(REGEN_INTERVAL)

	# Update active effects.
	_tick_effects(delta)

	# State machine drives movement and animation.
	# (StateMachine node handles its own _process/_physics_process.)

# ─── Overridable Hooks ────────────────────────────────────────────────────────

## Called at end of _ready(). Override for class-specific setup.
func _on_ready() -> void:
	pass


## Override to configure stats from class/enemy data.
func _initialize_stats() -> void:
	pass


## Override to build a class-specific skill tree.
func _setup_skill_tree() -> void:
	skill_tree = SkillTree.new()
	skill_tree.owner_character = self

# ─── State Machine ────────────────────────────────────────────────────────────

func _setup_state_machine() -> void:
	state_machine = StateMachine.new()
	state_machine.name = "StateMachine"
	add_child(state_machine)

	# All characters share these base states.
	state_machine.add_state("idle",   IdleState.new(self))
	state_machine.add_state("move",   MoveState.new(self))
	state_machine.add_state("attack", AttackState.new(self))
	state_machine.add_state("cast",   CastState.new(self))
	state_machine.add_state("hit",    HitState.new(self))
	state_machine.add_state("dead",   DeadState.new(self))

	state_machine.transition_to("idle")


## Subclasses can add extra states after calling super._setup_state_machine().
func add_state(state_name: String, state: CharacterState) -> void:
	state_machine.add_state(state_name, state)

# ─── Signal Connections ───────────────────────────────────────────────────────

func _connect_signals() -> void:
	stats.died.connect(_on_stats_died)
	stats.hp_changed.connect(_on_hp_changed)
	stats.mana_changed.connect(_on_mana_changed)
	stats.stat_changed.connect(_on_stat_changed)

# ─── Combat API ──────────────────────────────────────────────────────────────

## Primary entry point for receiving damage from any source.
## damage_info is the Dictionary returned by CombatManager.calculate_damage().
func take_damage(damage_info: Dictionary) -> float:
	if not is_alive:
		return 0.0

	# Evasion check (physical only).
	if damage_info.get("damage_type", -1) == CombatManager.DamageType.PHYSICAL:
		if randf() * 100.0 < stats.get_stat("evasion"):
			EventBus.floating_text_requested.emit(global_position, "Evade", Color.CYAN)
			return 0.0

	var actual: float = stats.apply_damage(damage_info.get("final_damage", 0.0))

	EventBus.character_damaged.emit(self, damage_info)
	EventBus.show_damage_number.emit(
		global_position,
		actual,
		damage_info.get("is_crit", false),
		CombatManager.DamageType.keys()[damage_info.get("damage_type", 0)])

	if is_alive and actual > 0.0:
		state_machine.transition_to("hit")

	return actual


## Heal this character. Returns actual amount healed.
func receive_healing(amount: float) -> float:
	if not is_alive:
		return 0.0
	var actual := stats.apply_healing(amount)
	EventBus.character_healed.emit(self, actual)
	return actual

# ─── Skill API ───────────────────────────────────────────────────────────────

## Activate a skill by its index in the skill bar.
## target_position is the 3D world-space aim point.
func use_skill(skill_slot: int, target_position: Vector3) -> bool:
	if not is_alive:
		return false

	var skill: BaseSkill = skill_tree.get_skill_at_slot(skill_slot)
	if skill == null or not skill.can_activate(self):
		return false

	_skill_target_pos = target_position
	active_skill = skill
	state_machine.transition_to("cast")
	skill.activate(self, target_position)
	return true


## Called by BaseSkill when execution finishes.
func on_skill_complete(skill: BaseSkill) -> void:
	if active_skill == skill:
		active_skill = null
	if state_machine.is_in_state("cast"):
		state_machine.transition_to("idle")


## Accessor used by CastState to orient the character.
func get_skill_target_position() -> Vector3:
	return _skill_target_pos


## Accessor used by AttackState.
func get_attack_target_position() -> Vector3:
	return _attack_target_pos

# ─── Status Effect System ────────────────────────────────────────────────────

## Apply a status effect. Refreshes duration if same effect is already active.
func apply_effect(effect_data: Dictionary) -> void:
	var effect_id: String = effect_data.get("id", "")
	if effect_id.is_empty():
		push_warning("BaseCharacter.apply_effect: effect has no id.")
		return

	if _active_effects.has(effect_id):
		remove_effect(effect_id)

	_active_effects[effect_id] = {
		"data": effect_data,
		"remaining": effect_data.get("duration", 5.0),
		"tick_timer": 0.0,
	}

	for mod: StatModifier in effect_data.get("modifiers", []):
		stats.add_modifier(mod)

	EventBus.effect_applied.emit(self, effect_id, effect_data.get("duration", 5.0))


## Remove an effect immediately (dispel, cleanse, etc.).
func remove_effect(effect_id: String) -> void:
	if not _active_effects.has(effect_id):
		return

	var entry: Dictionary = _active_effects[effect_id]
	for mod: StatModifier in entry["data"].get("modifiers", []):
		stats.remove_modifier(mod.id)

	_active_effects.erase(effect_id)
	EventBus.effect_removed.emit(self, effect_id)


func _tick_effects(delta: float) -> void:
	var expired: Array[String] = []

	for effect_id: String in _active_effects:
		var entry: Dictionary = _active_effects[effect_id]
		entry["remaining"] -= delta

		var tick_dmg: float = entry["data"].get("tick_damage", 0.0)
		var tick_ivl: float = entry["data"].get("tick_interval", 1.0)
		if tick_dmg > 0.0:
			entry["tick_timer"] += delta
			if entry["tick_timer"] >= tick_ivl:
				entry["tick_timer"] -= tick_ivl
				var dtype: int = entry["data"].get("damage_type", CombatManager.DamageType.POISON)
				stats.apply_damage(tick_dmg)
				EventBus.show_damage_number.emit(global_position, tick_dmg, false,
					CombatManager.DamageType.keys()[dtype])

		if entry["remaining"] <= 0.0:
			expired.append(effect_id)

	for eid in expired:
		remove_effect(eid)

# ─── Death Handling ───────────────────────────────────────────────────────────

func _on_stats_died() -> void:
	is_alive = false
	state_machine.force_transition_to("dead")
	_on_death()


## Override in subclasses for loot drops, XP awards, quest updates, etc.
func _on_death() -> void:
	pass

# ─── Stat Signal Handlers (for UI updates) ────────────────────────────────────

func _on_hp_changed(current: float, maximum: float) -> void:
	EventBus.stat_changed.emit(self, "current_hp", current, maximum)


func _on_mana_changed(current: float, maximum: float) -> void:
	EventBus.stat_changed.emit(self, "current_mana", current, maximum)


func _on_stat_changed(stat_name: String, old_val: float, new_val: float) -> void:
	EventBus.stat_changed.emit(self, stat_name, old_val, new_val)

# ─── Utility ─────────────────────────────────────────────────────────────────

## Returns true if this character is a valid combat target.
func is_targetable() -> bool:
	return is_alive and is_instance_valid(self)


## Move toward a 3D world position using NavigationAgent3D (or direct fallback).
func move_to(target_position: Vector3) -> void:
	_move_target = target_position
	if navigation_agent != null:
		navigation_agent.target_position = target_position
	state_machine.transition_to("move")


## Play an animation safely (no-op if animation doesn't exist).
func play_animation(anim_name: String) -> void:
	if animation_player and animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
