# ConsumableItem.gd
# =============================================================================
# Consumable item instance (potions, scrolls, food, etc.).
# Stacks in inventory. use() consumes one from the stack and applies the effect.
# =============================================================================
class_name ConsumableItem
extends BaseItem

## Cooldown tracker (shared across all potion types via the character's effect system).
var _last_use_time: float = -INF


func _init(item_data: ItemData, instance_uid: String = "") -> void:
	super._init(item_data, instance_uid)
	quantity = 1


## Try to use this consumable on a character.
## Returns true if used successfully (decrements stack by 1).
func use(character: BaseCharacter) -> bool:
	if quantity <= 0:
		return false

	# Cooldown check.
	var current_time := Time.get_ticks_msec() / 1000.0
	if current_time - _last_use_time < data.use_cooldown:
		EventBus.floating_text_requested.emit(
			character.global_position,
			"On cooldown!",
			Color.GRAY
		)
		return false

	_last_use_time = current_time

	# Apply healing.
	if data.heal_amount > 0.0:
		var actual := character.receive_healing(data.heal_amount)
		EventBus.floating_text_requested.emit(
			character.global_position,
			"+%.0f HP" % actual,
			Color(0.2, 1.0, 0.2)
		)

	# Restore mana.
	if data.mana_amount > 0.0:
		character.stats.restore_mana(data.mana_amount)
		EventBus.floating_text_requested.emit(
			character.global_position + Vector3(0, 2, 0),
			"+%.0f MP" % data.mana_amount,
			Color(0.4, 0.4, 1.0)
		)

	# Apply a status effect if defined.
	if data.use_effect_id.length() > 0:
		# Look up the effect definition from SkillDatabase or a dedicated EffectDatabase.
		# Placeholder: the effect_id is passed to the character's apply_effect().
		# Implement EffectDatabase.get_effect(id) to return effect_data Dictionaries.
		pass

	quantity -= 1
	EventBus.inventory_layout_changed.emit(character)

	return true


## True if this stack is completely consumed.
func is_depleted() -> bool:
	return quantity <= 0


## Try to merge another ConsumableItem into this stack.
## Returns the number of items that couldn't fit (excess).
func try_merge(other: ConsumableItem) -> int:
	if other.data.id != data.id:
		return other.quantity  # Can't merge different types.

	var space := data.max_stack - quantity
	if space <= 0:
		return other.quantity

	var absorbed := mini(other.quantity, space)
	quantity += absorbed
	return other.quantity - absorbed
