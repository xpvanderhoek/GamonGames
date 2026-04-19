extends Control

var SimonSaysGameScene = preload("res://scenes/puzzles/simon_says/simon_says.tscn")

var scripts = {
	"normal": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_normal.gd"),
	"mirrored": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_mirrored.gd"),
	"reverse": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_vice_versa.gd"),
	"color": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_colored.gd"),
	"speed": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_speed.gd"),
	"inverted": preload("res://scripts/puzzles/simon_says/simon_says_versions/simon_says_inverted.gd")
}

func start_random_game():
	var game := SimonSaysGameScene.instantiate()
	var rand_idx = RunData.rng.randi_range(0, scripts.size() - 1)
	var rand_key = scripts.keys()[rand_idx]
	
	game.set_script(scripts[rand_key])
	get_tree().change_scene_to_node(game)
	
func _ready():
	start_random_game()
