# MoveState.gd
# =============================================================================
# Character is moving along a navigation path.
# Drives NavigationAgent3D and applies velocity each physics frame.
# Transitions back to idle when the path is complete.
# =============================================================================
class_name MoveState
extends CharacterState

## Minimum distance to target before we consider arrival complete (world units).
const ARRIVAL_THRESHOLD: float = 0.8


func enter() -> void:
	play_animation("run")


func physics_update(_delta: float) -> void:
	var nav: NavigationAgent3D = character.navigation_agent
	var speed: float = character.stats.get_stat("movement_speed") * BaseCharacter.WORLD_SCALE
	var direction: Vector3 = Vector3.ZERO

	if nav != null and not nav.is_navigation_finished():
		# Navigate via path.
		var next_pos: Vector3 = nav.get_next_path_position()
		var flat_to_next := Vector3(next_pos.x - character.global_position.x, 0.0,
				next_pos.z - character.global_position.z)
		direction = flat_to_next.normalized()
	elif character._move_target != Vector3.ZERO:
		# Direct movement fallback (no NavigationRegion baked, or nav unavailable).
		var to_target: Vector3 = character._move_target - character.global_position
		to_target.y = 0.0
		if to_target.length() < ARRIVAL_THRESHOLD:
			character._move_target = Vector3.ZERO
			transition_to("idle")
			return
		direction = to_target.normalized()
	else:
		transition_to("idle")
		return

	character.velocity = direction * speed

	# Rotate VisualRoot to face movement direction.
	var vroot: Node3D = character.get_node_or_null("VisualRoot") as Node3D
	if direction.length() > 0.1 and vroot:
		vroot.rotation.y = atan2(direction.x, direction.z)

	character.move_and_slide()

	# Check nav arrival.
	if nav != null and not nav.is_navigation_finished():
		var flat_diff := Vector3(character.global_position.x - nav.target_position.x,
				0.0, character.global_position.z - nav.target_position.z)
		var flat_dist := flat_diff.length()
		if flat_dist < ARRIVAL_THRESHOLD:
			nav.target_position = character.global_position
			character._move_target = Vector3.ZERO
			transition_to("idle")
