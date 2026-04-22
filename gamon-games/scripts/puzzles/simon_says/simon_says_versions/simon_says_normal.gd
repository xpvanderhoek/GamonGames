extends SimonSays

func _ready():
	if !PuzzleData.knows_simon_says_normal:
		open_explaination(PuzzleData.knows_simon_says_normal)
	super._ready()
