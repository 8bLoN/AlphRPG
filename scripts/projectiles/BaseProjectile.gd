# BaseProjectile.gd
# =============================================================================
# Scene-based projectile base class. Attach to a CharacterBody2D scene with:
#   • CollisionShape2D (small circle)
#   • AnimatedSprite2D or GPUParticles2D for visuals
#   • Area2D "HitArea" for overlap detection
#
# LIFECYCLE:
#   1. Skill instantiates the scene and calls setup().
#   2. Projectile moves each frame using velocity.
#   3. On colliding with a character (via HitArea), _on_hit() is called.
#   4. _on_hit() deals damage (AoE if aoe_radius > 0) and frees the node.
#
# EXTENDING:
#   Override _on_hit() for special impact effects (freeze, chain lightning, etc.)
# =============================================================================
class_name BaseProjectile
extends CharacterBody3D

# ─── Configuration ────────────────────────────────────────────────────────────

## Movement speed in pixels per second.
@export var projectile_speed: float = 30.0

## Maximum travel distance in metres before auto-expiry.
@export var max_range: float = 60.0

## Lifetime cap regardless of range (safety net).
@export var max_lifetime: float = 5.0

# ─── Runtime State ────────────────────────────────────────────────────────────

var _caster: BaseCharacter = null
var _base_damage: float = 0.0
var _damage_type: int = 0
var _skill_multiplier: float = 1.0
var _aoe_radius: float = 0.0
var _max_targets: int = 1

var _direction: Vector3 = Vector3.FORWARD
var _spawn_position: Vector3 = Vector3.ZERO
var _lifetime: float = 0.0
var _hit_targets: Array[BaseCharacter] = []  # Track hit targets to prevent double-hits.

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var _hit_area: Area3D = get_node_or_null("HitArea") as Area3D
@onready var _visual: Node3D = get_node_or_null("Visual") as Node3D

# ─── Initialisation ───────────────────────────────────────────────────────────

## Called by the skill after instantiation.
func setup(
		caster: BaseCharacter,
		target_position: Vector3,
		base_damage: float,
		damage_type: int,
		skill_multiplier: float = 1.0,
		aoe_radius: float = 0.0,
		max_targets: int = 1) -> void:

	_caster = caster
	_base_damage = base_damage
	_damage_type = damage_type
	_skill_multiplier = skill_multiplier
	_aoe_radius = aoe_radius
	_max_targets = max_targets

	var flat_diff := Vector3(target_position.x - global_position.x, 0.0, target_position.z - global_position.z)
	_direction = flat_diff.normalized() if flat_diff.length() > 0.01 else Vector3.FORWARD
	_spawn_position = global_position

	# Orient along the travel direction.
	rotation.y = atan2(_direction.x, _direction.z)


func _ready() -> void:
	if _hit_area:
		_hit_area.body_entered.connect(_on_body_entered)
		_hit_area.area_entered.connect(_on_area_entered)

# ─── Movement ─────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	_lifetime += delta

	# Expire on timeout or range.
	if _lifetime >= max_lifetime:
		_expire()
		return
	if global_position.distance_to(_spawn_position) >= max_range:
		_expire()
		return

	velocity = _direction * projectile_speed
	move_and_slide()

# ─── Collision Handling ───────────────────────────────────────────────────────

func _on_body_entered(body: Node) -> void:
	_try_hit_character(body)


func _on_area_entered(area: Area3D) -> void:
	_try_hit_character(area.get_parent())


func _try_hit_character(node: Node) -> void:
	if not (node is BaseCharacter):
		return
	var target := node as BaseCharacter

	# Skip: same faction as caster, not targetable, or already hit.
	if not is_instance_valid(_caster):
		return
	if target.faction == _caster.faction:
		return
	if not target.is_targetable():
		return
	if _hit_targets.has(target):
		return

	_on_hit(target)


## Override this for specialised hit behaviour.
func _on_hit(primary_target: BaseCharacter) -> void:
	if _aoe_radius > 0.0:
		_deal_aoe_damage(primary_target)
	else:
		_deal_single_damage(primary_target)

	_impact()


func _deal_single_damage(target: BaseCharacter) -> void:
	_hit_targets.append(target)
	var result := CombatManager.calculate_damage(
		_caster.stats, target.stats, _base_damage,
		_damage_type, _skill_multiplier)
	target.take_damage(result)

	# VFX hook (can be overridden or connected via signal).
	_spawn_hit_vfx(target.global_position)


func _deal_aoe_damage(_epicenter_target: BaseCharacter) -> void:
	# Find all enemies in radius around the impact point.
	var space := get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = _aoe_radius
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = 4  # Character layer.

	var hit_count := 0
	for res in space.intersect_shape(params):
		var body: Node = res.collider
		if body is Area3D:
			body = body.get_parent()
		if not (body is BaseCharacter):
			continue
		var target := body as BaseCharacter
		if target.faction == _caster.faction:
			continue
		if not target.is_targetable():
			continue
		if _hit_targets.has(target):
			continue

		_hit_targets.append(target)
		var result := CombatManager.calculate_damage(
			_caster.stats, target.stats, _base_damage,
			_damage_type, _skill_multiplier)
		target.take_damage(result)

		hit_count += 1
		if _max_targets > 0 and hit_count >= _max_targets:
			break

	_spawn_hit_vfx(global_position)


func _spawn_hit_vfx(_impact_position: Vector3) -> void:
	# Override in subclasses to spawn explosion particles, etc.
	pass


func _expire() -> void:
	# Override to add dissipation VFX.
	queue_free()


func _impact() -> void:
	# Stop movement.
	set_physics_process(false)
	velocity = Vector3.ZERO
	# Optionally play impact animation before freeing.
	queue_free()
