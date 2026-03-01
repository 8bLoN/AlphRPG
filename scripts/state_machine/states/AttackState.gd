# AttackState.gd
# =============================================================================
# Character is executing a basic (auto) attack.
# The attack actually connects at the animation's hit frame via an
# AnimationPlayer track calling character.on_attack_hit().
# Transitions to idle when the animation finishes.
# =============================================================================
class_name AttackState
extends CharacterState


func enter() -> void:
	play_animation("attack")

	# Face attack target direction if set.
	if character.has_method("get_attack_target_position"):
		var target_pos: Vector3 = character.get_attack_target_position()
		var diff: Vector3 = target_pos - character.global_position
		var dir: Vector3 = Vector3(diff.x, 0.0, diff.z).normalized()
		if dir.length() > 0.1 and character.has_node("VisualRoot"):
			character.get_node("VisualRoot").rotation.y = atan2(dir.x, dir.z)

	# Listen for animation completion.
	var ap: AnimationPlayer = character.animation_player
	if ap and not ap.animation_finished.is_connected(_on_animation_finished):
		ap.animation_finished.connect(_on_animation_finished, CONNECT_ONE_SHOT)


func exit() -> void:
	# Disconnect listener if still connected (e.g., state was forced out).
	var ap: AnimationPlayer = character.animation_player
	if ap and ap.animation_finished.is_connected(_on_animation_finished):
		ap.animation_finished.disconnect(_on_animation_finished)


func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "attack":
		transition_to("idle")
