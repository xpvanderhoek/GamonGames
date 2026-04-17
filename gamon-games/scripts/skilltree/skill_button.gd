extends TextureButton
class_name SkillNode

@onready var skill_level: Label = $SkillLevel
@onready var skill_branch: Line2D = $SkillBranch
@export var skill: SkillData


func _ready() -> void:
	_update_tooltip_text()
	if get_parent() is SkillNode:
		var parent_node = get_parent() as SkillNode
		
		skill_branch.clear_points()
		
		var parent_top_middle = parent_node.global_position + Vector2(parent_node.size.x / 2, 0)
		var child_bottom_middle = self.global_position + Vector2(self.size.x / 2, self.size.y)
		
		var local_parent = parent_top_middle - skill_branch.global_position
		var local_child = child_bottom_middle - skill_branch.global_position
		
		skill_branch.add_point(local_parent)
		skill_branch.add_point(local_child)
		
		_update_line_appearance(parent_node)
	if skill.current_level == 0:
		self.self_modulate = self.self_modulate * 0.7
	_update_skill_display()

func _update_line_appearance(parent_node: SkillNode) -> void:
	if parent_node.skill.current_level == 0:
		skill_branch.modulate = Color(0.5, 0.5, 0.5, 0.5)
	else:
		skill_branch.modulate = Color.WHITE

func _update_skill_display() -> void:
	skill_level.text = str(skill.current_level) + "/" + str(skill.max_level)

func _on_pressed() -> void:
	if get_parent() is SkillNode:
		var parent_node = get_parent() as SkillNode
		if parent_node.skill.current_level == 0:
			print("%s must be leveled first!" %parent_node.skill.skill_name)
			return
	
	if skill.current_level == skill.max_level:
		print(skill.skill_name + " is already at max level")
		return
	
	var cost = skill.get_level_cost()
	
	if RunData.marrow_shards < cost:
		print("Not enough marrow shards for upgrade")
	else:
		RunData.marrow_shards -= cost
		skill.current_level += 1
		
		if skill.affected_stat != "" and skill.stat_bonus_per_level > 0:
			PlayerStats.update_stat(skill.affected_stat, skill.stat_bonus_per_level)
		
		if skill.current_level == 1:
			self.self_modulate = self.self_modulate * 1.42857
			_update_children_line_appearance()
		if skill.current_level == skill.max_level:
			pass
			#TODO:Add something to sprite here to show skill reached its max level
			#(green border for example)
		_update_skill_display()
		_update_tooltip_text()
		print(skill.skill_name + " leveled up to level: " + str(skill.current_level))

func _update_children_line_appearance() -> void:
	for child in get_children():
		if child is SkillNode:
			child._update_line_appearance(self)

func _update_tooltip_text() -> void:
	var lvl_cost = skill.get_level_cost()
	tooltip_text = "%s\n%s\nCost: %d Marrow shards"%[skill.skill_name,skill.tooltip_text,lvl_cost]
