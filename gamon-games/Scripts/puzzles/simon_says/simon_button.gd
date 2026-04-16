extends TextureButton

const FLASH_TIME = 0.2

func flash(color: Color = Color(2, 2, 2)):
	modulate = color
	
	await get_tree().create_timer(FLASH_TIME).timeout
	
	modulate = Color(1, 1, 1)
