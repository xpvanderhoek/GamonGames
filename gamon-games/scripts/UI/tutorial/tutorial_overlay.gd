extends CanvasLayer

@export var title : String = "New Tutorial"
@export var pages : Array[TutorialPage]

@onready var page_number_label: Label = $Panel/PageNumberLabel
@onready var image: TextureRect = $Panel/ImageContainer/Image
@onready var rich_text: RichTextLabel = $Panel/Text
@onready var back_button: Button = $Panel/BackButton
@onready var next_button: Button = $Panel/NextButton
@onready var exit_button: Button = $Panel/ExitButton

var current_page : int

func _ready() -> void:
	$Panel/TitleLabel.text = title
	current_page = 0
	show_page(current_page)

func show_page(index : int):
	var page = pages[index]
	rich_text.text = page.text
	
	exit_button.visible = (index == pages.size() - 1)
	
	if page.image:
		image.texture = page.image
		image.show()
	else:
		image.hide()
	
	page_number_label.text = "(Page " + str(index + 1) + " of " + str(pages.size()) + ")"
	
	back_button.disabled = (index == 0)
	next_button.disabled = (index == pages.size() - 1)

func _on_next_pressed():
	if current_page < pages.size() - 1:
		current_page += 1
		show_page(current_page)

func _on_back_pressed():
	if current_page > 0:
		current_page -= 1
		show_page(current_page)

func _on_exit_pressed():
	if current_page == pages.size() - 1:
		self.visible = false
		PlayerStats.knows_combat = true
		current_page = 0
		show_page(current_page)
