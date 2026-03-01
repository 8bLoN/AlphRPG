# SkillData.gd
# =============================================================================
# Resource that defines a skill TEMPLATE.
# One .tres per skill. Scripts extend BaseSkill and reference a SkillData
# resource for their configuration, keeping logic and data separated.
#
# SKILL TREE LAYOUT:
#   Each SkillData has a tree_position (column, row) used by the SkillTree UI.
#   prerequisites list skill_ids that must be learned first.
#   max_rank controls how many times a skill can be upgraded.
#
# SCALING:
#   damage_per_rank / cost_per_rank are applied per rank level so skills
#   improve meaningfully as the player invests more points.
# =============================================================================
class_name SkillData
extends Resource

# ─── Identity ─────────────────────────────────────────────────────────────────

## Unique identifier. Never change after shipping — used in save data.
@export var id: String = ""

## Display name shown in tooltips and skill bar.
@export var display_name: String = ""

@export_multiline var description: String = ""

## Class this skill belongs to (e.g. "warrior", "mage", "rogue").
@export var class_id: String = ""

# ─── Type ─────────────────────────────────────────────────────────────────────

enum SkillType { ACTIVE, PASSIVE, TOGGLE }

@export var skill_type: SkillType = SkillType.ACTIVE

## Script path to the implementation class (e.g. "res://scripts/skills/mage/Fireball.gd").
## SkillTree instantiates this script to create the live skill node.
@export var script_path: String = ""

## Scene to instantiate for the skill's visual effect / projectile.
@export var skill_scene: PackedScene = null

# ─── Cost & Cooldown ──────────────────────────────────────────────────────────

@export_group("Cost & Cooldown")

## Resource spent on activation.
enum ResourceType { MANA, STAMINA, HEALTH, NONE }
@export var resource_type: ResourceType = ResourceType.MANA

## Base cost at rank 1.
@export var base_cost: float = 10.0

## Additional cost per rank.
@export var cost_per_rank: float = 2.0

## Cooldown in seconds at rank 1.
@export var base_cooldown: float = 1.0

## Cooldown reduction per rank (can be negative to increase cooldown).
@export var cooldown_per_rank: float = -0.1

## Cast time in seconds (0 = instant).
@export var cast_time: float = 0.0

# ─── Damage ───────────────────────────────────────────────────────────────────

@export_group("Damage")

@export var base_damage: float = 0.0
@export var damage_per_rank: float = 5.0
@export var damage_type: int = 0      # CombatManager.DamageType
@export var skill_multiplier: float = 1.0

## Radius in pixels for AoE skills (0 = single-target).
@export var aoe_radius: float = 0.0

## Maximum number of targets hit (0 = unlimited).
@export var max_targets: int = 1

## If true, skill hits friendlies (for heals, buffs).
@export var affects_allies: bool = false

# ─── Skill Tree Position ──────────────────────────────────────────────────────

@export_group("Skill Tree")

## Column (x) and row (y) in the skill tree grid.
@export var tree_position: Vector2i = Vector2i(0, 0)

## Skill IDs that must be learned before this skill unlocks.
@export var prerequisites: Array[String] = []

## Minimum character level required.
@export var required_level: int = 1

## Maximum times this skill can be upgraded (rank).
@export var max_rank: int = 5

# ─── Passive Modifiers ────────────────────────────────────────────────────────

## For PASSIVE skills: stat modifiers applied when the skill is learned.
## Array of Dictionaries with keys: "stat", "value", "type" (StatModifier.Type).
@export var passive_modifiers: Array[Dictionary] = []

## Additional modifiers added per rank (same format as passive_modifiers).
@export var passive_modifiers_per_rank: Array[Dictionary] = []

# ─── Visual & Audio ───────────────────────────────────────────────────────────

@export_group("Visual")
@export var icon: Texture2D = null
@export var animation_name: String = "attack"
@export var cast_vfx_scene: PackedScene = null
@export var hit_vfx_scene: PackedScene = null

# ─── Runtime Helpers ──────────────────────────────────────────────────────────

## Calculate the cost for a given rank.
func get_cost_at_rank(rank: int) -> float:
	return base_cost + cost_per_rank * (rank - 1)


## Calculate the cooldown for a given rank (min 0.1 seconds).
func get_cooldown_at_rank(rank: int) -> float:
	return maxf(base_cooldown + cooldown_per_rank * (rank - 1), 0.1)


## Calculate the damage for a given rank.
func get_damage_at_rank(rank: int) -> float:
	return base_damage + damage_per_rank * (rank - 1)


## Returns a formatted description with rank-specific values substituted.
func get_description_at_rank(rank: int) -> String:
	# Simple substitution — extend for more complex templating.
	var desc := description
	desc = desc.replace("{damage}", "%.0f" % get_damage_at_rank(rank))
	desc = desc.replace("{cost}", "%.0f" % get_cost_at_rank(rank))
	desc = desc.replace("{cooldown}", "%.1fs" % get_cooldown_at_rank(rank))
	desc = desc.replace("{radius}", "%.0f" % aoe_radius)
	return desc
