extends TextureButton

const PUZZLE_SCENES := [
	"res://scenes/puzzles/sliding_puzzle/sliding_puzzle.tscn",
	"res://scenes/puzzles/simon_says/start_simon.tscn"
]

func _on_pressed() -> void:
	disabled = true
	TransitionManager.change_scene(PUZZLE_SCENES[RunData.rng.randi() % PUZZLE_SCENES.size()])



func _on_mouse_entered() -> void:
	print("hoi")
	material.set_shader_parameter("hovering", true)


func _on_mouse_exited() -> void:
	print("doei")
	material.set_shader_parameter("hovering", false)
