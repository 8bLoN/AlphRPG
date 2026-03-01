# SkillTree.gd
# =============================================================================
# Manages a character's learned skills: registration, learning/upgrading,
# rank tracking, and skill bar slot assignment.
#
# ARCHITECTURE:
#   • _skill_registry holds ALL SkillData available to this class (from ClassData).
#   • _learned_skills holds only skills the player has actually invested points in.
#   • _skill_bar maps bar slot indices (0–5) to skill IDs for quick activation.
#   • Skill instances (BaseSkill objects) live in _skill_instances.
#
# EXTENDING:
#   • For mastery systems: add mastery_level tracking per skill.
#   • For synergies: add a get_synergy_bonus(skill_id) method that reads other
#     skill ranks and returns a flat damage bonus.
# =============================================================================
class_name SkillTree
extends RefCounted

## The character who owns this skill tree.
var owner_character: BaseCharacter = null

## All SkillData resources available to this class. Key: skill_id.
var _skill_registry: Dictionary = {}

## Skills the player has actually learned. Key: skill_id, Value: rank (int).
var _learned_skills: Dictionary = {}

## Live skill instances. Key: skill_id, Value: BaseSkill.
var _skill_instances: Dictionary = {}

## Skill bar assignment. Key: slot (int 0–5), Value: skill_id (String).
var _skill_bar: Dictionary = {}

# ─── Registration ─────────────────────────────────────────────────────────────

## Register a SkillData resource as available to this tree.
## Call once for each skill in CharacterClassData.available_skills.
func register_skill(skill_data: SkillData) -> void:
	_skill_registry[skill_data.id] = skill_data


## Register multiple skills at once.
func register_skills(skill_data_array: Array) -> void:
	for sd in skill_data_array:
		register_skill(sd)

# ─── Learning ─────────────────────────────────────────────────────────────────

## Attempt to learn a skill or upgrade its rank.
## Returns true if the operation succeeded.
func learn_or_upgrade(skill_id: String) -> bool:
	if not _skill_registry.has(skill_id):
		push_warning("SkillTree: Skill '%s' not registered." % skill_id)
		return false

	var skill_data: SkillData = _skill_registry[skill_id]
	var current_rank: int = _learned_skills.get(skill_id, 0)

	# Prerequisite check.
	if not _prerequisites_met(skill_data):
		return false

	# Level requirement.
	if owner_character and owner_character.stats.level < skill_data.required_level:
		return false

	# Max rank check.
	if current_rank >= skill_data.max_rank:
		return false

	var new_rank := current_rank + 1
	_learned_skills[skill_id] = new_rank

	# Create or update the skill instance.
	if not _skill_instances.has(skill_id):
		var instance := _create_skill_instance(skill_data, new_rank)
		_skill_instances[skill_id] = instance
	else:
		_skill_instances[skill_id].rank = new_rank

	# Apply passive modifiers for passive skills.
	if skill_data.skill_type == SkillData.SkillType.PASSIVE:
		var passive := _skill_instances[skill_id] as PassiveSkill
		if passive:
			passive.apply_passive_modifiers(owner_character)

	EventBus.skill_learned.emit(owner_character, skill_data)
	return true


## Returns the current rank of a skill (0 = not learned).
func get_rank(skill_id: String) -> int:
	return _learned_skills.get(skill_id, 0)


## Returns true if the skill has been learned at any rank.
func has_skill(skill_id: String) -> bool:
	return _learned_skills.get(skill_id, 0) > 0


## Returns all learned skill IDs.
func get_learned_skill_ids() -> Array[String]:
	var result: Array[String] = []
	for sid: String in _learned_skills:
		result.append(sid)
	return result

# ─── Skill Bar ────────────────────────────────────────────────────────────────

## Assign a learned skill to a hotbar slot (0–5).
func assign_to_slot(slot: int, skill_id: String) -> void:
	if not has_skill(skill_id):
		push_warning("SkillTree: Cannot assign unlearned skill '%s' to slot %d." % [skill_id, slot])
		return
	_skill_bar[slot] = skill_id


## Unassign a slot.
func unassign_slot(slot: int) -> void:
	_skill_bar.erase(slot)


## Returns the BaseSkill assigned to a hotbar slot, or null.
func get_skill_at_slot(slot: int) -> BaseSkill:
	var skill_id: String = _skill_bar.get(slot, "")
	if skill_id.is_empty():
		return null
	return _skill_instances.get(skill_id, null)


## Returns all skill bar assignments as { slot: skill_id }.
func get_skill_bar() -> Dictionary:
	return _skill_bar.duplicate()

# ─── Query ────────────────────────────────────────────────────────────────────

## Get the SkillData for a registered skill (for tooltip display).
func get_skill_data(skill_id: String) -> SkillData:
	return _skill_registry.get(skill_id, null)


## Get the live BaseSkill instance for a learned skill.
func get_skill_instance(skill_id: String) -> BaseSkill:
	return _skill_instances.get(skill_id, null)


## All registered skills as SkillData, grouped by tree_position for UI rendering.
func get_all_skills_sorted() -> Array[SkillData]:
	var all: Array[SkillData] = []
	for sid: String in _skill_registry:
		all.append(_skill_registry[sid])
	all.sort_custom(func(a: SkillData, b: SkillData) -> bool:
		if a.tree_position.y != b.tree_position.y:
			return a.tree_position.y < b.tree_position.y
		return a.tree_position.x < b.tree_position.x)
	return all

# ─── Internal ─────────────────────────────────────────────────────────────────

func _prerequisites_met(skill_data: SkillData) -> bool:
	for prereq_id: String in skill_data.prerequisites:
		if _learned_skills.get(prereq_id, 0) < 1:
			return false
	return true


func _create_skill_instance(skill_data: SkillData, initial_rank: int) -> BaseSkill:
	var instance: BaseSkill

	if skill_data.script_path.length() > 0 and ResourceLoader.exists(skill_data.script_path):
		var scr: GDScript = load(skill_data.script_path)
		instance = scr.new(skill_data, initial_rank)
	else:
		# Fallback: detect type from SkillData.skill_type.
		match skill_data.skill_type:
			SkillData.SkillType.PASSIVE:
				instance = PassiveSkill.new(skill_data, initial_rank)
			_:
				instance = BaseSkill.new(skill_data, initial_rank)

	if owner_character:
		instance.initialize(owner_character, owner_character.get_tree())

	return instance
