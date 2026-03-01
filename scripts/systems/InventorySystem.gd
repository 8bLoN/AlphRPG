# InventorySystem.gd
# =============================================================================
# Grid-based inventory storage (Diablo 2 style).
# Each item occupies a rectangular area of cells defined by item.data.size.
#
# GRID INTERNALS:
#   _grid is a 2D Array (rows × columns) where each cell is either null (empty)
#   or a reference to the BaseItem occupying it. Items spanning multiple cells
#   all point to the SAME item instance, so we don't store duplicate data.
#
# PERFORMANCE:
#   - add_item: O(w×h×cols×rows) worst case for the slot scan.
#   - remove_item: O(w×h) — always fast since grid_position is stored on the item.
#   - move_item: O(w×h) for clear + place.
#   For inventory sizes up to 12×10 this is completely negligible.
#
# EXTENDING:
#   • Add weight limits: track current_weight vs max_weight.
#   • Add tab support: multiple InventorySystem instances (stash tabs).
#   • Add sorting: sort_by_type() iterates _items and re-places after clearing.
# =============================================================================
class_name InventorySystem
extends RefCounted

# ─── Signals ──────────────────────────────────────────────────────────────────

signal item_added(item: BaseItem)
signal item_removed(item: BaseItem)
signal layout_changed()

# ─── Grid ─────────────────────────────────────────────────────────────────────

## Grid dimensions: x = columns (width), y = rows (height).
var grid_size: Vector2i = Vector2i(10, 4)

## 2D grid. Access: _grid[row][col] → BaseItem or null.
var _grid: Array = []

## All items currently stored (no duplicates).
var _items: Array[BaseItem] = []

# ─── Weight ───────────────────────────────────────────────────────────────────

var max_weight: float = 0.0   # 0 = unlimited.
var current_weight: float = 0.0

# ─── Initialisation ───────────────────────────────────────────────────────────

func _init(columns: int = 10, rows: int = 4, weight_limit: float = 0.0) -> void:
	grid_size = Vector2i(columns, rows)
	max_weight = weight_limit
	_rebuild_grid()

# ─── Placement API ────────────────────────────────────────────────────────────

## Add an item, automatically finding the first available slot.
## Returns true if placed, false if inventory is full or weight exceeded.
func add_item(item: BaseItem) -> bool:
	if max_weight > 0.0 and current_weight + item.data.weight > max_weight:
		return false

	# Try to merge with existing stack first (consumables).
	if item is ConsumableItem and item.data.max_stack > 1:
		if _try_merge_into_existing(item):
			return true

	var slot := find_free_slot(item.data.size)
	if slot.x < 0:
		return false

	return place_item(item, slot)


## Place an item at a specific grid coordinate.
## Returns true on success, false if the position is invalid or occupied.
func place_item(item: BaseItem, grid_pos: Vector2i) -> bool:
	if not can_place_item(item, grid_pos):
		return false

	_occupy_cells(item, grid_pos)
	item.grid_position = grid_pos
	_items.append(item)
	current_weight += item.data.weight

	item_added.emit(item)
	layout_changed.emit()
	return true


## Remove an item from the inventory.
## Returns true if the item was present and removed.
func remove_item(item: BaseItem) -> bool:
	if not _items.has(item):
		return false

	_clear_cells(item)
	_items.erase(item)
	current_weight -= item.data.weight
	item.grid_position = Vector2i(-1, -1)

	item_removed.emit(item)
	layout_changed.emit()
	return true


## Move an item to a new grid position within the inventory.
## Returns true on success (false if target position is invalid or blocked).
func move_item(item: BaseItem, new_pos: Vector2i) -> bool:
	if not _items.has(item):
		return false

	var old_pos := item.grid_position

	# Temporarily vacate current cells so can_place_item doesn't block on itself.
	_clear_cells(item)

	if not can_place_item(item, new_pos):
		# Restore original position.
		_occupy_cells(item, old_pos)
		return false

	_occupy_cells(item, new_pos)
	item.grid_position = new_pos
	layout_changed.emit()
	return true


