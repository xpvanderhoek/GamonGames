extends SimonSays

func _ready():
	if !PlayerStats.knows_puzzles[get_puzzle_data()]:
		PlayerStats.knows_puzzles[get_puzzle_data()] = true
		$TutorialOverlay.visible = true
	super._ready()
	
