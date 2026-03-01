# CharacterStats.gd
# =============================================================================
# The core statistics engine for every character in the game.
# This class is the most critical piece of the ARPG foundation.
#
# DESIGN DECISIONS:
#   • Primary stats (STR/DEX/INT/VIT) are raw integers set by the player.
#   • All derived stats (max_hp, armor, damage, etc.) are computed lazily via
#     a dirty-flag pattern: _mark_dirty() sets _dirty = true, and any call to
#     get_stat() triggers _recompute_all() if dirty.
#   • Modifiers are indexed TWICE for performance:
#       _mods_by_id   → O(1) removal by ID
#       _mods_by_stat → O(n) per-stat modifier lookup during compute
#   • Signals are emitted for each changed stat so UI components can bind
#     without polling.
#
# EXTENDING:
#   • Add new derived stat names to the _base_stat_names list and implement
#     their formula in _compute_base().
#   • Override _compute_base() in a subclass for class-specific scaling,
#     OR pass a CharacterClassData resource to initialize_from_class_data().
# =============================================================================
class_name CharacterStats
extends RefCounted

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted when any computed (derived) stat changes. Drives UI updates.
signal stat_changed(stat_name: String, old_value: float, new_value: float)

## Emitted frequently — subscribers should be lightweight.
signal hp_changed(current: float, maximum: float)

signal mana_changed(current: float, maximum: float)

## Emitted once when HP first reaches 0.
signal died()

# ─── Primary Stats ────────────────────────────────────────────────────────────
# Setters mark dirty so derived stats are recalculated on next access.

var strength: int = 10:
	set(v):
		strength = maxi(1, v)
		_mark_dirty()

var dexterity: int = 10:
	set(v):
		dexterity = maxi(1, v)
		_mark_dirty()

var intelligence: int = 10:
	set(v):
		intelligence = maxi(1, v)
		_mark_dirty()

var vitality: int = 10:
	set(v):
		vitality = maxi(1, v)
		_mark_dirty()

## Character level affects all base stat formulas.
var level: int = 1:
	set(v):
		level = maxi(1, v)
		_mark_dirty()

# ─── Scaling Overrides (from CharacterClassData) ──────────────────────────────
# These let each class have unique scaling without subclassing CharacterStats.

var _hp_per_vitality: float = 5.0
var _mana_per_intelligence: float = 3.0
var _armor_per_strength: float = 0.3

# ─── Mutable Resources (HP / Mana) ───────────────────────────────────────────
# These change constantly and have custom setters for clamping and signals.

var _hp: float = -1.0    # -1 = uninitialized; set to max on first compute.
var _mana: float = -1.0

var current_hp: float:
	get:
		if _hp < 0.0:
			_ensure_computed()
			_hp = _cache.get("max_hp", 100.0)
		return _hp
	set(v):
		var prev := _hp
		_hp = clampf(v, 0.0, get_stat("max_hp"))
		hp_changed.emit(_hp, get_stat("max_hp"))
		if _hp <= 0.0 and prev > 0.0:
			died.emit()

var current_mana: float:
	get:
		if _mana < 0.0:
			_ensure_computed()
			_mana = _cache.get("max_mana", 50.0)
		return _mana
	set(v):
		_mana = clampf(v, 0.0, get_stat("max_mana"))
		mana_changed.emit(_mana, get_stat("max_mana"))

# ─── Modifier Storage ─────────────────────────────────────────────────────────

## All modifiers, keyed by ID for O(1) removal.
var _mods_by_id: Dictionary = {}

## Modifiers grouped by the stat they affect for fast compute-pass lookup.
var _mods_by_stat: Dictionary = {}

# ─── Cache ────────────────────────────────────────────────────────────────────

var _dirty: bool = true
var _cache: Dictionary = {}

