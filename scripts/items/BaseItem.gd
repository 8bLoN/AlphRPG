# BaseItem.gd
# =============================================================================
# A runtime INSTANCE of an item (not the template).
# ItemData (resource) = template. BaseItem = instance with rolled stats.
#
# One BaseItem exists per item drop / inventory slot. Multiple copies of the
# same sword type are separate BaseItem instances, each with their own rolled
# affix values (via their own StatModifier lists).
#
# EXTENDING:
#   EquipmentItem – adds equip/unequip logic and character stat modifiers.
#   ConsumableItem – adds use() and stack management.
# =============================================================================
class_name BaseItem
extends RefCounted

# ─── Template ─────────────────────────────────────────────────────────────────

## The immutable data template this item was generated from.
var data: ItemData = null

# ─── Instance Identity ────────────────────────────────────────────────────────

## Unique ID for this instance (used as modifier source prefix: "item/<uid>").
var uid: String = ""

## Current stack count (1 for non-stackable items).
var quantity: int = 1

# ─── Grid Position ────────────────────────────────────────────────────────────

## Top-left position of this item in the inventory grid.
## Set by InventorySystem when placed.
var grid_position: Vector2i = Vector2i(-1, -1)

# ─── Rolled Affixes ───────────────────────────────────────────────────────────

## Stat modifiers rolled at generation time (prefixes + suffixes + base stats).
## These are what actually get applied to the character's CharacterStats.
var modifiers: Array[StatModifier] = []

# ─── Rarity Override ──────────────────────────────────────────────────────────

## Rarity of this specific instance (may differ from data.rarity for uniques).
var rarity: ItemData.Rarity = ItemData.Rarity.COMMON

# ─── Initialisation ───────────────────────────────────────────────────────────

func _init(item_data: ItemData, instance_uid: String = "") -> void:
	data = item_data
	rarity = item_data.rarity
	uid = instance_uid if instance_uid.length() > 0 else _generate_uid()


func _generate_uid() -> String:
	return "%s_%d" % [data.id, Time.get_ticks_msec()]

# ─── Tooltip Data ─────────────────────────────────────────────────────────────

## Human-readable item name (accounts for rarity prefix generation).
func get_display_name() -> String:
	return data.display_name


## Returns the item's rarity colour.
func get_rarity_color() -> Color:
	return ItemData.get_rarity_color(rarity)


## Returns all modifier lines for tooltip rendering.
func get_tooltip_lines() -> Array[String]:
	var lines: Array[String] = []
	for mod: StatModifier in modifiers:
		lines.append(mod.to_display_string())
	return lines

# ─── Serialisation ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var mods_data := []
	for mod: StatModifier in modifiers:
		mods_data.append({
			"id": mod.id,
			"stat": mod.stat,
			"value": mod.value,
			"type": mod.type,
		})
	return {
		"uid": uid,
		"data_id": data.id,
		"quantity": quantity,
		"rarity": rarity,
		"modifiers": mods_data,
		"grid_x": grid_position.x,
		"grid_y": grid_position.y,
	}
