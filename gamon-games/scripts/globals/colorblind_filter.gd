extends CanvasLayer

var color_rect: ColorRect
var shader_material: ShaderMaterial

func _ready():
	layer = 128
	
	color_rect = ColorRect.new()
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(color_rect)
	
	shader_material = ShaderMaterial.new()
	var shader = load("res://scripts/shaders/colorblindness.gdshader")
	shader_material.shader = shader
	color_rect.material = shader_material

func set_mode(mode: int):
	if shader_material:
		shader_material.set_shader_parameter("mode", mode)
