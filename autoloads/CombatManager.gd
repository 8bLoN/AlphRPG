# CombatManager.gd
# =============================================================================
# The single authoritative source for all damage calculation logic.
# No character script should compute damage on its own — always delegate here.
#
# PIPELINE (in order):
#   1. base_damage × skill_multiplier
#   2. Stat scaling added (strength bonus, spell power, etc.)
#   3. Critical hit roll (crit_chance → crit_multiplier)
#   4. Resistance / armor reduction on the TARGET side
#   5. Minimum damage guarantee
#
# EXTENDING:
#   • Add new DamageType entries and matching resistance stats.
#   • Add block / parry check between steps 3 and 4.
#   • Add damage-over-time helpers (tick_damage_result) using the same pipeline.
# =============================================================================
extends Node

# ─── Damage Types ─────────────────────────────────────────────────────────────

enum DamageType {
	PHYSICAL,
	FIRE,
	COLD,
	LIGHTNING,
	POISON,
	ARCANE,
	PURE,      # Bypasses all resistances (true damage).
}

# ─── Global Constants ─────────────────────────────────────────────────────────

## Resistance percentage cap. No character can exceed this via equipment.
const MAX_RESISTANCE: float = 75.0

## No hit may deal less than this amount (prevents totally immune scenarios).
const MIN_DAMAGE: float = 1.0

## Armor damage reduction formula constant (tunable).
## Formula: reduction% = armor / (armor + ARMOR_K * attacker_level)
const ARMOR_K: float = 50.0

# ─── Main API ─────────────────────────────────────────────────────────────────

## Calculate a full damage result from attacker → target.
##
## Returns a Dictionary with keys:
##   "raw_damage"    – base_damage before any modification
##   "final_damage"  – damage after all reductions (what gets subtracted from HP)
##   "is_crit"       – bool
##   "is_blocked"    – bool (currently false; extend for shield block)
##   "damage_type"   – DamageType int
##   "absorbed"      – amount removed by resistances/armor
##   "skill_mult"    – skill_multiplier that was applied
func calculate_damage(
		attacker_stats: Object,        # CharacterStats instance
		target_stats: Object,          # CharacterStats instance
		base_damage: float,
		damage_type: DamageType = DamageType.PHYSICAL,
		skill_multiplier: float = 1.0,
		bonus_crit_chance: float = 0.0) -> Dictionary:

	var result: Dictionary = {
		"raw_damage": base_damage,
		"final_damage": 0.0,
		"is_crit": false,
		"is_blocked": false,
		"damage_type": damage_type,
		"absorbed": 0.0,
		"skill_mult": skill_multiplier,
	}

	# Step 1 — Skill multiplier.
	var damage: float = base_damage * skill_multiplier

	# Step 2 — Attacker stat bonuses.
	damage = _apply_attacker_scaling(damage, attacker_stats, damage_type)

	# Step 3 — Critical hit.
	var crit_roll: float = attacker_stats.get_stat("crit_chance") + bonus_crit_chance
	if randf() * 100.0 < crit_roll:
		result["is_crit"] = true
		damage *= attacker_stats.get_stat("crit_multiplier") / 100.0
		EventBus.critical_hit.emit(null, null, damage)  # Emitter fills attacker/target.

	# Step 4 — Target resistance / armor reduction.
	var absorbed: float = _compute_absorption(damage, target_stats, attacker_stats, damage_type)
	result["absorbed"] = absorbed
	damage -= absorbed

	# Step 5 — Minimum damage guarantee (skip for PURE damage).
	if damage_type != DamageType.PURE:
		damage = max(damage, MIN_DAMAGE)

	result["final_damage"] = damage
	return result


## Apply a pre-calculated damage result to a target's stats.
## Call this after calculate_damage() to actually subtract HP.
## Returns the actual damage dealt.
func apply_damage(target: Node, damage_result: Dictionary) -> float:
	if not is_instance_valid(target):
		return 0.0

	var actual: float = target.stats.apply_damage(damage_result["final_damage"])

	# Life steal — applies to physical damage only by default.
	# Extend this block for "elemental life steal" items.
	# (attacker reference must be passed in; omitted here for brevity)

	return actual


## Convenience: calculate AND apply in one call.
func deal_damage(
		attacker: Node,
		target: Node,
		base_damage: float,
		damage_type: DamageType = DamageType.PHYSICAL,
		skill_multiplier: float = 1.0,
		bonus_crit_chance: float = 0.0) -> Dictionary:

	if not is_instance_valid(attacker) or not is_instance_valid(target):
		return {}

	var result := calculate_damage(
		attacker.stats,
		target.stats,
		base_damage,
		damage_type,
		skill_multiplier,
		bonus_crit_chance)

	apply_damage(target, result)

	EventBus.hit_landed.emit(attacker, target, result)
	EventBus.character_damaged.emit(target, result)
	EventBus.show_damage_number.emit(
		target.global_position,
		result["final_damage"],
		result["is_crit"],
		DamageType.keys()[damage_type])

	return result


## Calculate a heal amount (optionally boosted by caster's healing power).
func calculate_healing(caster_stats: Object, base_heal: float, heal_multiplier: float = 1.0) -> float:
	# Future: add "healing_bonus" stat for paladin-style classes.
	return max(base_heal * heal_multiplier, 0.0)

# ─── Internal Helpers ─────────────────────────────────────────────────────────

func _apply_attacker_scaling(damage: float, stats: Object, dtype: DamageType) -> float:
	match dtype:
		DamageType.PHYSICAL:
			damage += stats.get_stat("physical_damage_bonus")
		DamageType.FIRE:
			damage += stats.get_stat("spell_damage_bonus") + stats.get_stat("fire_damage_bonus")
		DamageType.COLD:
			damage += stats.get_stat("spell_damage_bonus") + stats.get_stat("cold_damage_bonus")
		DamageType.LIGHTNING:
			damage += stats.get_stat("spell_damage_bonus") + stats.get_stat("lightning_damage_bonus")
		DamageType.POISON:
			damage += stats.get_stat("poison_damage_bonus")
		DamageType.ARCANE:
			damage += stats.get_stat("spell_damage_bonus")
	return damage


func _compute_absorption(damage: float, target_stats: Object, attacker_stats: Object, dtype: DamageType) -> float:
	var resistance: float = 0.0

	match dtype:
		DamageType.PHYSICAL:
			# Diablo-style armor formula. Scales well against all levels.
			var armor: float = target_stats.get_stat("armor")
			var lvl: float = float(attacker_stats.level)
			resistance = (armor / (armor + ARMOR_K * lvl)) * 100.0
		DamageType.FIRE:
			resistance = minf(target_stats.get_stat("fire_resistance"), MAX_RESISTANCE)
		DamageType.COLD:
			resistance = minf(target_stats.get_stat("cold_resistance"), MAX_RESISTANCE)
		DamageType.LIGHTNING:
			resistance = minf(target_stats.get_stat("lightning_resistance"), MAX_RESISTANCE)
		DamageType.POISON:
			resistance = minf(target_stats.get_stat("poison_resistance"), MAX_RESISTANCE)
		DamageType.PURE:
			resistance = 0.0

	return damage * (resistance / 100.0)
