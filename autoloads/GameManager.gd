# GameManager.gd
# =============================================================================
# Central game-state singleton. Tracks which phase the game is in, holds a
# reference to the active player, and owns the global pause gate.
#
# EXTENDING:
#   Add save/load hooks here. Zone transitions, difficulty scaling, and
#   session stats (enemies killed, time played) also belong here.
# =============================================================================
extends Node

# ─── Phase ────────────────────────────────────────────────────────────────────

enum GamePhase {
	MAIN_MENU,
	CHARACTER_SELECT,
	LOADING,
	PLAYING,
	PAUSED,
	GAME_OVER,
}

## Emitted whenever the phase changes. Subscribe for pause menus, HUD show/hide.
signal phase_changed(old_phase: GamePhase, new_phase: GamePhase)

var current_phase: GamePhase = GamePhase.MAIN_MENU

# ─── Player Reference ─────────────────────────────────────────────────────────

## Weak reference to the active player node. Set by PlayerCharacter._ready().
var player: Node = null

# ─── Session Statistics ───────────────────────────────────────────────────────

## Total seconds spent in PLAYING phase this session.
var play_time: float = 0.0

## Enemies killed this session.
var enemies_killed: int = 0

## Current active zone name.
var active_zone: String = ""

# ─── Difficulty ───────────────────────────────────────────────────────────────

## Multipliers applied globally to enemy stats. Extend for NG+ or difficulty modes.
var difficulty_multipliers: Dictionary = {
	"enemy_damage": 1.0,
	"enemy_hp": 1.0,
	"xp_gain": 1.0,
	"item_find": 1.0,
}

# ─── Internal ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	# GameManager must run even while the tree is paused so it can unpause.
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_killed.connect(_on_enemy_killed)


func _process(delta: float) -> void:
	if current_phase == GamePhase.PLAYING:
		play_time += delta

# ─── Phase Management ─────────────────────────────────────────────────────────

## Transition to a new game phase. Handles pause-tree side effects automatically.
func set_phase(new_phase: GamePhase) -> void:
	if new_phase == current_phase:
		return

	var old := current_phase
	current_phase = new_phase

	match new_phase:
		GamePhase.PAUSED:
			get_tree().paused = true
		GamePhase.PLAYING:
			get_tree().paused = false
		GamePhase.LOADING:
			get_tree().paused = true
		_:
			get_tree().paused = false

	phase_changed.emit(old, new_phase)


## Shorthand toggle: PLAYING <-> PAUSED.
func toggle_pause() -> void:
	if current_phase == GamePhase.PLAYING:
		set_phase(GamePhase.PAUSED)
	elif current_phase == GamePhase.PAUSED:
		set_phase(GamePhase.PLAYING)

# ─── Player Registration ──────────────────────────────────────────────────────

## Called by PlayerCharacter when it enters the scene tree.
func register_player(player_node: Node) -> void:
	player = player_node


## Called by PlayerCharacter when it exits the scene tree or dies.
func unregister_player() -> void:
	player = null


## Safe accessor — returns Vector3.ZERO if no player is registered.
func get_player_position() -> Vector3:
	if is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO

# ─── Event Handlers ───────────────────────────────────────────────────────────

func _on_enemy_killed(_enemy: Node, _killer: Node) -> void:
	enemies_killed += 1

# ─── Utility ─────────────────────────────────────────────────────────────────

## Returns true if the game is currently in an interactable play state.
func is_playing() -> bool:
	return current_phase == GamePhase.PLAYING


func get_session_summary() -> Dictionary:
	return {
		"play_time": play_time,
		"enemies_killed": enemies_killed,
		"zone": active_zone,
	}
