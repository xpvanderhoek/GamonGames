extends "res://scripts/door.gd"

func interact():
	RunData.new_run()

	NavigationManager.go_to_room(NavigationManager.get_new_random_room())
