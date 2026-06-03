extends TextureButton

const PUZZLE_SCENES := [
	"res://scenes/puzzles/sliding_puzzle/sliding_puzzle.tscn",
	"res://scenes/puzzles/simon_says/start_simon.tscn"
]

func _ready():
	texture_normal = load(
	"res://assets/enemies/chest/Open_chest.png"
	if PuzzleData.chest_open
	else "res://assets/enemies/chest/locked_chest.png"
	)

func _on_pressed() -> void:
	if PuzzleData.chest_open == false:
		disabled = true
		TransitionManager.change_scene(PUZZLE_SCENES[RunData.rng.randi() % PUZZLE_SCENES.size()])
	else:
		RunData.coins = RunData.coins + PuzzleData.puzzle_coins
		PuzzleData.puzzle_coins = 0
		PuzzleData.chest_open = false
		TransitionManager.change_scene("res://scenes/map/map.tscn")
	



func _on_mouse_entered() -> void:
	print("hoi")
	material.set_shader_parameter("hovering", true)


func _on_mouse_exited() -> void:
	print("doei")
	material.set_shader_parameter("hovering", false)
