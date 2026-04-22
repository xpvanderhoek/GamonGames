extends Node

var slide_puzzle_size: int = 2
var failed_slide_puzzle_times: int = 0
var knows_slide_puzzle: bool = false

func increase_grid_size():
	failed_slide_puzzle_times = 0
	slide_puzzle_size = clamp(slide_puzzle_size + 1, 2, 999)

func decrease_grid_size():
	if failed_slide_puzzle_times > 1:
		failed_slide_puzzle_times = 0
		slide_puzzle_size = clamp(slide_puzzle_size - 1, 2, 999)
	else:
		failed_slide_puzzle_times += 1
