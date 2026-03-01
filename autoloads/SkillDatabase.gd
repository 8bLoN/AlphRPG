# SkillDatabase.gd
# =============================================================================
# Autoloaded singleton registry for all SkillData resources.
# Loaded automatically from res://data/skills/**/*.tres.
#
# USAGE:
#   SkillDatabase.get_skill("mage_fireball")  → SkillData
#   SkillDatabase.get_skills_for_class("mage") → Array[SkillData]
# =============================================================================
extends Node

## All registered skills. Key: skill_id, Value: SkillData.
var _skills: Dictionary = {}

# ─── Initialisation ───────────────────────────────────────────────────────────

func _ready() -> void:
	_load_skill_resources("res://data/skills/")
	print("SkillDatabase: Loaded %d skills." % _skills.size())

# ─── API ─────────────────────────────────────────────────────────────────────

func get_skill(skill_id: String) -> SkillData:
	return _skills.get(skill_id, null)


## Returns all skills belonging to a specific class.
func get_skills_for_class(class_id: String) -> Array[SkillData]:
	var result: Array[SkillData] = []
	for sd: SkillData in _skills.values():
		if sd.class_id == class_id:
			result.append(sd)
	return result


## Returns all registered skills.
func get_all_skills() -> Array[SkillData]:
	return _skills.values()


## Register a SkillData programmatically (for tests).
func register_skill(skill_data: SkillData) -> void:
	if skill_data.id.is_empty():
		push_error("SkillDatabase.register_skill: SkillData has no id.")
		return
	_skills[skill_data.id] = skill_data

# ─── Internal ─────────────────────────────────────────────────────────────────

func _load_skill_resources(base_path: String) -> void:
	var dir := DirAccess.open(base_path)
	if dir == null:
		push_warning("SkillDatabase: Path '%s' not found." % base_path)
		return

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry.length() > 0:
		var full_path := base_path + entry
		if dir.current_is_dir() and not entry.begins_with("."):
			# Recurse into subdirectories.
			_load_skill_resources(full_path + "/")
		elif entry.ends_with(".tres") or entry.ends_with(".res"):
			var res := ResourceLoader.load(full_path)
			if res is SkillData:
				_skills[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()
