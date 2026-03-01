# LootSystem.gd
# =============================================================================
# Handles the world-representation of dropped loot.
# When EventBus.loot_spawned is emitted, LootSystem spawns WorldDrop nodes
# in the world that the player can walk over to pick up.
# =============================================================================
class_name LootSystem
extends Node

## Scene containing a mesh + label + Area3D for item pickup interaction.
@export var world_drop_scene: PackedScene = null

## Radius within which item drops are magnetised toward the player (0 = off).
@export var pickup_magnet_radius: float = 0.0

# ─── Internals ────────────────────────────────────────────────────────────────

var _active_drops: Array[Node] = []

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	EventBus.loot_spawned.connect(_on_loot_spawned)


func _process(_delta: float) -> void:
	if pickup_magnet_radius <= 0.0:
		return
	_update_magnet()

# ─── Drop Spawning ────────────────────────────────────────────────────────────

func _on_loot_spawned(world_position: Vector3, items: Array) -> void:
	for item: BaseItem in items:
		_spawn_drop(item, world_position)


func _spawn_drop(item: BaseItem, world_position: Vector3) -> void:
	if world_drop_scene == null:
		push_warning("LootSystem: world_drop_scene not set. Drop skipped.")
		return

	var drop: Node = world_drop_scene.instantiate()
	get_parent().add_child(drop)

	# Offset drops slightly so they don't stack perfectly.
	var offset := Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(-2.4, 2.4))
	drop.global_position = world_position + offset

	if drop.has_method("set_item"):
		drop.set_item(item)

	if drop.has_signal("picked_up"):
		drop.picked_up.connect(_on_item_picked_up.bind(drop, item))

	_active_drops.append(drop)


func _on_item_picked_up(drop_node: Node, item: BaseItem) -> void:
	_active_drops.erase(drop_node)
	var player := GameManager.player
	if player == null:
		return

	if "inventory" in player and player.inventory is InventorySystem:
		if player.inventory.add_item(item):
			EventBus.item_added_to_inventory.emit(player, item)
			EventBus.floating_text_requested.emit(
				player.global_position,
				item.data.display_name,
				item.get_rarity_color()
			)
		else:
			EventBus.floating_text_requested.emit(
				player.global_position, "Inventory full!", Color.RED)
			_spawn_drop(item, drop_node.global_position)

	drop_node.queue_free()

# ─── Pickup Magnet ────────────────────────────────────────────────────────────

func _update_magnet() -> void:
	var player := GameManager.player
	if not is_instance_valid(player):
		return

	for drop: Node in _active_drops:
		if not is_instance_valid(drop):
			continue
		var dist: float = drop.global_position.distance_to(player.global_position)
		if dist <= pickup_magnet_radius:
			var dir: Vector3 = (player.global_position - drop.global_position).normalized()
			drop.global_position += dir * 30.0 * get_process_delta_time()
