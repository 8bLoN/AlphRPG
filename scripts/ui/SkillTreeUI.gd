# SkillTreeUI.gd
# =============================================================================
# Diablo 2-style skill tree window.
# Groups skills by class (Warrior | Mage | Rogue).
# Toggle with S key. Player can invest skill points via the "+" buttons.
# =============================================================================
class_name SkillTreeUI
extends Control

var _points_label: Label = null
var _warrior_col: VBoxContainer = null
var _mage_col: VBoxContainer = null
var _rogue_col: VBoxContainer = null


func _ready() -> void:
	visible = false
	_build_ui()
	EventBus.ui_panel_toggled.connect(_on_panel_toggled)
	EventBus.skill_learned.connect(func(_c: Node, _d: Resource) -> void:
		if visible:
			_refresh()
	)
	EventBus.skill_points_available.connect(func(_p: int) -> void:
		if visible:
			_refresh()
	)


func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.05, 0.1, 0.97)
	bg.z_index = -1
	add_child(bg)

	# Title bar
	var title_bar := ColorRect.new()
	title_bar.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_TOP, 0.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	title_bar.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 28.0)
	title_bar.color = Color(0.14, 0.06, 0.22, 1.0)
	add_child(title_bar)

	var title_lbl := Label.new()
	title_lbl.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	title_lbl.set_anchor_and_offset(SIDE_TOP, 0.0, 4.0)
	title_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	title_lbl.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 26.0)
	title_lbl.text = "SKILL TREE  [S]"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_lbl)

	# Points label
	_points_label = Label.new()
	_points_label.set_anchor_and_offset(SIDE_LEFT, 0.0, 0.0)
	_points_label.set_anchor_and_offset(SIDE_TOP, 0.0, 30.0)
	_points_label.set_anchor_and_offset(SIDE_RIGHT, 1.0, 0.0)
	_points_label.set_anchor_and_offset(SIDE_BOTTOM, 0.0, 50.0)
	_points_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points_label.text = "Skill Points: 0"
	add_child(_points_label)

	# 3-column HBoxContainer
	var hbox := HBoxContainer.new()
	hbox.set_anchor_and_offset(SIDE_LEFT, 0.0, 6.0)
	hbox.set_anchor_and_offset(SIDE_TOP, 0.0, 54.0)
	hbox.set_anchor_and_offset(SIDE_RIGHT, 1.0, -6.0)
	hbox.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -42.0)
	hbox.add_theme_constant_override("separation", 6)
	add_child(hbox)

	var warrior_result := _make_col_panel("⚔  WARRIOR")
	_warrior_col = warrior_result[1]
	hbox.add_child(warrior_result[0])

	var mage_result := _make_col_panel("✦  MAGE")
	_mage_col = mage_result[1]
	hbox.add_child(mage_result[0])

	var rogue_result := _make_col_panel("◆  ROGUE")
	_rogue_col = rogue_result[1]
	hbox.add_child(rogue_result[0])

	# Close button
	var close_btn := Button.new()
	close_btn.set_anchor_and_offset(SIDE_LEFT, 0.5, -50.0)
	close_btn.set_anchor_and_offset(SIDE_TOP, 1.0, -36.0)
	close_btn.set_anchor_and_offset(SIDE_RIGHT, 0.5, 50.0)
	close_btn.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -8.0)
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void:
		visible = false
	)
	add_child(close_btn)


# Returns [PanelContainer, inner VBoxContainer for skill cards]
func _make_col_panel(header: String) -> Array:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header_lbl := Label.new()
	header_lbl.text = header
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 1.0))
	outer.add_child(header_lbl)

	var sep := HSeparator.new()
	outer.add_child(sep)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var skill_vbox := VBoxContainer.new()
	skill_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(skill_vbox)
	outer.add_child(scroll)
	panel.add_child(outer)

	return [panel, skill_vbox]


func _on_panel_toggled(panel_id: String, open: bool) -> void:
	if panel_id == "skill_tree":
		visible = open
		if open:
			_refresh()


func _refresh() -> void:
	var player := GameManager.player as PlayerCharacter
	if not player:
		return

	var pts := player.unspent_skill_points
	if _points_label:
		_points_label.text = "Skill Points: %d" % pts

	_clear_col(_warrior_col)
	_clear_col(_mage_col)
	_clear_col(_rogue_col)

	for sd: SkillData in player.skill_tree.get_all_skills_sorted():
		var col := _get_col(sd.class_id)
		if col:
			_add_skill_card(col, sd, player, pts)


func _clear_col(col: VBoxContainer) -> void:
	if not col:
		return
	for c in col.get_children():
		c.queue_free()


func _get_col(class_id: String) -> VBoxContainer:
	match class_id:
		"warrior": return _warrior_col
		"mage":    return _mage_col
		"rogue":   return _rogue_col
	return null


func _add_skill_card(col: VBoxContainer, sd: SkillData, player: PlayerCharacter, pts: int) -> void:
	var rank := player.skill_tree.get_rank(sd.id)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_lbl := Label.new()
	name_lbl.text = "%s  [%d / %d]" % [sd.display_name, rank, sd.max_rank]
	if rank > 0:
		name_lbl.modulate = Color(1.0, 0.85, 0.3)
	name_lbl.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	var rank_for_desc := maxi(rank, 1)
	desc_lbl.text = sd.get_description_at_rank(rank_for_desc)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(desc_lbl)

	var can_invest := (pts > 0 and rank < sd.max_rank and _prereqs_met(player, sd))
	var btn := Button.new()
	btn.text = "+ Invest"
	btn.disabled = not can_invest
	btn.pressed.connect(func() -> void:
		if player.allocate_skill_point(sd.id):
			_refresh()
	)
	vbox.add_child(btn)

	card.add_child(vbox)
	col.add_child(card)


func _prereqs_met(player: PlayerCharacter, sd: SkillData) -> bool:
	for prereq_id: String in sd.prerequisites:
		if player.skill_tree.get_rank(prereq_id) < 1:
			return false
	return true
