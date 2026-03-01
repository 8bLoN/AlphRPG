# ItemDatabase.gd
# =============================================================================
# Autoloaded singleton that serves as the global registry for:
#   • ItemData resources   (item base types)
#   • Affix definitions    (prefix/suffix pools)
#   • Loot tables          (zone/enemy drop tables)
#
# SETUP:
#   All ItemData .tres files in res://data/items/ are loaded automatically.
#   Affix definitions are loaded from res://data/items/affixes.json.
#   Loot tables are loaded from res://data/items/loot_tables.json.
#
# EXTENDING:
#   • To add a new item: create a new ItemData .tres file in res://data/items/.
#     It will be picked up automatically on next run.
#   • To add new affixes: add entries to affixes.json.
#   • To add loot tables: add entries to loot_tables.json.
# =============================================================================
extends Node

# ─── Registries ───────────────────────────────────────────────────────────────

## All loaded ItemData resources. Key: ItemData.id.
var _items: Dictionary = {}

## All affix definitions. Key: affix id (String). Value: Dictionary.
var _affixes: Dictionary = {}

## Loot tables. Key: table_id (String). Value: Array of { "item_id", "weight" }.
var _loot_tables: Dictionary = {}

# ─── Initialisation ───────────────────────────────────────────────────────────

func _ready() -> void:
	_load_item_resources()
	_load_affixes()
	_load_loot_tables()
	print("ItemDatabase: Loaded %d items, %d affixes." % [_items.size(), _affixes.size()])

# ─── Item API ─────────────────────────────────────────────────────────────────

## Returns the ItemData resource for a given id, or null.
func get_item_data(item_id: String) -> ItemData:
	return _items.get(item_id, null)


## Returns all registered ItemData resources.
func get_all_items() -> Array:
	return _items.values()


## Create an item instance from an id and item level.
## Delegates to ItemFactory for full affix rolling.
func create_item(item_id: String, item_level: int, magic_find: float = 0.0) -> BaseItem:
	return ItemFactory.create_item(item_id, item_level, magic_find)


## Register an ItemData programmatically (useful for test setups).
func register_item(item_data: ItemData) -> void:
	if item_data.id.is_empty():
		push_error("ItemDatabase.register_item: ItemData has no id.")
		return
	_items[item_data.id] = item_data

# ─── Affix API ────────────────────────────────────────────────────────────────

## Returns an affix definition Dictionary, or {} if not found.
func get_affix(affix_id: String) -> Dictionary:
	return _affixes.get(affix_id, {})


## Returns all affix IDs.
func get_all_affix_ids() -> Array[String]:
	var result: Array[String] = []
	for k: String in _affixes:
		result.append(k)
	return result

# ─── Loot Table API ───────────────────────────────────────────────────────────

## Returns a random ItemData from a loot table, weighted by entry weights.
## Returns null if the table is empty or not found.
func get_random_item_from_table(table_id: String, item_level: int) -> ItemData:
	var table: Array = _loot_tables.get(table_id, [])
	if table.is_empty():
		# Fall back to a completely random item from all registered items.
		return _random_item_by_level(item_level)

	# Filter entries by item level, then pick by weight.
	var eligible: Array = table.filter(func(entry: Dictionary) -> bool:
		var item_data: ItemData = _items.get(entry.get("item_id", ""), null)
		if item_data == null:
			return false
		if item_data.min_item_level > item_level:
			return false
		if item_data.max_item_level > 0 and item_data.max_item_level < item_level:
			return false
		return true)

	if eligible.is_empty():
		return null

	# Weighted random selection.
	var total_weight := 0
	for entry: Dictionary in eligible:
		total_weight += entry.get("weight", 1)

	var roll := randi_range(0, total_weight - 1)
	var cumulative := 0
	for entry: Dictionary in eligible:
		cumulative += entry.get("weight", 1)
		if roll < cumulative:
			return _items.get(entry.get("item_id", ""), null)

	return null

# ─── Internal Loading ────────────────────────────────────────────────────────

func _load_item_resources() -> void:
	var dir := DirAccess.open("res://data/items/")
	if dir == null:
		push_warning("ItemDatabase: res://data/items/ not found.")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name.length() > 0:
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path := "res://data/items/" + file_name
			var res := ResourceLoader.load(path)
			if res is ItemData:
				_items[res.id] = res
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_affixes() -> void:
	var path := "res://data/items/affixes.json"
	if not FileAccess.file_exists(path):
		push_warning("ItemDatabase: affixes.json not found at '%s'. No affixes loaded." % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("ItemDatabase: Failed to parse affixes.json.")
		return

	var data = json.data
	if data is Array:
		for entry in data:
			if entry is Dictionary and entry.has("id"):
				_affixes[entry["id"]] = entry


func _load_loot_tables() -> void:
	var path := "res://data/items/loot_tables.json"
	if not FileAccess.file_exists(path):
		push_warning("ItemDatabase: loot_tables.json not found.")
		return

	var file := FileAccess.open(path, FileAccess.READ)
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("ItemDatabase: Failed to parse loot_tables.json.")
		return

	var data = json.data
	if data is Dictionary:
		for table_id: String in data:
			_loot_tables[table_id] = data[table_id]


func _random_item_by_level(item_level: int) -> ItemData:
	var eligible: Array = []
	for item: ItemData in _items.values():
		if item.min_item_level <= item_level:
			eligible.append(item)
	if eligible.is_empty():
		return null
	return eligible[randi() % eligible.size()]
