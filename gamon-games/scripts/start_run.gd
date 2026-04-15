extends Control

@onready var start_btn : Button = $ButtonContainer/StartRunBtn
@onready var giveup_btn : Button = $ButtonContainer/GiveUpBtn
@onready var motivation_label : Label = $MotivationLabel

var motivation_texts : Array[String] = [
	"Good luck out there, cursed knight",
	"No one said it would be easy",
	"Does your story end here?",
	]

func _ready() -> void:
	var idx = randi_range(0, motivation_texts.size() - 1)
	motivation_label.text = motivation_texts[idx]
	get_tree().paused = true

func _on_start_run_btn_pressed() -> void:
	get_tree().paused = false
	#if PlayerStats.knows_ghost:
		#RunData.new_run()
		#TransitionManager.transition_newrun(NavigationManager.get_new_random_room())
	#else:
		#TransitionManager.transition_newrun(NavigationManager.scene_room_limbo)
	TransitionManager.transition_newrun("res://scenes/map.tscn")
	
	queue_free()


func _on_give_up_btn_pressed() -> void:
	get_tree().quit()
