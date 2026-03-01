# CharacterClassData.gd
# =============================================================================
# Resource that defines a playable class.
# One .tres file per class (warrior.tres, mage.tres, rogue.tres).
# CharacterStats reads this to set base primary stats.
#
# EXTENDING:
#   Add per-level scaling arrays to define how much each primary stat grows
#   per level-up point. Currently each class gets one free point per level
#   distributed according to stat_weights, plus the manual allocation pool.
# =============================================================================
class_name CharacterClassData
extends Resource

# ─── Identity ─────────────────────────────────────────────────────────────────

## Internal ID used in code (e.g. "warrior", "mage", "rogue").
@export var class_id: String = "warrior"

## Display name shown in UI.
@export var display_name: String = "Warrior"

## Short lore blurb shown on character select screen.
@export_multiline var description: String = ""

# ─── Base Primary Stats (at Level 1) ─────────────────────────────────────────

@export_group("Base Stats")
@export var base_strength: int = 10
@export var base_dexterity: int = 10
@export var base_intelligence: int = 10
@export var base_vitality: int = 10

# ─── Per-Level Automatic Growth ───────────────────────────────────────────────
# These are applied automatically each level, on top of player-allocated points.

@export_group("Per-Level Growth")
@export var strength_per_level: float = 0.0
@export var dexterity_per_level: float = 0.0
@export var intelligence_per_level: float = 0.0
@export var vitality_per_level: float = 0.0

# ─── Stat Point Allocation ────────────────────────────────────────────────────

## Manually allocatable stat points gained per level.
@export var stat_points_per_level: int = 5

## Skill points gained per level.
@export var skill_points_per_level: int = 1

# ─── Skill Tree ───────────────────────────────────────────────────────────────

## Paths to all SkillData resources available to this class.
## Organised into tree branches in the SkillTree system.
@export var available_skills: Array[Resource] = []

# ─── Starting Equipment ───────────────────────────────────────────────────────

## ItemData IDs of items placed in inventory on character creation.
@export var starting_item_ids: Array[String] = []

# ─── Derived Stat Formula Overrides ──────────────────────────────────────────
# These multipliers let each class scale differently from the same base formulas.
# e.g. Warrior gets more HP per Vitality than Mage.

@export_group("Stat Scaling Overrides")
@export var hp_per_vitality: float = 5.0       # default: 5.0
@export var mana_per_intelligence: float = 3.0 # default: 3.0
@export var armor_per_strength: float = 0.3    # default: 0.3

# ─── Visual ───────────────────────────────────────────────────────────────────

@export_group("Visual")

## Path to the character's base sprite sheet (used by EquipmentVisualSystem).
@export var base_sprite_sheet: Texture2D = null

## Class icon for the UI.
@export var class_icon: Texture2D = null
