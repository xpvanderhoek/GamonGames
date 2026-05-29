extends TextureButton

const PUZZLE_SCENES := [
	"res://scenes/puzzles/sliding_puzzle/sliding_puzzle.tscn",
	"res://scenes/puzzles/simon_says/start_simon.tscn"
]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_pressed() -> void:
	disabled = true
	TransitionManager.change_scene(PUZZLE_SCENES[RunData.rng.randi() % PUZZLE_SCENES.size()])
