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
		show_coin_popup(PuzzleData.puzzle_coins)
		PuzzleData.puzzle_coins = 0
		PuzzleData.chest_open = false
		await get_tree().create_timer(1).timeout
		TransitionManager.change_scene("res://scenes/map/map.tscn")
	

func show_coin_popup(amount: int) -> void:
	var popup = Label.new()
	popup.text = "+" + str(amount)
	popup.modulate = Color(1, 1, 0)
	get_parent().add_child(popup)
	var rect = get_global_rect()
	popup.global_position = rect.get_center()
	popup.add_theme_font_size_override("font_size", 50)

	var tween = create_tween()

	tween.tween_property(popup, "position:y", popup.position.y - 100, 1.5)
	tween.parallel().tween_property(popup, "modulate:a", 0.0, 0.5)

	tween.finished.connect(func():
		popup.queue_free()
	)


func _on_mouse_entered() -> void:
	material.set_shader_parameter("hovering", true)


func _on_mouse_exited() -> void:
	material.set_shader_parameter("hovering", false)
