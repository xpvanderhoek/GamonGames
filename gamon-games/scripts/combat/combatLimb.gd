class_name CombatLimb
extends Sprite2D

const LIMB_DISSOLVE_SHADER := preload("res://shaders/black_disintegrate.gdshader")
const OUTLINE_SHADER := preload("res://shaders/combat_outline.gdshader")
const OUTLINE_COLOR := Color(1.0, 0.9, 0.2, 1.0)
const OUTLINE_WIDTH := 3.0
const OUTLINE_TWEEN_DURATION := 0.14
const OUTLINE_PADDING := 2

@export var limb_name: String = "Empty Limb"
@export var max_health: int = 100
@export var is_vital: bool = false
@export var can_be_targeted: bool = true
@export_range(0.0, 100.0, 0.1) var physical_defense: float = 0.0
@export_range(0.0, 100.0, 0.1) var magic_defense: float = 0.0
@export_range(0.0, 100.0, 0.1) var hit_chance_percent: float = 100.0
@export var attacks: Array[SpellData] = []

var current_health: int
var is_destroyed: bool = false
var is_highlighted: bool = false
var is_aoe_highlighted: bool = false
var _spell_targeting_enabled: bool = false
var _spell_targeting_hovered: bool = false
var _spell_targeting_icon: Texture2D = null
var _spell_targeting_frame_sprite: Sprite2D = null
var _spell_targeting_icon_sprite: Sprite2D = null
var _initial_scale: Vector2 = Vector2.ONE
var _initial_position: Vector2 = Vector2.ZERO
var _outline_sprite: Sprite2D = null
var _outline_material: ShaderMaterial = null
var _outline_tween: Tween = null
var _outline_source_texture: Texture2D = null

# Auto generate collision polygon
var alpha_threshold: float = 0.2 # Threshold for generating collision polygons from texture alpha
var epsilon: float = 2.0 # Epsilon for polygon simplification when generating collision polygons

signal limb_damaged(limb: CombatLimb, damage: int, remaining_health: int)
signal limb_destroyed(limb: CombatLimb)
signal limb_clicked(limb: CombatLimb)
signal mouse_entered_limb
signal mouse_exited_limb

func get_defense_for_damage_type(damage_type: SpellData.DamageType) -> float:
	match damage_type:
		SpellData.DamageType.MAGIC:
			return max(0.0, magic_defense)
		_:
			return max(0.0, physical_defense)

func roll_hit() -> bool:
	return randf() * 100.0 < hit_chance_percent

func has_attack_options() -> bool:
	return get_attack_options().size() > 0

func get_attack_options() -> Array[SpellData]:
	var options: Array[SpellData] = []
	for atk in attacks:
		if atk == null:
			continue
		options.append(atk)
	return options

func choose_attack() -> SpellData:
	var options := get_attack_options()
	if options.is_empty():
		return null
	if options.size() == 1:
		return options[0]

	var total_weight := 0.0
	for attack in options:
		total_weight += maxf(0.0, attack.weight)

	if total_weight <= 0.0:
		return options[randi() % options.size()]

	var roll := randf() * total_weight
	var cumulative := 0.0
	for attack in options:
		var weight := maxf(0.0, attack.weight)
		if weight <= 0.0:
			continue
		cumulative += weight
		if roll < cumulative:
			return attack

	for attack in options:
		if attack.weight > 0.0:
			return attack

	return options[randi() % options.size()]

func _ready() -> void:
	_initial_scale = scale
	_initial_position = position
	current_health = max_health
	_ensure_outline_sprite()
	if visible and texture:
		_setup_click_area()

func _ensure_outline_sprite() -> void:
	if texture == null:
		return
	if _outline_sprite != null and is_instance_valid(_outline_sprite) and _outline_source_texture == texture:
		return

	var outline_texture := _build_outline_texture(texture)
	if outline_texture == null:
		return
	_outline_source_texture = texture

	var outline_sprite := Sprite2D.new()
	_outline_sprite = outline_sprite
	_outline_sprite.name = "OutlineSprite"
	_outline_sprite.centered = centered
	_outline_sprite.offset = offset
	_outline_sprite.flip_h = flip_h
	_outline_sprite.flip_v = flip_v
	_outline_sprite.texture = outline_texture
	_outline_sprite.show_behind_parent = false
	_outline_sprite.z_as_relative = true
	_outline_sprite.z_index = 1

	var shader_material := ShaderMaterial.new()
	shader_material.shader = OUTLINE_SHADER
	shader_material.set_shader_parameter("outline_width", OUTLINE_WIDTH)
	shader_material.set_shader_parameter("outline_softness", 0.9)
	shader_material.set_shader_parameter("outline_enabled", true)
	shader_material.set_shader_parameter("outline_only", true)
	var color := OUTLINE_COLOR
	color.a = 0.0
	shader_material.set_shader_parameter("outline_color", color)
	_outline_sprite.material = shader_material
	_outline_material = shader_material

	_outline_sprite.scale = Vector2.ONE
	add_child(_outline_sprite)

