# ItemFactory.gd
# =============================================================================
# Generates BaseItem instances from ItemData templates with random affix rolls.
# This is the ONLY place in the codebase that creates item instances.
#
# RARITY SELECTION:
#   Rarity is influenced by item_level, zone difficulty, and the
#   "item_find_bonus" stat on the character (Magic Find in Diablo terms).
#
# AFFIX SYSTEM:
#   Affixes are stored in ItemDatabase.affixes as AffixDefinition dictionaries:
#   {
#     "id": "prefix_fire_dmg",
#     "category": "prefix",
#     "stat": "fire_damage_bonus",
#     "min_value": 5.0,
#     "max_value": 20.0,
#     "modifier_type": StatModifier.Type.FLAT,
#     "min_item_level": 1,
#     "label_template": "+{value} Fire Damage",
#   }
#
# EXTENDING:
#   • Add "set item" support: if item_data.set_id is set, force a predetermined
#     list of modifiers from a set definition resource.
#   • Add "corruption" for an extra dangerous bonus with a downside.
# =============================================================================
class_name ItemFactory
extends RefCounted  # Used as a static class; instantiation not required.

# ─── Rarity Weights ───────────────────────────────────────────────────────────
# Base weights (modified by magic find and item level).

const BASE_RARITY_WEIGHTS: Dictionary = {
	ItemData.Rarity.COMMON:    60,
	ItemData.Rarity.MAGIC:     30,
	ItemData.Rarity.RARE:      9,
	ItemData.Rarity.LEGENDARY: 1,
}

# ─── Main API ─────────────────────────────────────────────────────────────────

## Generate a random item of a specific base type at a given item level.
static func create_item(item_data_id: String, item_level: int, magic_find: float = 0.0) -> BaseItem:
	var item_data: ItemData = ItemDatabase.get_item_data(item_data_id)
	if item_data == null:
		push_error("ItemFactory: No ItemData found for id '%s'." % item_data_id)
		return null
	return generate_from_data(item_data, item_level, magic_find)


## Generate a random item from a loot table at a given item level.
static func generate_random_item(item_level: int, loot_table_id: String = "common_enemy", magic_find: float = 0.0) -> BaseItem:
	var item_data := ItemDatabase.get_random_item_from_table(loot_table_id, item_level)
	if item_data == null:
		return null
	return generate_from_data(item_data, item_level, magic_find)


## Generate a BaseItem from a specific ItemData with full affix rolling.
static func generate_from_data(item_data: ItemData, item_level: int, magic_find: float = 0.0) -> BaseItem:
	# Clamp item level to the template's supported range.
	var ilvl := item_level
	if item_data.min_item_level > 0:
		ilvl = maxi(ilvl, item_data.min_item_level)
	if item_data.max_item_level > 0:
		ilvl = mini(ilvl, item_data.max_item_level)

	# Select rarity.
	var rarity := _roll_rarity(magic_find)

	# Instantiate the correct class.
	var item: BaseItem
	match item_data.category:
		ItemData.ItemCategory.EQUIPMENT:
			item = EquipmentItem.new(item_data)
		ItemData.ItemCategory.CONSUMABLE:
			item = ConsumableItem.new(item_data)
		_:
			item = BaseItem.new(item_data)

	item.rarity = rarity

	# Roll affixes based on rarity.
	if item_data.category == ItemData.ItemCategory.EQUIPMENT:
		_roll_affixes(item, item_data, rarity, ilvl)

	return item

# ─── Rarity Rolling ───────────────────────────────────────────────────────────

static func _roll_rarity(magic_find: float) -> ItemData.Rarity:
	# Magic find increases rare+ chances without reducing legendary chance.
	var weights := BASE_RARITY_WEIGHTS.duplicate()
	var mf_factor := 1.0 + magic_find / 100.0

	weights[ItemData.Rarity.MAGIC] = int(weights[ItemData.Rarity.MAGIC] * mf_factor)
	weights[ItemData.Rarity.RARE] = int(weights[ItemData.Rarity.RARE] * mf_factor)
	weights[ItemData.Rarity.LEGENDARY] = int(weights[ItemData.Rarity.LEGENDARY] * mf_factor)

	# Reduce common weight to compensate.
	var total_non_common: int = (weights[ItemData.Rarity.MAGIC]
		+ weights[ItemData.Rarity.RARE]
		+ weights[ItemData.Rarity.LEGENDARY])
	weights[ItemData.Rarity.COMMON] = maxi(10, 100 - total_non_common)

	return _weighted_random_rarity(weights)


