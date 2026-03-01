# SkillBar.gd
# =============================================================================
# HUD skill hotbar with cooldown overlay.
# Displays up to 6 skill slots. Each slot shows:
#   • Skill icon
#   • Cooldown overlay (darkened + timer label)
#   • Mana cost indicator
#   • Keybind hint label
#
# SCENE REQUIREMENTS (for each SlotN child):
#   TextureRect    "Icon"
#   ColorRect      "CooldownOverlay"
#   Label          "CooldownLabel"
#   Label          "KeyLabel"
# =============================================================================
class_name SkillBar
extends HBoxContainer

const SLOT_COUNT: int = 6
const KEYBINDS: Array[String] = ["LMB", "RMB", "1", "2", "3", "4"]

var _slots: Array[Control] = []
var _skill_ids: Array[String] = []  # Skill ID assigned to each slot ("" = empty).

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	_skill_ids.resize(SLOT_COUNT)
	_skill_ids.fill("")

	# Collect slot nodes by index.
	for i in range(SLOT_COUNT):
		var slot := find_child("Slot%d" % i, true, false) as Control
		if slot:
			_slots.append(slot)
			# Show keybind label.
			var key_label := slot.find_child("KeyLabel", true, false) as Label
			if key_label:
				key_label.text = KEYBINDS[i] if i < KEYBINDS.size() else str(i)
		else:
			_slots.append(null)

	# Subscribe to cooldown updates.
	EventBus.skill_cooldown_updated.connect(_on_cooldown_updated)
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)

	# Wait for player to be registered before populating.
	GameManager.phase_changed.connect(_on_phase_changed)
	call_deferred("_refresh_from_player")


func _on_phase_changed(_old: int, new_phase: int) -> void:
	if new_phase == GameManager.GamePhase.PLAYING:
		call_deferred("_refresh_from_player")

# ─── Slot Population ─────────────────────────────────────────────────────────

## Populate a slot with a skill. Called by UI drag-and-drop or auto-assignment.
func assign_skill(slot: int, skill_data: SkillData) -> void:
	if slot < 0 or slot >= SLOT_COUNT:
		return
	_skill_ids[slot] = skill_data.id if skill_data else ""
	_update_slot_display(slot, skill_data)


func _refresh_from_player() -> void:
	var player := GameManager.player
	if not is_instance_valid(player) or not "skill_tree" in player:
		return
	var tree: SkillTree = player.skill_tree
	if tree == null:
		return

	for slot in range(SLOT_COUNT):
		var skill_id: String = tree.get_skill_bar().get(slot, "")
		_skill_ids[slot] = skill_id
		if skill_id.is_empty():
			_update_slot_display(slot, null)
		else:
			_update_slot_display(slot, tree.get_skill_data(skill_id))

# ─── Cooldown Handling ────────────────────────────────────────────────────────

func _on_cooldown_updated(skill_id: String, remaining: float, total: float) -> void:
	for i in range(SLOT_COUNT):
		if _skill_ids[i] == skill_id:
			_set_slot_cooldown(i, remaining, total)


func _set_slot_cooldown(slot: int, remaining: float, total: float) -> void:
	var slot_node := _slots[slot] if slot < _slots.size() else null
	if slot_node == null:
		return

	var overlay := slot_node.find_child("CooldownOverlay", true, false) as ColorRect
	var label := slot_node.find_child("CooldownLabel", true, false) as Label

	if remaining > 0.0:
		if overlay:
			overlay.visible = true
			# Shrink from bottom: modulate the rect height.
			overlay.anchor_top = 1.0 - (remaining / total)
		if label:
			label.visible = true
			label.text = "%.1f" % remaining
	else:
		if overlay:
			overlay.visible = false
		if label:
			label.visible = false

# ─── Slot Display ─────────────────────────────────────────────────────────────

func _update_slot_display(slot: int, skill_data: SkillData) -> void:
	var slot_node := _slots[slot] if slot < _slots.size() else null
	if slot_node == null:
		return

	var icon := slot_node.find_child("Icon", true, false) as TextureRect
	if icon:
		icon.texture = skill_data.icon if skill_data else null

	_set_slot_cooldown(slot, 0.0, 1.0)  # Reset cooldown display.


func _on_panel_toggled(_panel_id: String, _visible: bool) -> void:
	pass  # Reserved for future SkillBar hide/show logic.
