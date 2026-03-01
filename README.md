# AlphRPG

A Diablo-style action RPG built with **Godot 4.6** and GDScript.
Isometric 3D world, click-to-move controls, real-time combat.

---

## Features

### Combat & Controls
- **LMB** — click-to-move (NavigationAgent3D pathfinding)
- **LMB on enemy** — auto-attack with life steal support
- **RMB** — primary skill (slot 0)
- **1 / 2 / 3 / 4** — additional skill slots
- Full hit / crit / damage type system (Physical, Fire, Cold, Lightning, Poison, Arcane)

### Progression
- XP gain with exponential level scaling (`100 × 1.15^level`)
- Stat points per level — allocate Strength / Dexterity / Intelligence / Vitality
- Skill points per level — upgrade or unlock active skills in the skill tree

### Skills
- **Fireball** — projectile, AoE explosion on impact
- **Ground Slam** — melee AoE, knocks back enemies
- **Poison Dagger** — applies stacking DoT debuff
- Passive skills with stat modifier support
- Data-driven via `.tres` SkillData resources

### Items & Inventory
- Grid-based inventory (10×4)
- Equipment slots: Weapon, Helmet, Chest, Gloves, Boots, Ring, Amulet
- Rarity tiers: Common → Uncommon → Rare → Epic → Legendary
- Random affix rolling from `affixes.json` loot tables
- Item tooltips with stat comparison

### Enemy AI
- Three-phase FSM: **Patrol → Aggro → Attack**
- 3D sphere-cast aggro detection
- Configurable aggro/deaggro/attack radii via `EnemyData` resource
- Skill-capable enemies (use same skill tree as player)
- Auto-respawn spawners with configurable counts and timers

### World
- 3D isometric camera (perspective, FOV 55°, follows player)
- Procedural night-sky environment with fog
- NavigationRegion3D for obstacle-aware pathfinding
- 3D decorations: trees, rocks
- Loot drops with billboard labels and rarity glow

### UI
- Health / Mana bars (bottom-left HUD)
- Skill bar with cooldown overlays (bottom-center)
- Inventory panel (`I` key)
- Character window with stat allocation (`C` key)
- Floating damage numbers projected from 3D world space
- Item tooltips on hover

---

## Controls

| Input | Action |
|-------|--------|
| LMB | Move / Auto-attack |
| RMB | Primary skill |
| 1–4 | Skills 2–5 |
| I | Inventory |
| C | Character |
| Esc | Pause |

---

## Tech Stack

- **Engine**: Godot 4.6.1
- **Language**: GDScript
- **Architecture**: EventBus signals, StateMachine FSM, data-resource driven design
- **Physics**: CharacterBody3D + NavigationAgent3D + Area3D raycasting

---

*Author: SpiderMaH*
