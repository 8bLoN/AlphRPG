# EnemyAI.gd
# =============================================================================
# Behaviour controller for enemy characters (3D version).
# Three-phase FSM: PATROL → AGGRO → ATTACK
# =============================================================================
class_name EnemyAI
extends Node

enum Phase { PATROL, AGGRO, ATTACK }

var _character: EnemyCharacter = null
var _data: EnemyData = null

var _phase: Phase = Phase.PATROL
var _target: BaseCharacter = null
var _spawn_position: Vector3 = Vector3.ZERO
var _patrol_target: Vector3 = Vector3.ZERO
var _patrol_wait: float = 0.0
var _attack_timer: float = 0.0

const ATTACK_RHYTHM: float = 0.5

func _init(character: EnemyCharacter, enemy_data: EnemyData) -> void:
	_character = character
	_data = enemy_data


func _ready() -> void:
	_spawn_position = _character.global_position
	_patrol_target = _spawn_position
	_pick_new_patrol_target()


func _process(delta: float) -> void:
	if not _character.is_alive:
		return

	_attack_timer = maxf(0.0, _attack_timer - delta)

	match _phase:
		Phase.PATROL:
			_process_patrol(delta)
		Phase.AGGRO:
			_process_aggro(delta)
		Phase.ATTACK:
			_process_attack(delta)


func _process_patrol(delta: float) -> void:
	_target = _find_target()
	if _target:
		_enter_aggro()
		return

	var dist_to_wp := _character.global_position.distance_to(_patrol_target)
	if dist_to_wp < 2.0:
		_patrol_wait -= delta
		if _patrol_wait <= 0.0:
			_pick_new_patrol_target()
	else:
		_character.move_to(_patrol_target)


func _pick_new_patrol_target() -> void:
	var radius := (_data.patrol_radius if _data else 200.0) * BaseCharacter.WORLD_SCALE
	var angle := randf() * TAU
	var dist := randf_range(3.0, radius)
	_patrol_target = _spawn_position + Vector3(cos(angle), 0.0, sin(angle)) * dist
	_patrol_wait = _data.patrol_wait_time if _data else 2.0


func _process_aggro(_delta: float) -> void:
	if not _is_valid_target(_target):
		_enter_patrol()
		return

	var dist := _character.global_position.distance_to(_target.global_position)
	var deaggro_radius := (_data.deaggro_radius if _data else 500.0) * BaseCharacter.WORLD_SCALE
	if dist > deaggro_radius:
		_enter_patrol()
		return

	var attack_range := (_data.attack_range if _data else 80.0) * BaseCharacter.WORLD_SCALE
	if dist <= attack_range:
		_enter_attack()
		return

	_character.move_to(_target.global_position)


func _process_attack(_delta: float) -> void:
	if not _is_valid_target(_target):
		_enter_patrol()
		return

	var dist := _character.global_position.distance_to(_target.global_position)
	var attack_range := (_data.attack_range if _data else 80.0) * BaseCharacter.WORLD_SCALE

	if dist > attack_range * 1.2:
		_enter_aggro()
		return

	_character.velocity = Vector3.ZERO

	# Face the target.
	var diff := _target.global_position - _character.global_position
	var dir := Vector3(diff.x, 0.0, diff.z).normalized()
	if dir.length() > 0.1 and _character.has_node("VisualRoot"):
		_character.get_node("VisualRoot").rotation.y = atan2(dir.x, dir.z)

	if _attack_timer <= 0.0:
		_perform_attack()


func _enter_patrol() -> void:
	_phase = Phase.PATROL
	_target = null
	_pick_new_patrol_target()


func _enter_aggro() -> void:
	_phase = Phase.AGGRO


func _enter_attack() -> void:
	_phase = Phase.ATTACK
	_attack_timer = 0.0


func _perform_attack() -> void:
	if _target == null or not _target.is_targetable():
		return

	var used_skill := false
	if _character.skill_tree:
		for skill_id: String in _character.skill_tree.get_learned_skill_ids():
			var skill := _character.skill_tree.get_skill_instance(skill_id)
			if skill and skill.can_activate(_character):
				_character.use_skill(0, _target.global_position)
				used_skill = true
				break

	if not used_skill:
		var base_dmg := randf_range(
			_character.stats.get_stat("min_damage"),
			_character.stats.get_stat("max_damage"))
		var result := CombatManager.calculate_damage(
			_character.stats,
			_target.stats,
			base_dmg,
			CombatManager.DamageType.PHYSICAL)
		_target.take_damage(result)
		_character.state_machine.transition_to("attack")

	var atk_spd := _character.stats.get_stat("attack_speed")
	_attack_timer = 1.0 / maxf(atk_spd, 0.1)


func _find_target() -> BaseCharacter:
	var aggro_radius := (_data.aggro_radius if _data else 300.0) * BaseCharacter.WORLD_SCALE
	var space := _character.get_world_3d().direct_space_state
	var params := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = aggro_radius
	params.shape = sphere
	params.transform = Transform3D(Basis.IDENTITY, _character.global_position)
	params.collision_mask = 4  # Character layer.

	for res in space.intersect_shape(params):
		var body: Node = res.collider
		if body is Area3D:
			body = body.get_parent()
		if not (body is BaseCharacter):
			continue
		var candidate := body as BaseCharacter
		if candidate.faction == _character.faction:
			continue
		if not candidate.is_targetable():
			continue
		return candidate

	return null


func _is_valid_target(target: BaseCharacter) -> bool:
	return is_instance_valid(target) and target.is_targetable()
