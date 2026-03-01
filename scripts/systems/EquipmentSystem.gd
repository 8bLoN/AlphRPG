# EquipmentSystem.gd
# =============================================================================
# Manages a character's equipment slots and orchestrates equip/unequip.
#
# SLOTS (from ItemData.EquipSlot):
#   NONE, HELMET, CHEST, GLOVES, BOOTS,
#   WEAPON_MAIN, WEAPON_OFF, RING_LEFT, RING_RIGHT, AMULET
#
# EQUIPPING FLOW:
#   1. equip(item) is called with an EquipmentItem.
#   2. If the slot is occupied, the previous item is unequipped first.
#   3. The item's modifiers are applied to character.stats.
#   4. EventBus.item_equipped signal is emitted (drives visual layer swap).
#
# DUAL-WIELD / SHIELD:
#   WEAPON_OFF can hold a shield (EquipSlot.WEAPON_OFF) or an off-hand weapon.
#   Extend ItemData with a sub-type flag ("shield", "off-hand") if needed.
# =============================================================================
class_name EquipmentSystem
extends RefCounted

## The character this system belongs to.
var _character: BaseCharacter = null

## Current equipment. Key: ItemData.EquipSlot (int), Value: EquipmentItem or null.
var _slots: Dictionary = {}

# ─── Initialisation ───────────────────────────────────────────────────────────

func _init(character: BaseCharacter) -> void:
	_character = character
	# Initialise all slots to null (empty).
	for slot_idx in range(ItemData.EquipSlot.size()):
		_slots[slot_idx] = null

# ─── Equip / Unequip ─────────────────────────────────────────────────────────

## Equip an item into its designated slot.
## If the slot is occupied, the old item is returned to the inventory (if provided).
## Returns true on success.
func equip(item: EquipmentItem, inventory: InventorySystem = null) -> bool:
	if item == null or item.data == null:
		return false
	if item.data.equip_slot == ItemData.EquipSlot.NONE:
		push_warning("EquipmentSystem: Item '%s' has no equip slot." % item.data.id)
		return false

	var slot := item.data.equip_slot

	# Unequip current item in that slot first.
	var existing := _slots.get(slot, null) as EquipmentItem
	if existing:
		unequip_slot(slot, inventory)

	# Apply the new item.
	if not item.equip(_character):
		return false

	_slots[slot] = item
	return true


## Unequip the item in a specific slot.
## If inventory is provided, the item is placed back into it.
## Returns the unequipped item (or null if slot was empty).
func unequip_slot(slot: int, inventory: InventorySystem = null) -> EquipmentItem:
	var item := _slots.get(slot, null) as EquipmentItem
	if item == null:
		return null

	item.unequip(_character)
	_slots[slot] = null

	if inventory:
		if not inventory.add_item(item):
			# Inventory full — drop in world (caller should handle this).
			push_warning("EquipmentSystem: Inventory full, couldn't return unequipped item.")

	return item


## Swap the item in an inventory slot with the item in an equipment slot.
## If the equipment slot is occupied, the items trade places.
func swap_with_inventory(inv_item: EquipmentItem, inventory: InventorySystem) -> bool:
	if inv_item == null:
		return false

	var slot := inv_item.data.equip_slot
	var equipped := _slots.get(slot, null) as EquipmentItem

	# Remove from inventory first.
	if not inventory.remove_item(inv_item):
		return false

	if equipped:
		# Put old equipped item into inventory.
		equipped.unequip(_character)
		_slots[slot] = null
		if not inventory.add_item(equipped):
			# Can't fit old item back — abort and re-equip it.
			equipped.equip(_character)
			_slots[slot] = equipped
			inventory.add_item(inv_item)  # Return new item to inventory.
			return false

	# Equip the new item.
	inv_item.equip(_character)
	_slots[slot] = inv_item
	return true

# ─── Query API ────────────────────────────────────────────────────────────────

## Get the item in a specific slot (null if empty).
func get_item_in_slot(slot: int) -> EquipmentItem:
	return _slots.get(slot, null)


## Get all equipped items as an Array.
func get_all_equipped() -> Array[EquipmentItem]:
	var result: Array[EquipmentItem] = []
	for slot_idx: int in _slots:
		var item := _slots[slot_idx] as EquipmentItem
		if item:
			result.append(item)
	return result


## Returns true if the given slot is occupied.
func is_slot_occupied(slot: int) -> bool:
	return _slots.get(slot, null) != null


## Returns a dict of slot → item for UI rendering.
func get_all_slots() -> Dictionary:
	return _slots.duplicate()

# ─── Weapon Helpers ───────────────────────────────────────────────────────────

## Returns the main-hand weapon's damage range [min, max] or [0, 0] if unarmed.
func get_weapon_damage_range() -> Vector2:
	var weapon := _slots.get(ItemData.EquipSlot.WEAPON_MAIN, null) as EquipmentItem
	if weapon == null:
		return Vector2.ZERO
	return Vector2(weapon.get_weapon_min_damage(), weapon.get_weapon_max_damage())


## Returns the main-hand weapon's damage type, or PHYSICAL if unarmed.
func get_weapon_damage_type() -> int:
	var weapon := _slots.get(ItemData.EquipSlot.WEAPON_MAIN, null) as EquipmentItem
	if weapon == null:
		return CombatManager.DamageType.PHYSICAL
	return weapon.get_weapon_damage_type()

# ─── Serialisation ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var data := {}
	for slot_idx: int in _slots:
		var item := _slots[slot_idx] as EquipmentItem
		if item:
			data[str(slot_idx)] = item.serialize()
	return data
