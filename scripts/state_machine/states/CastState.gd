# CastState.gd
class_name CastState
extends CharacterState


func enter() -> void:
	character.velocity = Vector3.ZERO

	var anim_name: String = "cast"
	if character.active_skill and character.active_skill.data:
		var override: String = character.active_skill.data.animation_name
		if override.length() > 0:
			anim_name = override

	play_animation(anim_name)

	# Face the skill's target position.
	if character.has_method("get_skill_target_position"):
		var target_pos: Vector3 = character.get_skill_target_position()
		var diff: Vector3 = target_pos - character.global_position
		var dir: Vector3 = Vector3(diff.x, 0.0, diff.z).normalized()
		if dir.length() > 0.1 and character.has_node("VisualRoot"):
			character.get_node("VisualRoot").rotation.y = atan2(dir.x, dir.z)


func physics_update(_delta: float) -> void:
	character.velocity = Vector3.ZERO
	character.move_and_slide()
