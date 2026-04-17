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

func start_game(mode: String):
	var game = SimonSaysGameScene.instantiate()
	game.set_script(scripts[mode])
	
	get_tree().root.add_child(game)
	queue_free()
	
func _ready():
	$ButtonNormal.pressed.connect(func(): start_game("normal"))
	$ButtonMirrored.pressed.connect(func(): start_game("mirrored"))
	$ButtonReverse.pressed.connect(func(): start_game("reverse"))
	$ButtonColor.pressed.connect(func(): start_game("color"))
	$ButtonSpeed.pressed.connect(func(): start_game("speed"))
	$ButtonInverted.pressed.connect(func(): start_game("inverted"))
