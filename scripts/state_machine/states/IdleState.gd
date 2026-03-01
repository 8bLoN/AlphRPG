# IdleState.gd
# =============================================================================
# Character is standing still, waiting for input or AI commands.
# Plays the idle animation loop and zeroes out velocity.
# =============================================================================
class_name IdleState
extends CharacterState


func enter() -> void:
	play_animation("idle")
	# Stop all movement immediately.
	character.velocity = Vector3.ZERO


func physics_update(_delta: float) -> void:
	# For player: movement input is handled by PlayerCharacter directly
	# and transitions out of idle. For enemy: EnemyAI manages transitions.
	# Idle just ensures velocity stays zero while we wait.
	character.velocity = Vector3.ZERO
	character.move_and_slide()
