# StatModifier.gd
# =============================================================================
# A single modification to one character stat from one source.
# CharacterStats maintains a list of these and recomputes derived stats whenever
# the list changes (lazy / dirty-flag pattern).
#
# MODIFIER TYPES:
#   FLAT         – Adds/subtracts a raw value.
#                  Best for: +50 max HP, +10 armor
#   PERCENT_ADD  – Adds a percentage of the BASE stat.
#                  Multiple PERCENT_ADD mods are summed before multiplying.
#                  Best for: +20% max HP (stacks additively with other % HP mods)
#   PERCENT_MULT – Multiplies the stat AFTER flat + percent_add are applied.
#                  Stacks multiplicatively. Use sparingly — very powerful.
#                  Best for: "Increases damage by 30% more" legendary affixes
#
# EXAMPLE PIPELINE for max_hp = 200 (base):
#   + FLAT 100      → 300
#   + PERCENT_ADD 50% → 300 * 1.5 = 450
#   × PERCENT_MULT 1.2 → 450 * 1.2 = 540
#
# ID CONVENTION:
#   "item/<unique_item_instance_id>"    – from an equipped item
#   "skill/<skill_id>/<rank>"           – from a passive skill
#   "buff/<effect_id>"                  – from a temporary effect
# =============================================================================
class_name StatModifier
extends RefCounted

enum Type {
	FLAT,
	PERCENT_ADD,
	PERCENT_MULT,
}

## Unique string key. Used to remove this modifier later.
## Format: "source_category/source_identifier"
var id: String = ""

## Which stat to modify. Must match a key computed by CharacterStats._compute_base().
var stat: String = ""

## Numeric value of the modification.
##   FLAT:         raw units (e.g. 50.0 for +50 HP)
##   PERCENT_ADD:  percentage points (e.g. 20.0 for +20%)
##   PERCENT_MULT: percentage points (e.g. 30.0 for ×1.3)
var value: float = 0.0

## How the value is applied (see Type enum).
var type: Type = Type.FLAT

## Seconds before this modifier self-removes. -1 = permanent until explicitly removed.
var duration: float = -1.0

## Human-readable label for tooltip display (e.g. "+50 Maximum Life").
var display_label: String = ""

# ─── Constructor ──────────────────────────────────────────────────────────────

func _init(
		p_id: String = "",
		p_stat: String = "",
		p_value: float = 0.0,
		p_type: Type = Type.FLAT,
		p_duration: float = -1.0) -> void:
	id = p_id
	stat = p_stat
	value = p_value
	type = p_type
	duration = p_duration

# ─── Helpers ──────────────────────────────────────────────────────────────────

## Returns a display-ready string, e.g. "+50 max_hp" or "+20% crit_chance".
func to_display_string() -> String:
	if display_label.length() > 0:
		return display_label
	var sign_str := "+" if value >= 0.0 else ""
	match type:
		Type.FLAT:
			return "%s%.0f %s" % [sign_str, value, stat]
		Type.PERCENT_ADD:
			return "%s%.1f%% %s" % [sign_str, value, stat]
		Type.PERCENT_MULT:
			return "%s%.1f%% more %s" % [sign_str, value, stat]
	return ""


func _to_string() -> String:
	return "StatModifier(%s | %s %s)" % [id, Type.keys()[type], to_display_string()]
