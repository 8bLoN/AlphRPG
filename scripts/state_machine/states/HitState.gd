# HitState.gd
# =============================================================================
# Brief stagger played when the character takes damage.
# Duration is driven by the "hit" animation length.
# Heavy hits or stuns can extend this state externally.
# =============================================================================
class_name HitState
extends CharacterState

## Fallback duration (seconds) if no "hit" animation exists.
const FALLBACK_DURATION: float = 0.2

var _timer: float = 0.0


func can_enter() -> bool:
	# Cannot enter hit state if already dead.
	return character.is_alive


func enter() -> void:
	_timer = 0.0
	play_animation("hit")

	var ap: AnimationPlayer = character.animation_player
	if ap and ap.has_animation("hit"):
		# Use the real animation length so we exit exactly when it ends.
		_timer = ap.get_animation("hit").length
	else:
		_timer = FALLBACK_DURATION


func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		transition_to("idle")
