# EnemyCharacter.gd
# =============================================================================
# Base enemy character. Extends BaseCharacter with:
#   • EnemyData resource loading (stats, AI config, loot table)
#   • EnemyAI controller
#   • XP grant to killer on death
#   • Loot drop on death
#   • Health bar driven by EventBus
# =============================================================================
class_name EnemyCharacter
extends BaseCharacter

# ─── Configuration ────────────────────────────────────────────────────────────

@export var enemy_data: EnemyData = null

## Override: level of this specific enemy instance.
## If 0, uses the zone's recommended level.
@export var enemy_level: int = 0

# ─── AI ───────────────────────────────────────────────────────────────────────

var ai_controller: EnemyAI = null

# ─── Derived at runtime ───────────────────────────────────────────────────────

var _effective_level: int = 1
var _xp_reward: int = 0

# ─── Godot Lifecycle ─────────────────────────────────────────────────────────

func _on_ready() -> void:
	faction = 1  # Enemy faction.

	if enemy_data == null:
		push_error("EnemyCharacter '%s' has no EnemyData resource." % name)
		return

	_effective_level = enemy_level if enemy_level > 0 else stats.level
	stats.level = _effective_level

	_setup_ai()


func _initialize_stats() -> void:
	if enemy_data == null:
		return

	# Set primary stats derived from EnemyData formulas and level.
	var lvl := maxf(1.0, float(enemy_level if enemy_level > 0 else 1))

	# Map EnemyData flat stats into CharacterStats modifiers.
	var hp := enemy_data.base_hp + enemy_data.hp_per_level * (lvl - 1)
	var dmg_min := enemy_data.base_damage_min + enemy_data.damage_per_level * (lvl - 1)
	var dmg_max := enemy_data.base_damage_max + enemy_data.damage_per_level * (lvl - 1)
	var armor := enemy_data.base_armor + enemy_data.armor_per_level * (lvl - 1)

	# Apply as FLAT overrides on top of base (which starts very low for enemies).
	stats.add_modifier(StatModifier.new("enemy/max_hp",   "max_hp",   hp,       StatModifier.Type.FLAT))
	stats.add_modifier(StatModifier.new("enemy/min_dmg",  "min_damage", dmg_min, StatModifier.Type.FLAT))
	stats.add_modifier(StatModifier.new("enemy/max_dmg",  "max_damage", dmg_max, StatModifier.Type.FLAT))
	stats.add_modifier(StatModifier.new("enemy/armor",    "armor",    armor,    StatModifier.Type.FLAT))
	stats.add_modifier(StatModifier.new("enemy/move_spd", "movement_speed",
		enemy_data.movement_speed, StatModifier.Type.FLAT))
	stats.add_modifier(StatModifier.new("enemy/atk_spd",  "attack_speed",
		enemy_data.attack_speed,   StatModifier.Type.FLAT))

	# Resistances.
	for res_stat: String in enemy_data.base_resistances:
		var res_val: float = enemy_data.base_resistances[res_stat]
		if res_val > 0.0:
			stats.add_modifier(StatModifier.new("enemy/" + res_stat, res_stat, res_val, StatModifier.Type.FLAT))

	stats.restore_full()

	# Cache XP reward.
	_xp_reward = enemy_data.xp_reward + enemy_data.xp_per_level * (int(lvl) - 1)

	# Apply difficulty scaling.
	var hp_mult: float = GameManager.difficulty_multipliers.get("enemy_hp", 1.0)
	var dmg_mult: float = GameManager.difficulty_multipliers.get("enemy_damage", 1.0)
	if not is_equal_approx(hp_mult, 1.0):
		stats.add_modifier(StatModifier.new("diff/hp", "max_hp", hp_mult - 1.0, StatModifier.Type.PERCENT_MULT))
	if not is_equal_approx(dmg_mult, 1.0):
		stats.add_modifier(StatModifier.new("diff/dmg_min", "min_damage", dmg_mult - 1.0, StatModifier.Type.PERCENT_MULT))
		stats.add_modifier(StatModifier.new("diff/dmg_max", "max_damage", dmg_mult - 1.0, StatModifier.Type.PERCENT_MULT))


func _setup_skill_tree() -> void:
	super._setup_skill_tree()
	# Register any skills the enemy can use.
	if enemy_data:
		for skill_id: String in enemy_data.skill_ids:
			var skill_res: SkillData = SkillDatabase.get_skill(skill_id)
			if skill_res:
				skill_tree.register_skill(skill_res)


func _setup_ai() -> void:
	ai_controller = EnemyAI.new(self, enemy_data)
	ai_controller.name = "EnemyAI"
	add_child(ai_controller)

# ─── Death Handling ───────────────────────────────────────────────────────────

func _on_death() -> void:
	# Award XP to the killer (player).
	var player := GameManager.player
	if player and player.has_method("gain_experience"):
		player.gain_experience(_xp_reward)

	EventBus.enemy_killed.emit(self, player)

	# Drop loot.
	if enemy_data and randf() < enemy_data.loot_chance:
		_drop_loot()

	# Remove the node after a delay (let death animation play).
	await get_tree().create_timer(3.0).timeout
	queue_free()


func _drop_loot() -> void:
	if enemy_data == null:
		return

	var count := randi_range(enemy_data.loot_count_min, enemy_data.loot_count_max)
	var item_level := enemy_data.loot_item_level if enemy_data.loot_item_level > 0 else _effective_level

	var items: Array = []
	for _i in range(count):
		var item := ItemFactory.generate_random_item(item_level, enemy_data.loot_table_id)
		if item:
			items.append(item)

	if items.size() > 0:
		EventBus.loot_spawned.emit(global_position, items)


# ─── Utility ─────────────────────────────────────────────────────────────────

## Returns the EnemyData config (for AI and external systems).
func get_data() -> EnemyData:
	return enemy_data