## Complete list of derived stat names. Add entries here when adding new stats.
## This list drives both _recompute_all() and get_all_stat_names().
const _BASE_STAT_NAMES: Array[String] = [
	"max_hp", "max_mana",
	"min_damage", "max_damage",
	"armor",
	"crit_chance", "crit_multiplier",
	"attack_speed", "movement_speed",
	"hp_regen", "mana_regen",
	"evasion",
	"spell_power",
	"physical_damage_bonus", "spell_damage_bonus",
	"fire_damage_bonus", "cold_damage_bonus",
	"lightning_damage_bonus", "poison_damage_bonus",
	"fire_resistance", "cold_resistance",
	"lightning_resistance", "poison_resistance",
	"life_steal",
	"item_find_bonus",
]

# ─── Initialisation ──────────────────────────────────────────────────────────

## Apply a CharacterClassData resource to set base scaling values and primary stats.
func initialize_from_class_data(class_data: CharacterClassData) -> void:
	_hp_per_vitality = class_data.hp_per_vitality
	_mana_per_intelligence = class_data.mana_per_intelligence
	_armor_per_strength = class_data.armor_per_strength

	strength = class_data.base_strength
	dexterity = class_data.base_dexterity
	intelligence = class_data.base_intelligence
	vitality = class_data.base_vitality

	_mark_dirty()
	restore_full()


## Apply automatic per-level growth from class data (called on level-up).
func apply_level_growth(class_data: CharacterClassData) -> void:
	strength += int(class_data.strength_per_level)
	dexterity += int(class_data.dexterity_per_level)
	intelligence += int(class_data.intelligence_per_level)
	vitality += int(class_data.vitality_per_level)
	# (Fractional parts handled by caller accumulating a float remainder.)

# ─── Public Stat API ─────────────────────────────────────────────────────────

## Returns the final (post-modifier) value of a named stat.
func get_stat(stat_name: String) -> float:
	_ensure_computed()
	return _cache.get(stat_name, 0.0)


## Returns only the base value before modifiers (useful for tooltip breakdown).
func get_base_stat(stat_name: String) -> float:
	return _compute_base(stat_name)


## Returns all computed stat values as a Dictionary (for serialisation / debug).
func get_all_stats() -> Dictionary:
	_ensure_computed()
	return _cache.duplicate()


## List of all trackable stat names (convenience for UI builders).
func get_all_stat_names() -> Array[String]:
	return _BASE_STAT_NAMES.duplicate()

# ─── Modifier API ────────────────────────────────────────────────────────────

## Add (or replace) a modifier. Identical IDs are replaced, not stacked.
func add_modifier(modifier: StatModifier) -> void:
	# Remove any existing modifier with the same ID first.
	if _mods_by_id.has(modifier.id):
		_remove_internal(modifier.id)

	_mods_by_id[modifier.id] = modifier

	if not _mods_by_stat.has(modifier.stat):
		_mods_by_stat[modifier.stat] = []
	_mods_by_stat[modifier.stat].append(modifier)

	_mark_dirty()


## Remove a modifier by its unique ID.
func remove_modifier(modifier_id: String) -> void:
	if _mods_by_id.has(modifier_id):
		_remove_internal(modifier_id)
		_mark_dirty()


## Remove ALL modifiers whose IDs begin with source_prefix.
## e.g. remove_modifiers_by_source("item/") clears all equipment bonuses.
func remove_modifiers_by_source(source_prefix: String) -> void:
	var to_remove: Array[String] = []
	for mid: String in _mods_by_id:
		if mid.begins_with(source_prefix):
			to_remove.append(mid)

	if to_remove.is_empty():
		return

	for mid in to_remove:
		_remove_internal(mid)
	_mark_dirty()


## Returns all modifier display strings for a stat (tooltip breakdown).
func get_modifier_breakdown(stat_name: String) -> Array[String]:
	var result: Array[String] = []
	if _mods_by_stat.has(stat_name):
		for mod: StatModifier in _mods_by_stat[stat_name]:
			result.append(mod.to_display_string())
	return result

