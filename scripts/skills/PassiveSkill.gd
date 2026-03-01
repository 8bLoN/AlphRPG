# PassiveSkill.gd
# =============================================================================
# A passive skill applies StatModifiers to the owner when learned / ranked up.
# It has no activation — it is always "on" once learned.
#
# USAGE:
#   SkillTree.learn_or_upgrade(skill_id) calls apply_passive_modifiers()
#   when a rank is added, removing old modifiers and applying the new rank's set.
# =============================================================================
class_name PassiveSkill
extends BaseSkill

## Modifier IDs registered by this passive (for clean removal on rank change).
var _applied_modifier_ids: Array[String] = []


func can_activate(_caster: BaseCharacter) -> bool:
	# Passives are never manually activated.
	return false


## Apply all passive modifiers for the current rank. Called by SkillTree.
func apply_passive_modifiers(character: BaseCharacter) -> void:
	# Remove any previously applied modifiers (rank upgrade).
	_remove_passive_modifiers(character)

	if data == null:
		return

	# Base modifiers (rank 1 values).
	for mod_def: Dictionary in data.passive_modifiers:
		_apply_mod_def(character, mod_def, "passive_%s_base" % data.id)

	# Per-rank bonus modifiers (cumulative from rank 2 onward).
	if rank > 1:
		for mod_def: Dictionary in data.passive_modifiers_per_rank:
			for r in range(1, rank):
				var scaled_val: float = mod_def.get("value", 0.0)
				var scaled_def := mod_def.duplicate()
				scaled_def["value"] = scaled_val
				_apply_mod_def(character, scaled_def, "passive_%s_rank%d" % [data.id, r])


func _apply_mod_def(character: BaseCharacter, mod_def: Dictionary, base_id: String) -> void:
	var mod_id := "%s/%s" % [base_id, mod_def.get("stat", "unknown")]
	var mod := StatModifier.new(
		mod_id,
		mod_def.get("stat", ""),
		mod_def.get("value", 0.0),
		mod_def.get("type", StatModifier.Type.FLAT),
		-1.0
	)
	mod.display_label = mod_def.get("label", "")
	character.stats.add_modifier(mod)
	_applied_modifier_ids.append(mod_id)


func _remove_passive_modifiers(character: BaseCharacter) -> void:
	for mid: String in _applied_modifier_ids:
		character.stats.remove_modifier(mid)
	_applied_modifier_ids.clear()
