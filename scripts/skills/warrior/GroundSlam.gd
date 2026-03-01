# GroundSlam.gd
# =============================================================================
# Warrior active skill — GROUND SLAM
# The Warrior slams the ground with their weapon, dealing physical AoE damage
# around themselves and applying a 1-second slow to all hit enemies.
#
# SKILL DATA (configure in warrior_groundslam.tres):
#   id:              "warrior_ground_slam"
#   base_damage:     30.0
#   damage_per_rank: 15.0
#   base_cost:       20.0   (mana)
#   base_cooldown:   6.0
#   aoe_radius:      150.0
#   max_targets:     0      (unlimited)
#   skill_multiplier: 1.0
#   animation_name:  "slam"
#
# SCALING: Physical — scales with Strength via physical_damage_bonus.
# =============================================================================
class_name GroundSlam
extends BaseSkill

## Slow effect duration (seconds) applied to hit enemies.
const SLOW_DURATION: float = 1.0

## Movement speed reduction on hit targets (percentage).
const SLOW_AMOUNT: float = 40.0


func _execute(caster: BaseCharacter, _target_position: Vector3) -> void:
	# Ground slam hits around the caster (target_position ignored — self-centred AoE).
	var radius := data.aoe_radius if data.aoe_radius > 0.0 else 150.0
	var targets := get_targets_in_radius(caster.global_position, radius, caster)

	var base_dmg := data.get_damage_at_rank(rank)

	for target: BaseCharacter in targets:
		# Calculate and apply damage.
		var result := CombatManager.calculate_damage(
			caster.stats,
			target.stats,
			base_dmg,
			CombatManager.DamageType.PHYSICAL,
			data.skill_multiplier
		)
		target.take_damage(result)

		# Apply slow debuff.
		var slow_mod := StatModifier.new(
			"buff/ground_slam_slow",
			"movement_speed",
			-SLOW_AMOUNT,
			StatModifier.Type.PERCENT_ADD,
			SLOW_DURATION
		)
		slow_mod.display_label = "-%.0f%% Movement Speed (Slowed)" % SLOW_AMOUNT

		target.apply_effect({
			"id": "ground_slam_slow",
			"duration": SLOW_DURATION,
			"modifiers": [slow_mod],
		})

	# Spawn VFX at caster's position.
	if data.cast_vfx_scene:
		var vfx: Node = data.cast_vfx_scene.instantiate()
		caster.get_parent().add_child(vfx)
		vfx.global_position = caster.global_position