static func _weighted_random_rarity(weights: Dictionary) -> ItemData.Rarity:
	var total := 0
	for w: int in weights.values():
		total += w

	var roll := randi_range(0, total - 1)
	var cumulative := 0

	for rarity: ItemData.Rarity in weights:
		cumulative += weights[rarity]
		if roll < cumulative:
			return rarity

	return ItemData.Rarity.COMMON

# ─── Affix Rolling ────────────────────────────────────────────────────────────

static func _roll_affixes(item: BaseItem, data: ItemData, rarity: ItemData.Rarity, ilvl: int) -> void:
	var prefix_count := 0
	var suffix_count := 0

	match rarity:
		ItemData.Rarity.COMMON:
			prefix_count = 0
			suffix_count = 0
		ItemData.Rarity.MAGIC:
			prefix_count = randi_range(0, mini(1, data.max_prefixes))
			suffix_count = randi_range(0, mini(1, data.max_suffixes))
			# Ensure at least one affix for magic items.
			if prefix_count + suffix_count == 0:
				if randf() < 0.5:
					prefix_count = 1
				else:
					suffix_count = 1
		ItemData.Rarity.RARE:
			prefix_count = randi_range(1, mini(2, data.max_prefixes))
			suffix_count = randi_range(1, mini(2, data.max_suffixes))
		ItemData.Rarity.LEGENDARY:
			# Legendary affixes are predetermined per template.
			# For now, roll maximum affixes.
			prefix_count = data.max_prefixes
			suffix_count = data.max_suffixes

	# Roll prefixes.
	var used_affixes: Array[String] = []
	for _i in range(prefix_count):
		var affix := _pick_affix(data.prefix_pool, ilvl, used_affixes)
		if affix:
			used_affixes.append(affix["id"])
			var mod := _roll_affix_modifier(affix, "item/%s" % item.uid)
			item.modifiers.append(mod)

	# Roll suffixes.
	for _i in range(suffix_count):
		var affix := _pick_affix(data.suffix_pool, ilvl, used_affixes)
		if affix:
			used_affixes.append(affix["id"])
			var mod := _roll_affix_modifier(affix, "item/%s" % item.uid)
			item.modifiers.append(mod)


static func _pick_affix(pool: Array[String], ilvl: int, used: Array[String]) -> Dictionary:
	# Filter available affixes by item level and already-used.
	var available: Array[Dictionary] = []
	for affix_id: String in pool:
		if used.has(affix_id):
			continue
		var affix_def := ItemDatabase.get_affix(affix_id)
		if affix_def.is_empty():
			continue
		if affix_def.get("min_item_level", 1) > ilvl:
			continue
		available.append(affix_def)

	if available.is_empty():
		return {}

	return available[randi() % available.size()]


static func _roll_affix_modifier(affix: Dictionary, source_prefix: String) -> StatModifier:
	var min_val: float = affix.get("min_value", 0.0)
	var max_val: float = affix.get("max_value", 0.0)
	var rolled_val := randf_range(min_val, max_val)

	# Round to 1 decimal for cleaner display.
	rolled_val = roundf(rolled_val * 10.0) / 10.0

	var mod := StatModifier.new(
		"%s/%s" % [source_prefix, affix.get("id", "unknown")],
		affix.get("stat", ""),
		rolled_val,
		affix.get("modifier_type", StatModifier.Type.FLAT)
	)

	# Build display label from template.
	var label_template: String = affix.get("label_template", "")
	if label_template.length() > 0:
		var sign_str := "+" if rolled_val >= 0.0 else ""
		mod.display_label = label_template.replace(
			"{value}", "%s%.1f" % [sign_str, rolled_val])

	return mod
