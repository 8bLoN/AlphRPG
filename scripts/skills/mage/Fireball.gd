# Fireball.gd
# =============================================================================
# Mage active skill — FIREBALL
# Launches a projectile toward the target position. On impact it explodes,
# dealing fire damage to all enemies within the explosion radius.
#
# SKILL DATA (configure in mage_fireball.tres):
#   id:              "mage_fireball"
#   base_damage:     40.0
#   damage_per_rank: 20.0
#   base_cost:       30.0   (mana)
#   base_cooldown:   1.5
#   cast_time:       0.3
#   aoe_radius:      80.0   (explosion radius)
#   max_targets:     0
#   damage_type:     1      (CombatManager.DamageType.FIRE)
#   skill_multiplier: 1.2
#   animation_name:  "cast"
#   skill_scene:     preload("res://scenes/skills/FireballProjectile.tscn")
#
# SCALING: Fire spell — scales with spell_power (INT-based) + fire_damage_bonus.
# =============================================================================
class_name Fireball
extends BaseSkill


func _execute(caster: BaseCharacter, target_position: Vector3) -> void:
	if data.skill_scene == null:
		push_error("Fireball: skill_scene (FireballProjectile.tscn) not set.")
		return

	# Instantiate the projectile in the world.
	var projectile: BaseProjectile = data.skill_scene.instantiate()
	caster.get_parent().add_child(projectile)
	projectile.global_position = caster.global_position

	# Configure the projectile with this skill's parameters.
	projectile.setup(
		caster,
		target_position,
		data.get_damage_at_rank(rank),
		CombatManager.DamageType.FIRE,
		data.skill_multiplier,
		data.aoe_radius if data.aoe_radius > 0.0 else 80.0,
		data.max_targets
	)

	# Cast VFX at caster's hands.
	if data.cast_vfx_scene:
		var vfx: Node = data.cast_vfx_scene.instantiate()
		caster.add_child(vfx)
