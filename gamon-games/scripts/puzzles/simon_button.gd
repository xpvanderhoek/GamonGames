extends TextureButton

const FLASH_TIME = 0.2

func flash():
	modulate = Color(2, 2, 2)
	
	await get_tree().create_timer(FLASH_TIME).timeout
	
	modulate = Color(1, 1, 1)
