# PoisonDagger.gd
# =============================================================================
# Rogue active skill — POISON DAGGER
# A fast melee thrust that deals immediate physical damage and applies a
# stacking poison DoT (damage-over-time) effect. High crit synergy.
#
# SKILL DATA (configure in rogue_poisondagger.tres):
#   id:              "rogue_poison_dagger"
#   base_damage:     15.0
#   damage_per_rank: 8.0
#   base_cost:       12.0   (mana)
#   base_cooldown:   0.8
#   damage_type:     0      (PHYSICAL for initial hit)
#   skill_multiplier: 1.0
#   animation_name:  "attack"
#   max_targets:     1
#
# POISON DOT:
#   Each rank adds more poison damage per second and extends duration.
#   Poison stacks (each cast is a separate effect instance with a unique ID).
# =============================================================================
class_name PoisonDagger
extends BaseSkill

## Base poison damage per tick (per rank).
const POISON_DPS_BASE: float = 8.0
const POISON_DPS_PER_RANK: float = 5.0

## Tick interval in seconds.
const POISON_TICK: float = 1.0

## Duration in seconds (grows with rank).
const POISON_DURATION_BASE: float = 3.0
const POISON_DURATION_PER_RANK: float = 1.0

## Stack counter for unique effect IDs (allows multiple poisons from multiple casts).
var _stack_counter: int = 0


func _execute(caster: BaseCharacter, target_position: Vector3) -> void:
	# Find the nearest enemy within melee range of the target position.
	var targets := get_targets_in_radius(target_position, 80.0, caster)

	if targets.is_empty():
		# No target — try from caster position.
		targets = get_targets_in_radius(caster.global_position, 100.0, caster)

	if targets.is_empty():
		return

	var target := targets[0]

	# Initial physical hit (high crit bonus for Rogue).
	var base_dmg := data.get_damage_at_rank(rank)
	var bonus_crit := 15.0  # Poison Dagger has inherent high crit chance.
	var result := CombatManager.calculate_damage(
		caster.stats,
		target.stats,
		base_dmg,
		CombatManager.DamageType.PHYSICAL,
		data.skill_multiplier,
		bonus_crit
	)
	target.take_damage(result)

	# Apply a stacking poison DoT.
	_stack_counter += 1
	var effect_id := "rogue_poison_%d" % _stack_counter
	var poison_dps := POISON_DPS_BASE + POISON_DPS_PER_RANK * (rank - 1)
	var poison_dur := POISON_DURATION_BASE + POISON_DURATION_PER_RANK * (rank - 1)

	target.apply_effect({
		"id": effect_id,
		"duration": poison_dur,
		"modifiers": [],            # No stat changes, just damage.
		"tick_damage": poison_dps,
		"tick_interval": POISON_TICK,
		"damage_type": CombatManager.DamageType.POISON,
	})

	# Floating text to communicate the poison application.
	EventBus.floating_text_requested.emit(
		target.global_position + Vector3(0, 2, 0),
		"Poisoned!",
		Color(0.4, 0.9, 0.2)
	)

	# VFX.
	if data.cast_vfx_scene:
		var vfx: Node = data.cast_vfx_scene.instantiate()
		caster.get_parent().add_child(vfx)
		vfx.global_position = target.global_position
