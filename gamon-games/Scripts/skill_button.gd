extends TextureButton
class_name SkillNode

@onready var skill_level: Label = $SkillLevel
@onready var skill_branch: Line2D = $SkillBranch
@export var skill: SkillData

func _ready() -> void:
	if get_parent() is SkillNode:
		var parent_node = get_parent() as SkillNode
		
		skill_branch.clear_points()
		
		var parent_top_middle = parent_node.global_position + Vector2(parent_node.size.x / 2, 0)
		
		var child_bottom_middle = self.global_position + Vector2(self.size.x / 2, self.size.y)
		
		var local_parent = parent_top_middle - skill_branch.global_position
		var local_child = child_bottom_middle - skill_branch.global_position
		
		skill_branch.add_point(local_parent)
		skill_branch.add_point(local_child)
		
		update_line_appearance(parent_node)
		print(skill_branch.points)
	if skill.current_level == 0:
		self.self_modulate = self.self_modulate * 0.7
	update_skill_display()

func update_line_appearance(parent_node: SkillNode) -> void:
	if parent_node.skill.current_level == 0:
		skill_branch.modulate = Color(0.5, 0.5, 0.5, 0.5)  # Dark and transparent
	else:
		skill_branch.modulate = Color.WHITE  # Normal brightness

func update_skill_display() -> void:
	skill_level.text = str(skill.current_level) + "/" + str(skill.max_level)

func _on_pressed() -> void:
	if skill.current_level == skill.max_level:
		print(skill.skill_name + " is already at max level.")
		return
	var cost = skill.get_level_cost()
	print(cost)
	if PlayerStats.get_marrow_shards_amount() < cost:
		print("Not enough marrow_shards for upgrade")
	else:
		skill.current_level += 1
		if skill.current_level == 1:
			self.self_modulate = self.self_modulate * 1.42857
			# Update line appearance for all child nodes when leveled from 0 to 1
			_update_children_line_appearance()
		if skill.current_level == skill.max_level:
			pass
			#TODO: Maybe add something to sprite here to show skill reached its max level
			#(green border for example)
		update_skill_display()
		print(str(skill.skill_name) + " leveled up to level: " + str(skill.current_level))

func _update_children_line_appearance() -> void:
	# Update line appearance for all child nodes
	for child in get_children():
		if child is SkillNode:
			child.update_line_appearance(self)
