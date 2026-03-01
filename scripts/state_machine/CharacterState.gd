# CharacterState.gd
# =============================================================================
# Abstract base class for all character FSM states.
# Subclass this for every behaviour (Idle, Move, Attack, Cast, Hit, Dead).
#
# The character reference gives states direct access to the character node,
# its stats, animation player, and navigation agent.
# =============================================================================
class_name CharacterState
extends RefCounted

## Back-reference to the owning character node.
var character: Node = null

## Back-reference to the FSM (for requesting transitions).
var state_machine: StateMachine = null


func _init(p_character: Node) -> void:
	character = p_character

# ─── Lifecycle ────────────────────────────────────────────────────────────────

## Called by the FSM before entering this state.
## Return false to block the transition (guard condition).
func can_enter() -> bool:
	return true


## Called when this state becomes active.
func enter() -> void:
	pass


## Called when this state is being exited.
func exit() -> void:
	pass


## Called every frame while this state is active (_process).
func update(_delta: float) -> void:
	pass


## Called every physics frame while this state is active (_physics_process).
func physics_update(_delta: float) -> void:
	pass

# ─── Helpers ─────────────────────────────────────────────────────────────────

## Shorthand: play an animation on the character's AnimationPlayer.
func play_animation(anim_name: String, blend: float = -1.0) -> void:
	if character.animation_player and character.animation_player.has_animation(anim_name):
		if blend >= 0.0:
			character.animation_player.play(anim_name, blend)
		else:
			character.animation_player.play(anim_name)


## Shorthand: request a state transition through the FSM.
func transition_to(state_name: String) -> void:
	state_machine.transition_to(state_name)


## Shorthand: force a state transition (bypasses can_enter guard).
func force_transition(state_name: String) -> void:
	state_machine.force_transition_to(state_name)