func _build_outline_texture(source_texture: Texture2D) -> Texture2D:
	if source_texture == null:
		return null
	var source_image := source_texture.get_image()
	if source_image == null or source_image.is_empty():
		return source_texture
	var pad = max(OUTLINE_PADDING, int(ceil(OUTLINE_WIDTH)) + OUTLINE_PADDING)
	var source_size := source_image.get_size()
	var padded_size := Vector2i(source_size.x + (pad * 2), source_size.y + (pad * 2))
	var padded := Image.create(padded_size.x, padded_size.y, false, source_image.get_format())
	if padded == null:
		return source_texture
	padded.fill(Color(0.0, 0.0, 0.0, 0.0))
	var src_rect := Rect2i(Vector2i.ZERO, source_size)
	var dst_pos := Vector2i(pad, pad)
	padded.blit_rect(source_image, src_rect, dst_pos)
	return ImageTexture.create_from_image(padded)

func _set_outline_alpha(target_alpha: float, custom_color: Color = OUTLINE_COLOR) -> void:
	_ensure_outline_sprite()
	if _outline_material == null or _outline_sprite == null:
		return
	_outline_sprite.visible = true
	if _outline_tween != null and is_instance_valid(_outline_tween):
		_outline_tween.kill()
	_outline_tween = create_tween()
	var current_color: Color = _outline_material.get_shader_parameter("outline_color")
	var target_color := custom_color
	target_color.a = clampf(target_alpha, 0.0, 1.0)
	_outline_tween.tween_property(
		_outline_material,
		"shader_parameter/outline_color",
		target_color,
		OUTLINE_TWEEN_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _clear_outline() -> void:
	if _outline_tween != null and is_instance_valid(_outline_tween):
		_outline_tween.kill()
	if _outline_material != null and is_instance_valid(_outline_material):
		var color: Color = _outline_material.get_shader_parameter("outline_color")
		color.a = 0.0
		_outline_material.set_shader_parameter("outline_color", color)
	if _outline_sprite != null and is_instance_valid(_outline_sprite):
		_outline_sprite.visible = false

func _setup_click_area() -> void:
	# Auto generate collision polygons from the sprite's texture alpha clicking
	# So we don't have to manually add CollisionPolygon2D nodes for each limb
	
	# Create an Area2D with collision from the sprite's alpha channel
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
	area.scale = Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0)
	add_child(area)

	# Generate collision polygons from the texture's opaque pixels
	var image := texture.get_image()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_threshold)

	var tex_size := texture.get_size()
	var polygons := bitmap.opaque_to_polygons(Rect2(Vector2.ZERO, tex_size), epsilon)

	if polygons.size() > 0:
		for poly: PackedVector2Array in polygons:
			var collision := CollisionPolygon2D.new()
			# Offset polygons so they're centered on the sprite (Sprite2D is centered by default)
			var centered_poly := PackedVector2Array()
			for point in poly:
				centered_poly.append(point - tex_size / 2.0)
			collision.polygon = centered_poly
			area.add_child(collision)
	else:
		print("Error: No polygons generated for limb ", limb_name, ". Check Texture")

	area.mouse_entered.connect(func(): mouse_entered_limb.emit())
	area.mouse_exited.connect(func(): mouse_exited_limb.emit())
	if can_be_targeted:
		area.input_event.connect(_on_area_input_event)

func _get_primary_click_target() -> CombatLimb:
	var parent_limb := get_parent() as CombatLimb
	if parent_limb != null and is_instance_valid(parent_limb) and not parent_limb.is_destroyed:
		return parent_limb

	if is_destroyed:
		return null
	return self

