# EventBus.gd
# =============================================================================
# Global signal bus for decoupled inter-system communication.
# ALL cross-system events are routed through here so that systems never hold
# direct references to each other — only to EventBus.
#
# USAGE:
#   Emitting:  EventBus.character_died.emit(character)
#   Listening: EventBus.character_died.connect(_on_character_died)
#
# EXTENDING:
#   Add new signals here grouped by domain. Never add game logic to this file.
# =============================================================================
extends Node

# ─── Character Lifecycle ──────────────────────────────────────────────────────

## Any character (player or enemy) has died.
signal character_died(character: Node)

## A character received damage.
## damage_info keys: "final_damage" (float), "damage_type" (int),
##                   "is_crit" (bool), "absorbed" (float)
signal character_damaged(character: Node, damage_info: Dictionary)

## A character was healed.
signal character_healed(character: Node, amount: float)

## The player gained a level.
signal character_leveled_up(character: Node, new_level: int)

## A derived stat value changed (used for UI binding).
signal stat_changed(character: Node, stat_name: String, old_value: float, new_value: float)

## A status effect was applied to a character.
signal effect_applied(target: Node, effect_id: String, duration: float)

## A status effect was removed (expired or dispelled) from a character.
signal effect_removed(target: Node, effect_id: String)

# ─── Player Progression ───────────────────────────────────────────────────────

## Player's experience pool changed.
signal experience_changed(current_xp: int, xp_to_next: int)

## Player has unspent stat allocation points.
signal stat_points_available(points: int)

## Player has unspent skill points.
signal skill_points_available(points: int)

# ─── Combat ───────────────────────────────────────────────────────────────────

## A hit connected between attacker and target.
## damage_info: same keys as character_damaged
signal hit_landed(attacker: Node, target: Node, damage_info: Dictionary)

## A critical hit connected (used for special VFX/screen shake hooks).
signal critical_hit(attacker: Node, target: Node, damage: float)

## An enemy was killed — used by loot, quest, and XP systems.
signal enemy_killed(enemy: Node, killer: Node)

## Request a floating damage number at a world position.
signal show_damage_number(world_position: Vector3, damage: float, is_crit: bool, damage_type: String)

# ─── Skills ───────────────────────────────────────────────────────────────────

## A skill began executing (animation, VFX trigger).
signal skill_activated(caster: Node, skill_id: String)

## A skill finished executing.
signal skill_completed(caster: Node, skill_id: String)

## A skill was interrupted before completion.
signal skill_interrupted(caster: Node, skill_id: String)

## Cooldown tick — used by SkillBar to update cooldown overlays.
## remaining and total are in seconds.
signal skill_cooldown_updated(skill_id: String, remaining: float, total: float)

## A skill was learned from the skill tree.
signal skill_learned(character: Node, skill_data: Resource)

# ─── Inventory & Items ────────────────────────────────────────────────────────

## An item was added to a character's inventory.
signal item_added_to_inventory(character: Node, item: Resource)

## An item was removed from a character's inventory.
signal item_removed_from_inventory(character: Node, item: Resource)

## An item was equipped into a slot — triggers stat recalculation.
signal item_equipped(character: Node, item: Resource, slot: String)

## An item was unequipped from a slot.
signal item_unequipped(character: Node, item: Resource, slot: String)

## The inventory layout changed (items moved, added, removed).
## Used to redraw the inventory grid UI.
signal inventory_layout_changed(character: Node)

## A loot pile was spawned in the world.
signal loot_spawned(world_position: Vector3, items: Array)

# ─── UI ───────────────────────────────────────────────────────────────────────

## Request the tooltip system to display an item tooltip.
signal tooltip_show_requested(item: Resource, screen_position: Vector2)

## Request the tooltip system to hide the current tooltip.
signal tooltip_hide_requested()

## Request a floating text label in the world (damage numbers, pick-up text, etc.).
signal floating_text_requested(world_position: Vector3, text: String, color: Color)

## A UI panel was opened or closed.
signal ui_panel_toggled(panel_id: String, is_visible: bool)

# ─── World ────────────────────────────────────────────────────────────────────

## A vendor shop was opened by proximity.
## shop_items: Array of Dictionaries { "id", "name", "price" }
signal vendor_opened(vendor_name: String, vendor_type: String, shop_items: Array)

## The player left a vendor's proximity and the shop closed.
signal vendor_closed()

## The player is about to transition to a new zone.
signal zone_transition_started(from_zone: String, to_zone: String)

## A zone has fully loaded and is ready.
signal zone_transition_completed(zone_name: String)

## A waypoint / checkpoint was activated.
signal checkpoint_activated(checkpoint_id: String)
