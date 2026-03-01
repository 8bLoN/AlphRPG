# ItemData.gd
# =============================================================================
# Resource that defines an item TEMPLATE (not an instance).
# One .tres file per item base type. ItemFactory reads these and generates
# BaseItem instances with randomised affix rolls.
#
# GRID INVENTORY:
#   size.x = columns occupied, size.y = rows occupied (Diablo-style)
#   e.g. a sword might be 1×3, a ring 1×1, a two-handed axe 2×4
#
# AFFIXES:
#   prefix_pool / suffix_pool hold StatModifier arrays with min/max ranges
#   (stored as metadata on the Resource). ItemFactory picks from these pools
#   based on item level and rarity.
# =============================================================================
class_name ItemData
extends Resource

# ─── Identity ─────────────────────────────────────────────────────────────────

## Unique identifier. Must never change — used for save/load and the database.
@export var id: String = ""

## Display name (base type name, e.g. "Long Sword").
@export var display_name: String = ""

@export_multiline var base_description: String = ""

# ─── Category & Type ──────────────────────────────────────────────────────────

enum ItemCategory { EQUIPMENT, CONSUMABLE, QUEST, CURRENCY }
enum EquipSlot {
	NONE,
	HELMET, CHEST, GLOVES, BOOTS,
	WEAPON_MAIN, WEAPON_OFF,
	RING_LEFT, RING_RIGHT, AMULET
}

@export var category: ItemCategory = ItemCategory.EQUIPMENT
@export var equip_slot: EquipSlot = EquipSlot.NONE

# ─── Rarity System ────────────────────────────────────────────────────────────

enum Rarity { COMMON, MAGIC, RARE, LEGENDARY }

## Rarity determines number of affixes and colour in UI.
@export var rarity: Rarity = Rarity.COMMON

## Minimum item level this base type can spawn at.
@export var min_item_level: int = 1

## Maximum item level (0 = no cap).
@export var max_item_level: int = 0

# ─── Grid Size ────────────────────────────────────────────────────────────────

## Grid cells occupied: x = columns, y = rows.
@export var size: Vector2i = Vector2i(1, 1)

## Stack limit for consumables (1 for non-stackable equipment).
@export var max_stack: int = 1

## Weight for inventory capacity (optional feature).
@export var weight: float = 1.0

# ─── Base Stats (Equipment) ───────────────────────────────────────────────────
# These go directly into StatModifier.FLAT mods when the item is equipped.
# Keep these as dict for extensibility (no code change needed for new stats).

## Base stat modifiers provided by this item type before affix generation.
## Key: stat name (String), Value: base value (float).
@export var base_stat_bonuses: Dictionary = {}

# ─── Affix Pools ──────────────────────────────────────────────────────────────

## How many prefixes this item can roll (based on rarity):
##   COMMON: 0, MAGIC: 1, RARE: 2, LEGENDARY: 2 (fixed)
@export var max_prefixes: int = 0

## How many suffixes this item can roll.
@export var max_suffixes: int = 0

## Available prefix affix IDs (looked up in ItemDatabase.affixes).
@export var prefix_pool: Array[String] = []

## Available suffix affix IDs.
@export var suffix_pool: Array[String] = []

# ─── Damage (Weapons) ─────────────────────────────────────────────────────────

@export_group("Weapon")
@export var weapon_min_damage: float = 0.0
@export var weapon_max_damage: float = 0.0
@export var attack_speed_override: float = 0.0   # 0 = use character's default
@export var damage_type: int = 0                   # CombatManager.DamageType

# ─── Consumable ───────────────────────────────────────────────────────────────

@export_group("Consumable")

## Healing applied when used.
@export var heal_amount: float = 0.0

## Mana restored when used.
@export var mana_amount: float = 0.0

## Effect applied on use (e.g. temporary buff). Empty = no effect.
@export var use_effect_id: String = ""

## Cooldown between uses in seconds.
@export var use_cooldown: float = 0.0

# ─── Visual ───────────────────────────────────────────────────────────────────

@export_group("Visual")

## Icon shown in inventory grid and tooltips.
@export var icon: Texture2D = null

## Optional 3D/2D model for world drop display.
@export var world_icon: Texture2D = null

## Colour tint used to visualise rarity in tooltips.
static func get_rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON:    return Color.WHITE
		Rarity.MAGIC:     return Color(0.4, 0.4, 1.0)  # Blue
		Rarity.RARE:      return Color(1.0, 1.0, 0.3)  # Yellow
		Rarity.LEGENDARY: return Color(1.0, 0.5, 0.1)  # Orange
	return Color.WHITE