func _on_area_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_destroyed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target_limb := _get_primary_click_target()
		if target_limb != null:
			limb_clicked.emit(target_limb)
		# Consume the event so limbs behind this one (e.g. torso behind an arm) don't also get clicked
		viewport.set_input_as_handled()

func set_highlighted(custom_color: Color = OUTLINE_COLOR) -> void:
	if not is_destroyed and not is_highlighted:
		is_highlighted = true
		modulate = Color.WHITE
		_set_outline_alpha(1.0, custom_color)
	
	for child in get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb) and not child_limb.is_destroyed:
			child_limb.set_highlighted(custom_color)

func set_unhighlighted() -> void:
	if is_highlighted:
		is_highlighted = false
		modulate = Color(1, 0.5, 0) if is_aoe_highlighted else Color.WHITE
		_set_outline_alpha(0.0)
	
	for child in get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb):
			child_limb.set_unhighlighted()

func set_aoe_highlighted() -> void:
	if not is_destroyed and not is_aoe_highlighted:
		is_aoe_highlighted = true
		if not is_highlighted:
			modulate = Color.WHITE
	
	for child in get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb) and not child_limb.is_destroyed:
			child_limb.set_aoe_highlighted()

func set_aoe_unhighlighted() -> void:
	if is_aoe_highlighted:
		is_aoe_highlighted = false
		modulate = Color.WHITE
	
	for child in get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb):
			child_limb.set_aoe_unhighlighted()

func set_spell_targeting_preview(enabled: bool, hovered: bool, spell_icon: Texture2D = null) -> void:
	_spell_targeting_enabled = enabled and not is_destroyed
	_spell_targeting_hovered = hovered and _spell_targeting_enabled
	_spell_targeting_icon = spell_icon
	_ensure_spell_targeting_visuals()
	_update_spell_targeting_visuals()

func _ensure_spell_targeting_visuals() -> void:
	if _spell_targeting_frame_sprite == null:
		_spell_targeting_frame_sprite = Sprite2D.new()
		_spell_targeting_frame_sprite.name = "SpellTargetFrame"
		_spell_targeting_frame_sprite.centered = true
		_spell_targeting_frame_sprite.z_index = 40
		_spell_targeting_frame_sprite.texture = _create_spell_target_frame_texture()
		add_child(_spell_targeting_frame_sprite)

	if _spell_targeting_icon_sprite == null:
		_spell_targeting_icon_sprite = Sprite2D.new()
		_spell_targeting_icon_sprite.name = "SpellTargetIcon"
		_spell_targeting_icon_sprite.centered = true
		_spell_targeting_icon_sprite.z_index = 41
		add_child(_spell_targeting_icon_sprite)

func _create_spell_target_frame_texture() -> Texture2D:
	var image := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y in range(48):
		for x in range(48):
			var is_border := x < 4 or x >= 44 or y < 4 or y >= 44
			if is_border:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 0.9))
	return ImageTexture.create_from_image(image)

func _update_spell_targeting_visuals() -> void:
	if _spell_targeting_frame_sprite == null or _spell_targeting_icon_sprite == null:
		return

	if is_destroyed or not _spell_targeting_enabled:
		_spell_targeting_frame_sprite.visible = false
		_spell_targeting_icon_sprite.visible = false
		_spell_targeting_icon_sprite.texture = null
		return

	_spell_targeting_frame_sprite.visible = true
	_spell_targeting_icon_sprite.visible = _spell_targeting_hovered and _spell_targeting_icon != null

	if _spell_targeting_icon != null:
		_spell_targeting_icon_sprite.texture = _spell_targeting_icon
		var icon_size := _spell_targeting_icon.get_size()
		if icon_size.x > 0.0 and icon_size.y > 0.0:
			var frame_size := Vector2(48.0, 48.0)
			var padding := 10.0
			var available_size := frame_size - Vector2(padding, padding)
			var scale_factor := minf(available_size.x / icon_size.x, available_size.y / icon_size.y)
			_spell_targeting_icon_sprite.scale = Vector2.ONE * scale_factor
	else:
		_spell_targeting_icon_sprite.texture = null

func take_damage(amount: int) -> void:
	if is_destroyed:
		return

	current_health = max(0, current_health - amount)
	limb_damaged.emit(self, amount, current_health)

	_flash_hit()

	if current_health <= 0:
		destroy_limb()

