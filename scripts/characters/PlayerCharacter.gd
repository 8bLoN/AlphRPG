# PlayerCharacter.gd
# =============================================================================
# The playable character. Extends BaseCharacter with:
#   • Mouse-click movement (click-to-move, Diablo style, 3D raycast)
#   • LMB = move or auto-attack, RMB = primary skill
#   • XP + levelling, inventory + equipment systems
# =============================================================================
class_name PlayerCharacter
extends BaseCharacter

@export var class_data: CharacterClassData = null
@export var pickup_radius: float = 64.0

# ─── Progression ──────────────────────────────────────────────────────────────

var gold: int = 500
var experience: int = 0
var experience_to_next_level: int = 100
var unspent_stat_points: int = 0
var unspent_skill_points: int = 0

# ─── Systems ─────────────────────────────────────────────────────────────────

var inventory: InventorySystem = null
var equipment: EquipmentSystem = null

# ─── Visual Layers (3D MeshInstance3D) ────────────────────────────────────────
@onready var _layer_helmet: MeshInstance3D = get_node_or_null("VisualRoot/Head") as MeshInstance3D
@onready var _layer_chest: MeshInstance3D = get_node_or_null("VisualRoot/Body") as MeshInstance3D
@onready var _layer_weapon: MeshInstance3D = get_node_or_null("VisualRoot/WeaponBlade") as MeshInstance3D

var _visual_layers: Dictionary = {}

# ─── Input State ─────────────────────────────────────────────────────────────

var _mouse_world_pos: Vector3 = Vector3.ZERO
var _hovered_target: BaseCharacter = null
var _inventory_open: bool = false
var _character_open: bool = false
var _skill_tree_open: bool = false
var _equipment_open: bool = false
var _auto_attack_cooldown: float = 0.0

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _on_ready() -> void:
	GameManager.register_player(self)
	faction = 0
	_initialize_inventory()
	_initialize_visual_layers()
	_setup_default_skills()
	EventBus.item_equipped.connect(_on_item_equipped)
	EventBus.item_unequipped.connect(_on_item_unequipped)


func _initialize_stats() -> void:
	if class_data:
		stats.initialize_from_class_data(class_data)
	else:
		stats.strength = 15
		stats.dexterity = 10
		stats.intelligence = 8
		stats.vitality = 12
	stats.restore_full()


func _setup_skill_tree() -> void:
	super._setup_skill_tree()
	if class_data:
		for skill_res: SkillData in class_data.available_skills:
			skill_tree.register_skill(skill_res)


func _initialize_inventory() -> void:
	inventory = InventorySystem.new(10, 4)
	equipment = EquipmentSystem.new(self)
	if class_data:
		for item_id in class_data.starting_item_ids:
			var item := ItemDatabase.create_item(item_id, 1)
			if item:
				inventory.add_item(item)


func _initialize_visual_layers() -> void:
	_visual_layers = {}


func _setup_default_skills() -> void:
	# Register every skill .tres found in the data folder so the tree UI shows all skills.
	var dir := DirAccess.open("res://data/skills/")
	if dir:
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname.length() > 0:
			if fname.ends_with(".tres") or fname.ends_with(".res"):
				var res := ResourceLoader.load("res://data/skills/" + fname)
				if res is SkillData and not (res as SkillData).id.is_empty():
					skill_tree.register_skill(res)
			fname = dir.get_next()
		dir.list_dir_end()
	# Learn and slot the three starting skills.
	for entry: Array in [["mage_fireball", 0], ["warrior_bash", 1], ["rogue_backstab", 2]]:
		var sid: String = entry[0]
		var slot: int = entry[1]
		if skill_tree.get_skill_data(sid) != null:
			skill_tree.learn_or_upgrade(sid)
			skill_tree.assign_to_slot(slot, sid)

# ─── Input ────────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.is_playing():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_mouse_world_pos = _get_mouse_world_pos_3d()
		if _hovered_target and _hovered_target.faction != faction:
			_initiate_auto_attack(_hovered_target)
		else:
			move_to(_mouse_world_pos)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_mouse_world_pos = _get_mouse_world_pos_3d()
		use_skill(0, _mouse_world_pos)

	for i in range(1, 5):
		if event.is_action_pressed("skill_%d" % i):
			use_skill(i, _get_mouse_world_pos_3d())

	if event.is_action_pressed("toggle_inventory"):
		_inventory_open = not _inventory_open
		EventBus.ui_panel_toggled.emit("inventory", _inventory_open)
	if event.is_action_pressed("toggle_character"):
		_character_open = not _character_open
		EventBus.ui_panel_toggled.emit("character", _character_open)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_S:
			_skill_tree_open = not _skill_tree_open
			EventBus.ui_panel_toggled.emit("skill_tree", _skill_tree_open)
		elif event.keycode == KEY_E:
			_equipment_open = not _equipment_open
			EventBus.ui_panel_toggled.emit("equipment", _equipment_open)
	if event.is_action_pressed("ui_cancel"):
		GameManager.toggle_pause()


