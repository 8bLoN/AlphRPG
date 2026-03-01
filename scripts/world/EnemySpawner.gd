# EnemySpawner.gd
# =============================================================================
# Spawns enemy instances at runtime. Attach as a child of EnemySpawners node
# inside the zone scene, or place multiple in the world.
#
# Each spawner has:
#   • An EnemyData resource defining which enemy to spawn.
#   • A max_count cap so the zone doesn't overflow.
#   • A respawn_time (0 = no respawn).
#   • A spawn_radius for randomising spawn positions around this node.
# =============================================================================
class_name EnemySpawner
extends Node3D

# ─── Configuration ────────────────────────────────────────────────────────────

## The enemy scene to instantiate (must have EnemyCharacter script).
@export var enemy_scene: PackedScene = null

## EnemyData resource assigned to each spawned enemy instance.
@export var enemy_data: EnemyData = null

## How many enemies this spawner maintains simultaneously.
@export var max_count: int = 3

## Seconds between respawn attempts (0 = no respawn).
@export var respawn_time: float = 30.0

## Radius around this node where enemies can appear.
@export var spawn_radius: float = 64.0

# ─── State ────────────────────────────────────────────────────────────────────

var _zone_level: int = 1
var _active_enemies: Array[Node] = []
var _respawn_timer: float = 0.0
var _started: bool = false

# ─── Public API ───────────────────────────────────────────────────────────────

## Called by WorldManager. level = zone recommended level.
func start_spawning(level: int) -> void:
	_zone_level = level
	_started = true
	_fill_up()

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _started:
		return

	# Prune dead enemies from the list.
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e))

	# Respawn logic.
	if respawn_time > 0.0 and _active_enemies.size() < max_count:
		_respawn_timer += delta
		if _respawn_timer >= respawn_time:
			_respawn_timer = 0.0
			_spawn_one()

# ─── Spawning ─────────────────────────────────────────────────────────────────

func _fill_up() -> void:
	var needed := max_count - _active_enemies.size()
	for _i in range(needed):
		_spawn_one()


func _spawn_one() -> void:
	if enemy_scene == null:
		push_warning("EnemySpawner '%s': enemy_scene not set." % name)
		return

	if _active_enemies.size() >= max_count:
		return

	var instance: Node = enemy_scene.instantiate()

	# Set enemy data before adding to tree (properties, not position).
	if "enemy_data" in instance and enemy_data:
		instance.enemy_data = enemy_data
	if "enemy_level" in instance:
		instance.enemy_level = _zone_level

	# Add to tree first so global_position is valid.
	var target_parent: Node = _get_enemies_container()
	target_parent.add_child(instance)

	# Place at random point within spawn_radius (requires being in tree).
	var angle := randf() * TAU
	var dist := randf() * spawn_radius
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * dist
	instance.global_position = global_position + offset
	_active_enemies.append(instance)

	# Clean up when the enemy dies (it queue_frees itself after a delay).
	if instance.has_signal("tree_exiting"):
		instance.tree_exiting.connect(_on_enemy_removed.bind(instance), CONNECT_ONE_SHOT)


func _on_enemy_removed(enemy: Node) -> void:
	_active_enemies.erase(enemy)


func _get_enemies_container() -> Node:
	var scene_root: Node = get_tree().current_scene
	# Try Characters/Enemies (3D scene layout).
	var chars: Node = scene_root.get_node_or_null("Characters")
	if chars:
		var enemies: Node = chars.get_node_or_null("Enemies")
		if enemies:
			return enemies
		return chars
	# Fallback: legacy YSort layout.
	var y_sort: Node = scene_root.get_node_or_null("YSort")
	if y_sort:
		var enemies: Node = y_sort.get_node_or_null("Enemies")
		if enemies:
			return enemies
		return y_sort
	return scene_root
