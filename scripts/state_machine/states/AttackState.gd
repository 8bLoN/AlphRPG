# AttackState.gd
# =============================================================================
# Character is executing a basic (auto) attack.
# Uses a tween-based forward-lean animation (no AnimationPlayer required).
# Transitions to idle automatically when the swing tween finishes.
# =============================================================================
class_name AttackState
extends CharacterState

var _tween: Tween = null


func enter() -> void:
	# Face attack target direction.
	if character.has_method("get_attack_target_position"):
		var target_pos: Vector3 = character.get_attack_target_position()
		var diff: Vector3 = target_pos - character.global_position
		var dir: Vector3 = Vector3(diff.x, 0.0, diff.z).normalized()
		if dir.length() > 0.1 and character.has_node("VisualRoot"):
			character.get_node("VisualRoot").rotation.y = atan2(dir.x, dir.z)

	# Tween weapon swing: lean forward then spring back.
	_tween = character.create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	var vroot: Node3D = character.get_node_or_null("VisualRoot") as Node3D
	if vroot:
		_tween.tween_property(vroot, "rotation:x", -0.5, 0.12)
		_tween.tween_property(vroot, "rotation:x", 0.0, 0.2)
	else:
		_tween.tween_interval(0.32)
	_tween.tween_callback(_finish_attack)


func exit() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null
	var vroot: Node3D = character.get_node_or_null("VisualRoot") as Node3D
	if vroot:
		vroot.rotation.x = 0.0


func _finish_attack() -> void:
	transition_to("idle")
