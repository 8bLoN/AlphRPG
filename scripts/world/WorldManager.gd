# WorldManager.gd
# =============================================================================
# Manages the active game world: zone loading, spawn points, and the LootSystem.
# Attach to the root node of every zone/level scene.
#
# ZONE SCENE STRUCTURE (recommended):
#   WorldManager (this node)
#   ├── TileMap           "TileMap"       – isometric tile map
#   ├── YSort             "YSort"         – parent for all depth-sorted nodes
#   │   ├── Player        (PlayerCharacter scene)
#   │   └── Enemies       (EnemyCharacter scenes)
#   ├── NavigationRegion2D "NavigationRegion"
#   ├── LootSystem        "LootSystem"
#   └── CanvasLayer       "HUD"           – UI layer
# =============================================================================
class_name WorldManager
extends Node

# ─── Configuration ────────────────────────────────────────────────────────────

@export var zone_id: String = "zone_01"
@export var zone_display_name: String = "The Dark Forest"
@export var recommended_level: int = 1

# ─── Spawn Points ─────────────────────────────────────────────────────────────

## Player starts at this marker's position.
@onready var player_spawn: Marker3D = get_node_or_null("PlayerSpawn")

## Enemy spawner nodes (must have start_spawning() method).
@onready var enemy_spawners: Node = get_node_or_null("EnemySpawners")

# ─── Systems ─────────────────────────────────────────────────────────────────

@onready var loot_system: LootSystem = get_node_or_null("LootSystem") as LootSystem

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	GameManager.active_zone = zone_id
	GameManager.set_phase(GameManager.GamePhase.PLAYING)
	EventBus.zone_transition_completed.emit(zone_id)

	# Position player at spawn point.
	_spawn_player()

	# Start enemy spawners.
	if enemy_spawners:
		for spawner in enemy_spawners.get_children():
			if spawner.has_method("start_spawning"):
				spawner.start_spawning(recommended_level)

	print("WorldManager: Entered zone '%s' (recommended level %d)." % [zone_display_name, recommended_level])


func _spawn_player() -> void:
	var player := GameManager.player
	if is_instance_valid(player) and player_spawn:
		player.global_position = player_spawn.global_position
