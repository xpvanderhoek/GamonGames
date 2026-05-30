extends Node

func _ready():
	pick_random_puzzle()
	
var slide_puzzle_size: int = 2
var failed_slide_puzzle_times: int = 0
var knows_puzzles := {
	"slide": false,
	"simon_says_normal": false,
	"simon_says_mirror": false,
	"simon_says_reverse": false,
	"simon_says_color": false,
	"simon_says_speed": false,
	"simon_says_inverted": false
}
var current_puzzle = -1



func pick_random_puzzle():
	var keys = knows_puzzles.keys()
	keys.erase("slide")
	
	current_puzzle = randi_range(0, keys.size() - 1)
	
	print(keys)
	print(current_puzzle)
	print(keys[current_puzzle])

func increase_grid_size():
	failed_slide_puzzle_times = 0
	slide_puzzle_size = clamp(slide_puzzle_size + 1, 2, 999)

func decrease_grid_size():
	if failed_slide_puzzle_times > 1:
		failed_slide_puzzle_times = 0
		slide_puzzle_size = clamp(slide_puzzle_size - 1, 2, 999)
	else:
		failed_slide_puzzle_times += 1