func _process(delta: float) -> void:
	_update_hovered_target()
	_auto_attack_cooldown = maxf(0.0, _auto_attack_cooldown - delta)

# ─── 3D Mouse World Position ──────────────────────────────────────────────────

func _get_mouse_world_pos_3d() -> Vector3:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return global_position
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if is_zero_approx(dir.y):
		return global_position
	var t := -from.y / dir.y
	return from + dir * t

# ─── Auto Attack ─────────────────────────────────────────────────────────────

func _initiate_auto_attack(target: BaseCharacter) -> void:
	if _auto_attack_cooldown > 0.0:
		return
	_attack_target_pos = target.global_position
	var attack_range := 80.0 * WORLD_SCALE
	if global_position.distance_to(target.global_position) > attack_range:
		move_to(target.global_position)
		return
	_auto_attack_cooldown = 0.9
	state_machine.transition_to("attack")
	_perform_auto_attack(target)


func _perform_auto_attack(target: BaseCharacter) -> void:
	if not is_instance_valid(target) or not target.is_targetable():
		return
	var base_dmg := randf_range(stats.get_stat("min_damage"), stats.get_stat("max_damage"))
	var result := CombatManager.calculate_damage(stats, target.stats, base_dmg)
	target.take_damage(result)
	var steal_pct := stats.get_stat("life_steal")
	if steal_pct > 0.0:
		receive_healing(result["final_damage"] * steal_pct / 100.0)

# ─── Experience & Levelling ──────────────────────────────────────────────────

func gain_experience(amount: int) -> void:
	var scaled := int(amount * GameManager.difficulty_multipliers.get("xp_gain", 1.0))
	experience += scaled
	EventBus.experience_changed.emit(experience, experience_to_next_level)
	while experience >= experience_to_next_level:
		experience -= experience_to_next_level
		_level_up()


func _level_up() -> void:
	stats.level += 1
	experience_to_next_level = _calc_xp_to_next(stats.level)
	if class_data:
		stats.apply_level_growth(class_data)
		unspent_stat_points += class_data.stat_points_per_level
		unspent_skill_points += class_data.skill_points_per_level
	else:
		unspent_stat_points += 5
		unspent_skill_points += 1
	stats.restore_full()
	EventBus.character_leveled_up.emit(self, stats.level)
	EventBus.stat_points_available.emit(unspent_stat_points)
	EventBus.skill_points_available.emit(unspent_skill_points)


func _calc_xp_to_next(level: int) -> int:
	return int(100.0 * pow(1.15, level - 1))


func allocate_stat_point(stat_name: String) -> bool:
	if unspent_stat_points <= 0:
		return false
	match stat_name:
		"strength":     stats.strength += 1
		"dexterity":    stats.dexterity += 1
		"intelligence": stats.intelligence += 1
		"vitality":     stats.vitality += 1
		_:
			push_warning("PlayerCharacter: Unknown stat '%s'." % stat_name)
			return false
	unspent_stat_points -= 1
	return true


func allocate_skill_point(skill_id: String) -> bool:
	if unspent_skill_points <= 0:
		return false
	if skill_tree.learn_or_upgrade(skill_id):
		unspent_skill_points -= 1
		return true
	return false

# ─── Equipment Visual System ──────────────────────────────────────────────────

func _on_item_equipped(character: Node, _item: Variant, _slot: String) -> void:
	if character != self:
		return


func _on_item_unequipped(character: Node, _item: Variant, _slot: String) -> void:
	if character != self:
		return

# ─── Death Override ───────────────────────────────────────────────────────────

func _on_death() -> void:
	GameManager.unregister_player()
	await get_tree().create_timer(2.0).timeout
	GameManager.set_phase(GameManager.GamePhase.GAME_OVER)

# ─── Hover Detection (3D raycast) ────────────────────────────────────────────

func _update_hovered_target() -> void:
	_hovered_target = null
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse_pos)
	var to := from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, 4)
	var result := space.intersect_ray(params)
	if result:
		var body: Node = result.collider
		if body is Area3D:
			body = body.get_parent()
		if body is BaseCharacter and body != self and body.is_targetable():
			_hovered_target = body