# ─── Resource Spending ────────────────────────────────────────────────────────

## Subtract HP. Returns actual damage applied (may be less than amount if near death).
func apply_damage(amount: float) -> float:
	var actual := minf(amount, current_hp)
	current_hp -= actual
	return actual


## Restore HP. Returns actual heal applied.
func apply_healing(amount: float) -> float:
	var max_hp := get_stat("max_hp")
	var actual := minf(amount, max_hp - current_hp)
	current_hp += actual
	return actual


## Subtract mana. Returns false without modifying state if insufficient mana.
func spend_mana(amount: float) -> bool:
	if current_mana < amount:
		return false
	current_mana -= amount
	return true


## Add mana (capped at max_mana).
func restore_mana(amount: float) -> void:
	current_mana += amount


## Fully restore HP and mana to their computed maximums.
func restore_full() -> void:
	_ensure_computed()
	_hp = _cache.get("max_hp", 100.0)
	_mana = _cache.get("max_mana", 50.0)
	hp_changed.emit(_hp, _hp)
	mana_changed.emit(_mana, _mana)

# ─── Regeneration (call from _process with delta) ─────────────────────────────

func tick_regen(delta: float) -> void:
	var hp_regen := get_stat("hp_regen")
	if hp_regen > 0.0 and current_hp < get_stat("max_hp"):
		current_hp += hp_regen * delta

	var mp_regen := get_stat("mana_regen")
	if mp_regen > 0.0 and current_mana < get_stat("max_mana"):
		current_mana += mp_regen * delta

# ─── Debug ────────────────────────────────────────────────────────────────────

func get_debug_summary() -> String:
	_ensure_computed()
	return (
		"=== CharacterStats ===\n"
		+ "Level %d | STR:%d DEX:%d INT:%d VIT:%d\n" % [level, strength, dexterity, intelligence, vitality]
		+ "HP: %.0f/%.0f | Mana: %.0f/%.0f\n" % [current_hp, get_stat("max_hp"), current_mana, get_stat("max_mana")]
		+ "Dmg: %.0f–%.0f | Armor: %.0f | Crit: %.1f%% ×%.0f%%\n" % [
			get_stat("min_damage"), get_stat("max_damage"),
			get_stat("armor"), get_stat("crit_chance"), get_stat("crit_multiplier")]
		+ "AtkSpd: %.2f | MoveSpd: %.0f | Evasion: %.1f%%\n" % [
			get_stat("attack_speed"), get_stat("movement_speed"), get_stat("evasion")]
		+ "Res — F:%.0f%% C:%.0f%% L:%.0f%% P:%.0f%%" % [
			get_stat("fire_resistance"), get_stat("cold_resistance"),
			get_stat("lightning_resistance"), get_stat("poison_resistance")]
	)

# ─── Internal Computation ─────────────────────────────────────────────────────

func _mark_dirty() -> void:
	_dirty = true


func _ensure_computed() -> void:
	if _dirty:
		_recompute_all()


func _recompute_all() -> void:
	var old_cache := _cache.duplicate()
	_cache.clear()

	for stat_name in _BASE_STAT_NAMES:
		var base := _compute_base(stat_name)
		_cache[stat_name] = _apply_modifiers(stat_name, base)

	# Clamp mutable resources to new maximums.
	if _hp >= 0.0:
		_hp = minf(_hp, _cache["max_hp"])
	if _mana >= 0.0:
		_mana = minf(_mana, _cache["max_mana"])

	_dirty = false

	# Emit change signals for any stat that shifted.
	for stat_name in _cache:
		var new_val: float = _cache[stat_name]
		var old_val: float = old_cache.get(stat_name, new_val)
		if not is_equal_approx(new_val, old_val):
			stat_changed.emit(stat_name, old_val, new_val)


