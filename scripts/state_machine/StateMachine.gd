# StateMachine.gd
# =============================================================================
# Generic finite state machine (FSM) implemented as a Node so it participates
# in the scene tree and receives _process / _physics_process naturally.
#
# States are CharacterState objects (RefCounted) — not nodes — to keep the
# tree clean. The FSM holds them in a dictionary keyed by name.
#
# USAGE:
#   var sm := StateMachine.new()
#   add_child(sm)
#   sm.add_state("idle", IdleState.new(self))
#   sm.transition_to("idle")
#
# TRANSITION GUARDS:
#   Each CharacterState.can_enter() is called before transitioning.
#   Deny the transition by returning false from can_enter().
#   Force-transitions bypass can_enter() via force_transition_to().
# =============================================================================
class_name StateMachine
extends Node

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted after a successful state transition.
signal transitioned(from_state: String, to_state: String)

# ─── State Registry ───────────────────────────────────────────────────────────

## All registered states, keyed by their string name.
var _states: Dictionary = {}

## Currently active state.
var current_state: CharacterState = null

## Name of the currently active state (for external inspection / animation).
var current_state_name: String = ""

## Name of the previous state (for "return to idle" patterns).
var previous_state_name: String = ""

# ─── API ─────────────────────────────────────────────────────────────────────

## Register a state with a given name. Call before any transition.
func add_state(state_name: String, state: CharacterState) -> void:
	_states[state_name] = state
	state.state_machine = self


## Transition to a named state. Calls can_enter() on the target state.
## Returns true if the transition succeeded.
func transition_to(state_name: String) -> bool:
	if not _states.has(state_name):
		push_error("StateMachine: State '%s' is not registered." % state_name)
		return false

	var target: CharacterState = _states[state_name]

	# Guard check — state may refuse entry.
	if not target.can_enter():
		return false

	_do_transition(state_name, target)
	return true


## Transition without calling can_enter(). Use for forced state changes (e.g. death).
func force_transition_to(state_name: String) -> void:
	if not _states.has(state_name):
		push_error("StateMachine: State '%s' is not registered." % state_name)
		return
	_do_transition(state_name, _states[state_name])


## Returns true if the FSM is currently in the named state.
func is_in_state(state_name: String) -> bool:
	return current_state_name == state_name


## Returns the registered state object by name (for direct inspection).
func get_state(state_name: String) -> CharacterState:
	return _states.get(state_name, null)

# ─── Godot Callbacks ─────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

# ─── Internal ─────────────────────────────────────────────────────────────────

func _do_transition(state_name: String, target: CharacterState) -> void:
	var prev_name := current_state_name

	if current_state:
		current_state.exit()

	previous_state_name = current_state_name
	current_state = target
	current_state_name = state_name
	current_state.enter()

	transitioned.emit(prev_name, state_name)
