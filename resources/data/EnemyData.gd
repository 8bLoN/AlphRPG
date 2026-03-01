# EnemyData.gd
# =============================================================================
# Resource that defines an enemy TYPE template.
# EnemyCharacter reads this on _ready() to set up its stats and behaviour.
#
# EXTENDING:
#   Add elite/boss modifiers as arrays of StatModifier here.
#   Add ability arrays (AI skill IDs) to give enemies active skills.
# =============================================================================
class_name EnemyData
extends Resource

# ─── Identity ─────────────────────────────────────────────────────────────────

@export var id: String = ""
@export var display_name: String = "Enemy"
@export_multiline var description: String = ""

# ─── Archetype ────────────────────────────────────────────────────────────────

enum Archetype { MELEE, RANGED, CASTER, TANK, ELITE, BOSS }
@export var archetype: Archetype = Archetype.MELEE

# ─── Base Stats ───────────────────────────────────────────────────────────────

@export_group("Stats")
@export var base_hp: float = 100.0
@export var hp_per_level: float = 20.0
@export var base_damage_min: float = 5.0
@export var base_damage_max: float = 10.0
@export var damage_per_level: float = 2.0
@export var base_armor: float = 5.0
@export var armor_per_level: float = 1.0
@export var movement_speed: float = 150.0
@export var attack_speed: float = 1.0   # Attacks per second.

## Base resistances (fire, cold, lightning, poison). 0–75.
@export var base_resistances: Dictionary = {
	"fire_resistance": 0.0,
	"cold_resistance": 0.0,
	"lightning_resistance": 0.0,
	"poison_resistance": 0.0,
}

# ─── Experience & Loot ────────────────────────────────────────────────────────

@export_group("Rewards")
@export var xp_reward: int = 50
@export var xp_per_level: int = 10

## Weight probability of dropping loot (0.0–1.0).
@export var loot_chance: float = 0.5

## Item level of dropped items (0 = use zone level).
@export var loot_item_level: int = 0

## Loot table ID (looked up in LootSystem).
@export var loot_table_id: String = "common_enemy"

## Number of items to drop (range).
@export var loot_count_min: int = 0
@export var loot_count_max: int = 2

# ─── AI ───────────────────────────────────────────────────────────────────────

@export_group("AI")

## Detection radius for switching from patrol to aggro.
@export var aggro_radius: float = 300.0

## Lose aggro if target gets further than this.
@export var deaggro_radius: float = 500.0

## Attack range (melee ≈ 60, ranged ≈ 400).
@export var attack_range: float = 60.0

## Distance enemy maintains from target (for ranged/casters).
@export var preferred_distance: float = 0.0

## IDs of skills this enemy can use (linked to SkillData resources).
@export var skill_ids: Array[String] = []

## Patrol radius around spawn point.
@export var patrol_radius: float = 200.0

## Seconds between patrol waypoint changes.
@export var patrol_wait_time: float = 2.0

# ─── Visual ───────────────────────────────────────────────────────────────────

@export_group("Visual")
@export var sprite_sheet: Texture2D = null
@export var sprite_frames: SpriteFrames = null
@export var scale: Vector2 = Vector2.ONE
@export var health_bar_offset: Vector2 = Vector2(0.0, -50.0)
