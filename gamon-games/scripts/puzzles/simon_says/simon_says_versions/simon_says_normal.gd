extends SimonSays

func _ready():
	if !PuzzleData.knows_puzzles[get_puzzle_data()]:
		PuzzleData.knows_puzzles[get_puzzle_data()] = true
		$TutorialOverlay.visible = true
	super._ready()
	
