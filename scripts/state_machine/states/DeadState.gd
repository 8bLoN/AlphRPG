# DeadState.gd
# =============================================================================
# Terminal state — plays the death animation and disables all further input.
# Once in DeadState the character cannot transition to any other state.
# The character node itself is eventually freed by the scene that owns it.
# =============================================================================
class_name DeadState
extends CharacterState


func can_enter() -> bool:
	# Always allow entering dead state (it's a forced transition).
	return true


func enter() -> void:
	play_animation("death")
	character.velocity = Vector3.ZERO

	# Disable physics processing to stop all movement.
	character.set_physics_process(false)

	# Disable collision so the corpse doesn't block pathfinding.
	if character.has_node("CollisionShape3D"):
		character.get_node("CollisionShape3D").set_deferred("disabled", true)

	# Notify the game that this character has died.
	EventBus.character_died.emit(character)


func exit() -> void:
	# Dead state should never be exited during normal gameplay.
	push_warning("DeadState: Unexpected exit from dead state on '%s'." % character.name)