## Swap two items within the inventory.
## Only works if both items fit in each other's original positions.
func swap_items(item_a: BaseItem, item_b: BaseItem) -> bool:
	if not _items.has(item_a) or not _items.has(item_b):
		return false

	var pos_a := item_a.grid_position
	var pos_b := item_b.grid_position

	# Temporarily clear both.
	_clear_cells(item_a)
	_clear_cells(item_b)

	# Check both can fit in the swapped positions.
	var a_fits := can_place_item(item_a, pos_b)
	var b_fits := can_place_item(item_b, pos_a)

	if a_fits and b_fits:
		_occupy_cells(item_a, pos_b)
		_occupy_cells(item_b, pos_a)
		item_a.grid_position = pos_b
		item_b.grid_position = pos_a
		layout_changed.emit()
		return true

	# Restore original positions on failure.
	_occupy_cells(item_a, pos_a)
	_occupy_cells(item_b, pos_b)
	return false

# ─── Query API ────────────────────────────────────────────────────────────────

## Returns the item at a grid coordinate, or null if empty.
func get_item_at(grid_pos: Vector2i) -> BaseItem:
	if not _in_bounds(grid_pos.x, grid_pos.y):
		return null
	return _grid[grid_pos.y][grid_pos.x]


## Find the first grid position where an item of the given size fits.
## Returns Vector2i(-1, -1) if no slot is available.
func find_free_slot(item_size: Vector2i) -> Vector2i:
	for row in range(grid_size.y):
		for col in range(grid_size.x):
			if _fits_at(item_size, Vector2i(col, row)):
				return Vector2i(col, row)
	return Vector2i(-1, -1)


## Returns true if an item can be placed at the given position without conflict.
func can_place_item(item: BaseItem, grid_pos: Vector2i) -> bool:
	return _fits_at(item.data.size, grid_pos)


## Returns all items currently in the inventory.
func get_all_items() -> Array[BaseItem]:
	return _items.duplicate()


## Returns a list of items matching a predicate (for sorting, filtering).
func find_items(predicate: Callable) -> Array[BaseItem]:
	return _items.filter(predicate)


## Returns true if the inventory has no free 1×1 cells.
func is_full() -> bool:
	return find_free_slot(Vector2i(1, 1)).x < 0


## Count of free 1×1 cells (approximate inventory usage display).
func count_free_cells() -> int:
	var count := 0
	for row in range(grid_size.y):
		for col in range(grid_size.x):
			if _grid[row][col] == null:
				count += 1
	return count


## Number of items in the inventory (not counting stack quantities).
func item_count() -> int:
	return _items.size()

# ─── Serialisation ────────────────────────────────────────────────────────────

func serialize() -> Dictionary:
	var items_data := []
	for item: BaseItem in _items:
		items_data.append(item.serialize())
	return {
		"grid_w": grid_size.x,
		"grid_h": grid_size.y,
		"items": items_data,
	}

# ─── Internal ─────────────────────────────────────────────────────────────────

func _rebuild_grid() -> void:
	_grid.clear()
	for _row in range(grid_size.y):
		var row_arr := []
		for _col in range(grid_size.x):
			row_arr.append(null)
		_grid.append(row_arr)


func _fits_at(size: Vector2i, pos: Vector2i) -> bool:
	if pos.x < 0 or pos.y < 0:
		return false
	if pos.x + size.x > grid_size.x or pos.y + size.y > grid_size.y:
		return false
	for r in range(size.y):
		for c in range(size.x):
			if _grid[pos.y + r][pos.x + c] != null:
				return false
	return true


func _occupy_cells(item: BaseItem, pos: Vector2i) -> void:
	for r in range(item.data.size.y):
		for c in range(item.data.size.x):
			_grid[pos.y + r][pos.x + c] = item


func _clear_cells(item: BaseItem) -> void:
	var pos := item.grid_position
	for r in range(item.data.size.y):
		for c in range(item.data.size.x):
			var gr := pos.y + r
			var gc := pos.x + c
			if _in_bounds(gc, gr) and _grid[gr][gc] == item:
				_grid[gr][gc] = null


func _in_bounds(col: int, row: int) -> bool:
	return col >= 0 and row >= 0 and col < grid_size.x and row < grid_size.y


func _try_merge_into_existing(new_item: ConsumableItem) -> bool:
	for existing: BaseItem in _items:
		if not (existing is ConsumableItem):
			continue
		var stack := existing as ConsumableItem
		if stack.data.id != new_item.data.id:
			continue
		if stack.quantity >= stack.data.max_stack:
			continue
		var excess := stack.try_merge(new_item)
		if excess <= 0:
			layout_changed.emit()
			return true  # Fully merged.
		new_item.quantity = excess
		# Continue to next stack if partial merge.

	return false