func destroy_limb() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	is_highlighted = false
	is_aoe_highlighted = false
	_clear_outline()
	_spell_targeting_enabled = false
	_spell_targeting_hovered = false
	_spell_targeting_icon = null
	if _spell_targeting_frame_sprite != null:
		_spell_targeting_frame_sprite.visible = false
	if _spell_targeting_icon_sprite != null:
		_spell_targeting_icon_sprite.visible = false

	var click_area := get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		click_area.input_pickable = false
		click_area.monitoring = false
		click_area.monitorable = false

	for child in get_children():
		var child_limb := child as CombatLimb
		if child_limb != null and is_instance_valid(child_limb) and not child_limb.is_destroyed:
			child_limb.destroy_limb()

	limb_destroyed.emit(self)
	if not _start_limb_disintegrate():
		_play_destroy_animation()

func mark_destroyed_silent() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	is_highlighted = false
	is_aoe_highlighted = false
	_clear_outline()
	_spell_targeting_enabled = false
	_spell_targeting_hovered = false
	_spell_targeting_icon = null
	if _spell_targeting_frame_sprite != null:
		_spell_targeting_frame_sprite.visible = false
	if _spell_targeting_icon_sprite != null:
		_spell_targeting_icon_sprite.visible = false

	var click_area := get_node_or_null("ClickArea") as Area2D
	if click_area != null:
		click_area.input_pickable = false
		click_area.monitoring = false
		click_area.monitorable = false

func _play_destroy_animation() -> void:
	if not is_inside_tree():
		visible = false
		return

	if has_meta("destroy_tween"):
		var existing_tween = get_meta("destroy_tween")
		if existing_tween is Tween:
			(existing_tween as Tween).kill()
		remove_meta("destroy_tween")

	var break_offset := Vector2(randf_range(-8.0, 8.0), randf_range(8.0, 18.0))
	var tween := create_tween()
	set_meta("destroy_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(1.25, 0.45, 0.45, 0.95), 0.07).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _initial_scale * 1.12, 0.07).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.set_parallel(true)
	tween.tween_property(self, "modulate", Color(0.2, 0.1, 0.1, 0.0), 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", _initial_scale * 0.58, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position", _initial_position + break_offset, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.finished.connect(func():
		if is_instance_valid(self):
			remove_meta("destroy_tween")
			_finalize_destroy_visual()
	)

func _start_limb_disintegrate() -> bool:
	if LIMB_DISSOLVE_SHADER == null or not is_inside_tree():
		return false
	_clear_outline()

	if has_meta("destroy_tween"):
		var existing_tween = get_meta("destroy_tween")
		if existing_tween is Tween:
			(existing_tween as Tween).kill()
		remove_meta("destroy_tween")

	var material := ShaderMaterial.new()
	material.shader = LIMB_DISSOLVE_SHADER
	material.set_shader_parameter("dissolve", 0.0)
	material.set_shader_parameter("time", 0.0)
	self.material = material

	var tween := create_tween()
	set_meta("destroy_tween", tween)
	var duration := 0.45
	tween.set_parallel(true)
	tween.tween_property(material, "shader_parameter/dissolve", 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(material, "shader_parameter/time", 0.6, duration)
	tween.set_parallel(false)
	tween.tween_interval(0.03)
	
	tween.finished.connect(func():
		if is_instance_valid(self):
			remove_meta("destroy_tween")
			_finalize_destroy_visual()
	)
	return true

func _finalize_destroy_visual() -> void:
	visible = false
	scale = _initial_scale
	position = _initial_position
	modulate = Color.WHITE
	material = null

func heal(amount: int) -> void:
	if is_destroyed:
		return
	current_health = min(max_health, current_health + amount)

func get_health_percent() -> float:
	if max_health <= 0:
		return 0.0
	return float(current_health) / float(max_health)

func _flash_hit() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(1.7, 1.7, 1.7, 1.0), 0.22)
	tween.tween_interval(0.08)
	tween.tween_callback(_sync_modulate_from_state)

func _sync_modulate_from_state() -> void:
	if is_destroyed:
		return
	if is_highlighted:
		modulate = Color.GREEN
		return
	if is_aoe_highlighted:
		modulate = Color(1, 0.5, 0)
		return
	modulate = Color.WHITE
