extends Resource
class_name SkillData

@export var skill_name: String
var cost: int
@export var min_cost: int
@export var max_cost: int
@export var max_level: int
@export var current_level: int = 0
@export var texture: Texture
@export var skill_after: Array [SkillData]

func get_level_cost() -> int:
	var progress = current_level / float(max_level)
	return min_cost + int((max_cost - min_cost) * (progress * progress))