## Computes the BASE value for a stat from primary stats and level ONLY.
## No modifiers are applied here — they are layered on top in _apply_modifiers().
##
## FORMULA NOTES (tuned for a 1–100 level range):
##   max_hp   : Warrior feels tanky, Mage is fragile. Tune via hp_per_vitality.
##   min/max_damage: Narrow spread at low levels, widens at high for skill ceiling.
##   crit_chance  : Hard-capped via MAX_RESISTANCE in CombatManager (75%).
func _compute_base(stat_name: String) -> float:
	match stat_name:
		"max_hp":
			# 50 base + 5 per VIT (class scaling via _hp_per_vitality) + 10 per level.
			return 50.0 + vitality * _hp_per_vitality + level * 10.0

		"max_mana":
			return 20.0 + intelligence * _mana_per_intelligence + level * 5.0

		"min_damage":
			return 1.0 + strength * 0.5 + level * 0.5

		"max_damage":
			return 3.0 + strength * 1.0 + level * 1.0

		"armor":
			return strength * _armor_per_strength + level * 2.0

		"crit_chance":
			# 5% base + 0.15 per DEX. Soft cap via diminishing returns from items.
			return 5.0 + dexterity * 0.15

		"crit_multiplier":
			# 150% = deal 1.5× damage on crit. Items can push this to ~400%.
			return 150.0

		"attack_speed":
			# Attacks per second. DEX gives marginal bonus; items give larger gains.
			return 1.0 + dexterity * 0.005

		"movement_speed":
			# Pixels per second.
			return 200.0 + dexterity * 0.5

		"hp_regen":
			# HP per second. Minor but noticeable out of combat.
			return 0.5 + vitality * 0.05

		"mana_regen":
			# Mana per second.
			return 1.0 + intelligence * 0.1

		"evasion":
			# Percent chance to fully dodge a physical hit.
			return dexterity * 0.1

		"spell_power":
			# Flat bonus added to spell damage before resistance.
			return intelligence * 1.5

		# Damage bonuses start at 0 and come entirely from items / passives.
		"physical_damage_bonus", "spell_damage_bonus",\
		"fire_damage_bonus", "cold_damage_bonus",\
		"lightning_damage_bonus", "poison_damage_bonus":
			return 0.0

		# Resistances start at 0; purely gear-dependent.
		"fire_resistance", "cold_resistance",\
		"lightning_resistance", "poison_resistance":
			return 0.0

		"life_steal":
			return 0.0

		"item_find_bonus":
			# Percentage bonus to finding magic/rare items.
			return 0.0

		_:
			push_warning("CharacterStats: Unknown stat '%s'." % stat_name)
			return 0.0


## Applies all modifiers to a base value using the three-tier pipeline:
##   base + Σ(FLAT) → result₁
##   result₁ × (1 + Σ(PERCENT_ADD) / 100) → result₂
##   result₂ × Π(1 + PERCENT_MULT[i] / 100) → final
func _apply_modifiers(stat_name: String, base_value: float) -> float:
	if not _mods_by_stat.has(stat_name):
		return base_value

	var flat_total: float = 0.0
	var pct_add_total: float = 0.0
	var pct_mult: float = 1.0

	for mod: StatModifier in _mods_by_stat[stat_name]:
		match mod.type:
			StatModifier.Type.FLAT:
				flat_total += mod.value
			StatModifier.Type.PERCENT_ADD:
				pct_add_total += mod.value
			StatModifier.Type.PERCENT_MULT:
				pct_mult *= (1.0 + mod.value / 100.0)

	var result := (base_value + flat_total) * (1.0 + pct_add_total / 100.0) * pct_mult
	return result


func _remove_internal(modifier_id: String) -> void:
	if not _mods_by_id.has(modifier_id):
		return

	var mod: StatModifier = _mods_by_id[modifier_id]
	_mods_by_id.erase(modifier_id)

	if _mods_by_stat.has(mod.stat):
		_mods_by_stat[mod.stat].erase(mod)
		if _mods_by_stat[mod.stat].is_empty():
			_mods_by_stat.erase(mod.stat)
