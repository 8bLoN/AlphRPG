# FloatingTextManager.gd
# =============================================================================
# Spawns floating text labels in screen space (damage numbers, pick-up names,
# status effect notifications, etc.).
#
# World positions are projected to screen via Camera3D.unproject_position().
# Labels float upward while fading out, recycled via a pool.
# =============================================================================
class_name FloatingTextManager
extends Node

# ─── Configuration ────────────────────────────────────────────────────────────

const DURATION: float = 1.2
const FLOAT_SPEED: float = 60.0
const NORMAL_FONT_SIZE: int = 18
const CRIT_FONT_SIZE: int = 28
const POOL_SIZE: int = 40

# ─── Label Pool ───────────────────────────────────────────────────────────────

var _pool: Array[Label] = []
var _active: Array[Dictionary] = []  # { "label": Label, "timer": float, "vel": Vector2 }

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	for _i in range(POOL_SIZE):
		var label := Label.new()
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(label)
		_pool.append(label)

	EventBus.floating_text_requested.connect(_on_floating_text)
	EventBus.show_damage_number.connect(_on_damage_number)


func _process(delta: float) -> void:
	var finished: Array[Dictionary] = []

	for entry in _active:
		var label: Label = entry["label"]
		entry["timer"] -= delta

		if entry["timer"] <= 0.0:
			finished.append(entry)
			continue

		label.position += entry["vel"] * delta

		var fade_start := DURATION * 0.6
		var remaining: float = entry["timer"]
		if remaining < fade_start:
			label.modulate.a = remaining / fade_start

	for entry in finished:
		_return_to_pool(entry["label"])
		_active.erase(entry)

# ─── Spawn API ────────────────────────────────────────────────────────────────

func _on_damage_number(world_position: Vector3, damage: float, is_crit: bool, damage_type: String) -> void:
	var color := _get_damage_color(damage_type, is_crit)
	var text := "%.0f" % damage
	if is_crit:
		text = "CRIT! " + text
	var font_size := CRIT_FONT_SIZE if is_crit else NORMAL_FONT_SIZE
	_spawn(world_position, text, color, font_size)


func _on_floating_text(world_position: Vector3, text: String, color: Color) -> void:
	_spawn(world_position, text, color, NORMAL_FONT_SIZE)


func _spawn(world_position: Vector3, text: String, color: Color, font_size: int) -> void:
	var label := _get_from_pool()
	if label == null:
		return

	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)

	# Project 3D world position to 2D screen position.
	var camera: Camera3D = get_viewport().get_camera_3d()
	var canvas_pos: Vector2
	if camera:
		canvas_pos = camera.unproject_position(world_position)
	else:
		canvas_pos = Vector2.ZERO

	label.position = canvas_pos + Vector2(randf_range(-10, 10), 0)
	label.modulate.a = 1.0
	label.visible = true

	var vel := Vector2(randf_range(-8.0, 8.0), -FLOAT_SPEED)

	_active.append({
		"label": label,
		"timer": DURATION,
		"vel": vel,
	})

# ─── Pool Management ─────────────────────────────────────────────────────────

func _get_from_pool() -> Label:
	if _pool.is_empty():
		if _active.is_empty():
			return null
		var oldest: Dictionary = _active.pop_front()
		return oldest["label"]
	return _pool.pop_back()


func _return_to_pool(label: Label) -> void:
	label.visible = false
	label.modulate.a = 1.0
	_pool.append(label)

# ─── Colour Helpers ───────────────────────────────────────────────────────────

func _get_damage_color(damage_type: String, is_crit: bool) -> Color:
	var base_color := Color.WHITE
	match damage_type:
		"PHYSICAL": base_color = Color(1.0, 0.9, 0.8)
		"FIRE":     base_color = Color(1.0, 0.4, 0.1)
		"COLD":     base_color = Color(0.5, 0.8, 1.0)
		"LIGHTNING":base_color = Color(1.0, 1.0, 0.3)
		"POISON":   base_color = Color(0.4, 1.0, 0.3)
		"ARCANE":   base_color = Color(0.8, 0.4, 1.0)

	if is_crit:
		return base_color.lightened(0.3)
	return base_color
