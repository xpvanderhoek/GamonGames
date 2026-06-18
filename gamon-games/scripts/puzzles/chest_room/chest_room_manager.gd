extends Control

func _process(_delta: float) -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var scale_factor = maxf(viewport_size.x / 1152.0, viewport_size.y / 648.0)
	
	var chest = get_node_or_null("TextureButton") as Control
	if chest:
		chest.pivot_offset = Vector2(-chest.offset_left, -chest.offset_top)
		chest.scale = Vector2(scale_factor, scale_factor)
		
	var shadow_container = get_node_or_null("TextureRect2") as Control
	if shadow_container:
		shadow_container.pivot_offset = Vector2(-shadow_container.offset_left, -shadow_container.offset_top)
		shadow_container.scale = Vector2(scale_factor, scale_factor)
