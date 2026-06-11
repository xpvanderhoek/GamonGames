extends SimonSays

func _ready():
	print("hoi")
	print(tutorial)
	tutorial.title = "Simon Says Normal"
	tutorial.pages[0].video = load("res://assets/puzzle/SS-normal - kopie.ogv")
	tutorial.pages[0].text = "Remember the sequgfbfdgbence and repeat it correctly."
	print(tutorial.title)
	print(tutorial.pages[0].video)
	print(tutorial.pages[0].text)

	super._ready()
	
