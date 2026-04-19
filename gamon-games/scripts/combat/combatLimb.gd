class_name CombatLimb
extends Sprite2D

@export var limb_name: String = "Empty Limb"
@export var max_health: int = 100
@export var is_vital: bool = false
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
	if visible and texture:
		_setup_click_area()

func _setup_click_area() -> void:
	# Auto generate collision polygons from the sprite's texture alpha clicking
	# So we don't have to manually add CollisionPolygon2D nodes for each limb
	
	# Create an Area2D with collision from the sprite's alpha channel
	var area := Area2D.new()
	area.name = "ClickArea"
	area.input_pickable = true
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

	area.input_event.connect(_on_area_input_event)
	area.mouse_entered.connect(func(): mouse_entered_limb.emit())
	area.mouse_exited.connect(func(): mouse_exited_limb.emit())

func _on_area_input_event(viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if is_destroyed:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		limb_clicked.emit(self)
		# Consume the event so limbs behind this one (e.g. torso behind an arm) don't also get clicked
		viewport.set_input_as_handled()

func set_highlighted() -> void:
	if is_destroyed or is_highlighted:
		return
	is_highlighted = true
	modulate = Color.GREEN

func set_unhighlighted() -> void:
	if not is_highlighted:
		return
	is_highlighted = false
	modulate = Color(1, 0.5, 0) if is_aoe_highlighted else Color.WHITE

func set_aoe_highlighted() -> void:
	if is_destroyed or is_aoe_highlighted:
		return
	is_aoe_highlighted = true
	if not is_highlighted:
		modulate = Color(1, 0.5, 0)

func set_aoe_unhighlighted() -> void:
	if not is_aoe_highlighted:
		return
	is_aoe_highlighted = false
	modulate = Color.GREEN if is_highlighted else Color.WHITE

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
	print(limb_name, " took ", amount, " damage — HP: ", current_health, "/", max_health)
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

	limb_destroyed.emit(self)
	_play_destroy_animation()

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

func _finalize_destroy_visual() -> void:
	visible = false
	scale = _initial_scale
	position = _initial_position
	modulate = Color.WHITE

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
