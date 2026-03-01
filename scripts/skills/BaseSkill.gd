# BaseSkill.gd
# =============================================================================
# Abstract base for every executable skill (active or passive).
# Subclass this for each skill implementation.
#
# LIFECYCLE:
#   1. SkillTree instantiates a BaseSkill subclass and stores it.
#   2. PlayerCharacter.use_skill() calls can_activate() before calling activate().
#   3. activate() starts the skill: spawns VFX, begins cast timer, deals damage.
#   4. _finish() calls character.on_skill_complete() to release the cast lock.
#   5. Cooldown timer runs independently after activation.
#
# DATA vs LOGIC SPLIT:
#   • SkillData holds all tunable numbers (damage, cost, cooldown, etc.)
#   • BaseSkill subclass holds the execution logic only.
#
# EXTENDING:
#   See ActiveSkill and PassiveSkill for the two main branches.
#   For projectiles: spawn a BaseProjectile scene in activate() / _execute().
#   For AoE: query an Area2D overlap at the target position in _execute().
# =============================================================================
class_name BaseSkill
extends RefCounted

# ─── Data & State ─────────────────────────────────────────────────────────────

## The SkillData resource that configures this skill's numbers.
var data: SkillData = null

## Current skill rank (1 = first learned, max = data.max_rank).
var rank: int = 1

## Cooldown remaining in seconds. 0 = ready.
var cooldown_remaining: float = 0.0

## The character that owns (has learned) this skill.
var owner_character: BaseCharacter = null

## Whether this skill is currently executing (cast in progress).
var is_executing: bool = false

# ─── Internal ─────────────────────────────────────────────────────────────────

## SceneTree reference needed to run timers (set by SkillTree on init).
var _scene_tree: SceneTree = null

## Cooldown ticker node (added to scene tree during cooldown).
var _cooldown_timer: Timer = null

# ─── Initialisation ───────────────────────────────────────────────────────────

func _init(p_data: SkillData, p_rank: int = 1) -> void:
	data = p_data
	rank = p_rank


## Called by SkillTree after adding this skill so it has tree access.
func initialize(character: BaseCharacter, scene_tree: SceneTree) -> void:
	owner_character = character
	_scene_tree = scene_tree

# ─── Public API ──────────────────────────────────────────────────────────────

## Returns true if the skill can currently be activated.
func can_activate(caster: BaseCharacter) -> bool:
	if data == null:
		return false
	if cooldown_remaining > 0.0:
		return false
	if is_executing:
		return false

	# Resource check.
	match data.resource_type:
		SkillData.ResourceType.MANA:
			if caster.stats.current_mana < data.get_cost_at_rank(rank):
				return false
		SkillData.ResourceType.HEALTH:
			if caster.stats.current_hp <= data.get_cost_at_rank(rank):
				return false
		SkillData.ResourceType.STAMINA:
			pass  # Extend when stamina is added.
		SkillData.ResourceType.NONE:
			pass

	return true


## Begin skill execution. Override _execute() for the actual skill logic.
func activate(caster: BaseCharacter, target_position: Vector3) -> void:
	if data == null:
		return

	is_executing = true

	# Spend resource.
	_spend_resource(caster)

	# Emit global event for VFX / audio hooks.
	EventBus.skill_activated.emit(caster, data.id)

	# If there's a cast time, delay execution.
	if data.cast_time > 0.0:
		await _scene_tree.create_timer(data.cast_time).timeout

	# Execute the actual skill effect.
	_execute(caster, target_position)

	# Mark cooldown.
	_start_cooldown(caster)

	is_executing = false
	EventBus.skill_completed.emit(caster, data.id)
	caster.on_skill_complete(self)


## Interrupt the skill (e.g. stagger, death). Override if cleanup is needed.
func interrupt(caster: BaseCharacter) -> void:
	if not is_executing:
		return
	is_executing = false
	EventBus.skill_interrupted.emit(caster, data.id)
	caster.on_skill_complete(self)

# ─── Override Points ─────────────────────────────────────────────────────────

## Override this in every skill subclass. This is where damage, projectiles,
## AoE, buffs, etc. are actually applied.
func _execute(_caster: BaseCharacter, _target_position: Vector3) -> void:
	push_warning("BaseSkill._execute() not overridden for skill: " + data.id)

# ─── Cooldown System ─────────────────────────────────────────────────────────

## Returns true if the skill is ready to use.
func is_ready() -> bool:
	return cooldown_remaining <= 0.0


## Remaining cooldown fraction [0, 1] for UI overlay rendering.
func get_cooldown_fraction() -> float:
	var total := data.get_cooldown_at_rank(rank)
	if total <= 0.0:
		return 0.0
	return cooldown_remaining / total


func _start_cooldown(caster: BaseCharacter) -> void:
	var cd := data.get_cooldown_at_rank(rank)
	if cd <= 0.0:
		return

	cooldown_remaining = cd

	# Use a polling approach via the character's _process, OR a Timer node.
	# We use a Timer for clean decoupling.
	if _cooldown_timer == null and caster.get_tree():
		_cooldown_timer = Timer.new()
		_cooldown_timer.one_shot = false
		_cooldown_timer.wait_time = 0.1  # Tick every 100ms.
		caster.add_child(_cooldown_timer)
		_cooldown_timer.timeout.connect(_tick_cooldown.bind(caster))
		_cooldown_timer.start()


func _tick_cooldown(caster: BaseCharacter) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - 0.1)
	EventBus.skill_cooldown_updated.emit(data.id, cooldown_remaining, data.get_cooldown_at_rank(rank))

	if cooldown_remaining <= 0.0:
		_cooldown_timer.stop()
		_cooldown_timer.queue_free()
		_cooldown_timer = null

# ─── Resource Spending ────────────────────────────────────────────────────────

func _spend_resource(caster: BaseCharacter) -> void:
	var cost := data.get_cost_at_rank(rank)
	match data.resource_type:
		SkillData.ResourceType.MANA:
			caster.stats.spend_mana(cost)
		SkillData.ResourceType.HEALTH:
			caster.stats.apply_damage(cost)
		SkillData.ResourceType.STAMINA:
			pass
		SkillData.ResourceType.NONE:
			pass

# ─── AoE Helper ──────────────────────────────────────────────────────────────

## Get all enemy characters within radius of a world position.
## This should be called from _execute() in AoE skill subclasses.
func get_targets_in_radius(
		world_position: Vector3,
		radius: float,
		caster: BaseCharacter) -> Array[BaseCharacter]:

	var targets: Array[BaseCharacter] = []
	var space := caster.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, world_position)
	params.collision_mask = 4  # Layer 3: character hitboxes.

	for result in space.intersect_shape(params):
		var collider: Object = result.collider
		var body: Node = collider.get_parent() if collider is Area3D else collider
		if body is BaseCharacter and body != caster and body.is_targetable():
			if data.affects_allies or body.faction != caster.faction:
				targets.append(body)
				if data.max_targets > 0 and targets.size() >= data.max_targets:
					break

	return targets
