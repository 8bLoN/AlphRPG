# EquipmentItem.gd
# =============================================================================
# Equipment item instance. Extends BaseItem with:
#   • equip() — applies all StatModifiers to a character's CharacterStats.
#   • unequip() — removes all StatModifiers.
#   • visual_sprite_frames — the SpriteFrames used by EquipmentVisualSystem.
#
# Modifier source prefix: "item/<uid>/<stat>"
# This convention lets EquipmentSystem remove all modifiers for one item in O(n).
# =============================================================================
class_name EquipmentItem
extends BaseItem

## SpriteFrames resource for the equipment visual layer.
## Must share animation names with the base character animations (idle, run, etc.)
var visual_sprite_frames: SpriteFrames = null

## Whether this item is currently equipped.
var is_equipped: bool = false


func _init(item_data: ItemData, instance_uid: String = "") -> void:
	super._init(item_data, instance_uid)


## Apply all this item's stat modifiers to the character.
## Returns true on success.
func equip(character: BaseCharacter) -> bool:
	if is_equipped:
		push_warning("EquipmentItem: '%s' is already equipped." % get_display_name())
		return false
	if data.category != ItemData.ItemCategory.EQUIPMENT:
		return false

	var source := "item/%s" % uid

	# Apply base stat bonuses defined in ItemData.base_stat_bonuses.
	for stat_name: String in data.base_stat_bonuses:
		var val: float = data.base_stat_bonuses[stat_name]
		var mod := StatModifier.new(
			"%s/%s_base" % [source, stat_name],
			stat_name, val, StatModifier.Type.FLAT)
		character.stats.add_modifier(mod)
		# Also track in our modifiers list for serialisation.
		if not modifiers.has(mod):
			modifiers.append(mod)

	# Apply rolled affix modifiers.
	for mod: StatModifier in modifiers:
		# Ensure the modifier ID uses our source prefix for clean removal.
		if not mod.id.begins_with(source):
			mod.id = "%s/%s" % [source, mod.id]
		character.stats.add_modifier(mod)

	is_equipped = true
	EventBus.item_equipped.emit(character, self, ItemData.EquipSlot.keys()[data.equip_slot])
	return true


## Remove all this item's stat modifiers from the character.
func unequip(character: BaseCharacter) -> bool:
	if not is_equipped:
		return false

	character.stats.remove_modifiers_by_source("item/%s" % uid)
	is_equipped = false
	EventBus.item_unequipped.emit(character, self, ItemData.EquipSlot.keys()[data.equip_slot])
	return true


## Weapon-specific helpers.

func get_weapon_min_damage() -> float:
	return data.weapon_min_damage


func get_weapon_max_damage() -> float:
	return data.weapon_max_damage


func get_weapon_damage_type() -> int:
	return data.damage_type


## Display name for tooltip header.
func get_display_name() -> String:
	var base := super.get_display_name()
	# Legendary items often have unique names — respect data.display_name.
	return base
