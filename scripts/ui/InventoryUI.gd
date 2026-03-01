# InventoryUI.gd
# =============================================================================
# Diablo 2-style grid inventory UI.
# Renders the InventorySystem grid and handles drag-and-drop item movement.
#
# SCENE REQUIREMENTS:
#   GridContainer or Control  "Grid"           – parent for cell nodes
#   Control                   "DragPreview"    – follows mouse while dragging
#   TextureRect               "DragIcon"       – shows dragged item icon
#
# CELL_SIZE: pixels per inventory cell. Set to match your sprite grid.
# =============================================================================
class_name InventoryUI
extends Control

# ─── Configuration ────────────────────────────────────────────────────────────

const CELL_SIZE: int = 40

# ─── Nodes ────────────────────────────────────────────────────────────────────

@onready var grid_root: Control = get_node_or_null("Grid")
@onready var drag_preview: Control = get_node_or_null("DragPreview")
@onready var drag_icon: TextureRect = get_node_or_null("DragPreview/DragIcon")

# ─── State ────────────────────────────────────────────────────────────────────

var _inventory: InventorySystem = null

## Item currently being dragged, null if none.
var _dragging_item: BaseItem = null

## Grid position where the drag started.
var _drag_start_pos: Vector2i = Vector2i(-1, -1)

## All rendered slot controls. Index: row * cols + col.
var _cell_nodes: Array[Control] = []

## Item panels (one per item). Key: uid (String), Value: Control.
var _item_panels: Dictionary = {}

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _ready() -> void:
	if drag_preview:
		drag_preview.visible = false
	EventBus.ui_panel_toggled.connect(_on_ui_panel_toggled)
	EventBus.inventory_layout_changed.connect(_on_layout_changed)


## Call this to bind the UI to an inventory. Called by PlayerCharacter or HUD.
func bind_inventory(inventory: InventorySystem) -> void:
	if _inventory:
		_inventory.layout_changed.disconnect(_rebuild_display)
	_inventory = inventory
	_inventory.layout_changed.connect(_rebuild_display)
	_build_grid()
	_rebuild_display()


func _process(_delta: float) -> void:
	if _dragging_item:
		drag_preview.global_position = get_global_mouse_position() + Vector2(4, 4)

# ─── Grid Construction ────────────────────────────────────────────────────────

func _build_grid() -> void:
	if grid_root == null:
		return
	# Clear existing cells.
	for child in grid_root.get_children():
		child.queue_free()
	_cell_nodes.clear()

	var cols := _inventory.grid_size.x
	var rows := _inventory.grid_size.y

	grid_root.custom_minimum_size = Vector2(cols * CELL_SIZE, rows * CELL_SIZE)

	for row in range(rows):
		for col in range(cols):
			var cell := ColorRect.new()
			cell.size = Vector2(CELL_SIZE - 1, CELL_SIZE - 1)  # 1px gap.
			cell.position = Vector2(col * CELL_SIZE, row * CELL_SIZE)
			cell.color = Color(0.1, 0.1, 0.1, 0.8)
			grid_root.add_child(cell)
			_cell_nodes.append(cell)

# ─── Item Display ─────────────────────────────────────────────────────────────

func _rebuild_display() -> void:
	# Remove all item panels.
	for uid in _item_panels:
		_item_panels[uid].queue_free()
	_item_panels.clear()

	# Re-create panels for all items.
	for item: BaseItem in _inventory.get_all_items():
		_create_item_panel(item)


func _create_item_panel(item: BaseItem) -> void:
	var panel := Panel.new()
	var item_w := item.data.size.x * CELL_SIZE
	var item_h := item.data.size.y * CELL_SIZE
	panel.size = Vector2(item_w - 2, item_h - 2)
	panel.position = Vector2(
		item.grid_position.x * CELL_SIZE + 1,
		item.grid_position.y * CELL_SIZE + 1)

	# Colour by rarity.
	var style := StyleBoxFlat.new()
	style.bg_color = item.get_rarity_color().darkened(0.6)
	style.border_color = item.get_rarity_color()
	style.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", style)

	# Icon.
	if item.data.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = item.data.icon
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(icon_rect)

	# Stack quantity label (for consumables).
	if item.quantity > 1:
		var qty_label := Label.new()
		qty_label.text = str(item.quantity)
		qty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		qty_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		qty_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.add_child(qty_label)

	# Input events.
	panel.gui_input.connect(_on_item_panel_input.bind(item))
	panel.mouse_entered.connect(_on_item_hover_enter.bind(item))
	panel.mouse_exited.connect(_on_item_hover_exit)

	grid_root.add_child(panel)
	_item_panels[item.uid] = panel

# ─── Input ────────────────────────────────────────────────────────────────────

func _on_item_panel_input(event: InputEvent, item: BaseItem) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_begin_drag(item)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_on_right_click(item)


func _begin_drag(item: BaseItem) -> void:
	_dragging_item = item
	_drag_start_pos = item.grid_position

	# Show drag preview.
	if item.data.icon:
		drag_icon.texture = item.data.icon
	drag_preview.size = Vector2(
		item.data.size.x * CELL_SIZE,
		item.data.size.y * CELL_SIZE)
	drag_preview.visible = true

	# Hide the item panel while dragging.
	var panel := _item_panels.get(item.uid, null) as Control
	if panel:
		panel.modulate = Color(1, 1, 1, 0.3)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT and _dragging_item:
			_end_drag(event.global_position)


func _end_drag(drop_global_pos: Vector2) -> void:
	drag_preview.visible = false
	var item := _dragging_item
	_dragging_item = null

	# Convert global drop position to grid coordinate.
	var local_pos := drop_global_pos - grid_root.global_position
	var grid_pos := Vector2i(
		int(local_pos.x / CELL_SIZE),
		int(local_pos.y / CELL_SIZE))

	if not _inventory.move_item(item, grid_pos):
		# Failed — restore original display.
		var panel := _item_panels.get(item.uid, null) as Control
		if panel:
			panel.modulate = Color.WHITE
	# layout_changed signal will trigger _rebuild_display().


func _on_right_click(item: BaseItem) -> void:
	# Right-click: use consumables, open context menu for equipment.
	if item is ConsumableItem:
		var player := GameManager.player as PlayerCharacter
		if player:
			(item as ConsumableItem).use(player)
	elif item is EquipmentItem:
		# Try to equip/unequip.
		var player := GameManager.player as PlayerCharacter
		if player:
			player.equipment.swap_with_inventory(item as EquipmentItem, _inventory)

# ─── Tooltip ─────────────────────────────────────────────────────────────────

func _on_item_hover_enter(item: BaseItem) -> void:
	EventBus.tooltip_show_requested.emit(item, get_global_mouse_position())


func _on_item_hover_exit() -> void:
	EventBus.tooltip_hide_requested.emit()

# ─── Visibility ──────────────────────────────────────────────────────────────

func _on_ui_panel_toggled(panel_id: String, is_visible: bool) -> void:
	if panel_id == "inventory":
		visible = is_visible
		if is_visible:
			var player := GameManager.player as PlayerCharacter
			if player and player.inventory:
				bind_inventory(player.inventory)


func _on_layout_changed(_character: Node) -> void:
	_rebuild_display()
