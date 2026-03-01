# FireballProjectile.gd
# =============================================================================
# Fireball projectile. Extends BaseProjectile with:
#   • Screen shake on impact
#   • Scorch mark decal spawning
#   • Fire trail particles while in flight
# Attach this script to res://scenes/skills/FireballProjectile.tscn
# =============================================================================
class_name FireballProjectile
extends BaseProjectile

## Scene to spawn as a scorch decal on the ground after impact.
@export var scorch_scene: PackedScene = null

## Screen shake magnitude on impact (set > 0 when Camera2D shake is implemented).
const IMPACT_SHAKE: float = 6.0


func _spawn_hit_vfx(impact_position: Vector3) -> void:
	# Spawn scorch mark (stays on ground).
	if scorch_scene:
		var scorch: Node = scorch_scene.instantiate()
		get_parent().add_child(scorch)
		scorch.global_position = impact_position

	# Request screen shake via EventBus (Camera2D subscribes to this).
	# EventBus.screen_shake_requested.emit(IMPACT_SHAKE, 0.3)

	# Floating text showing it was a fire hit.
	EventBus.floating_text_requested.emit(impact_position, "FIRE!", Color(1.0, 0.4, 0.0))
