class_name CombatLimb
extends Sprite2D

@export var limb_name: String = "Empty Limb"
@export var max_health: int = 100
@export var is_vital: bool = false

var current_health: int
var is_destroyed: bool = false
var is_highlighted: bool = false
var is_aoe_highlighted: bool = false

# Auto generate collision polygon
var alpha_threshold: float = 0.2 # Threshold for generating collision polygons from texture alpha
var epsilon: float = 2.0 # Epsilon for polygon simplification when generating collision polygons

signal limb_damaged(limb: CombatLimb, damage: int, remaining_health: int)
signal limb_destroyed(limb: CombatLimb)
signal limb_clicked(limb: CombatLimb)
signal mouse_entered_limb
signal mouse_exited_limb

func _ready() -> void:
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
	is_destroyed = true
	visible = false
	limb_destroyed.emit(self)

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
	tween.tween_property(self, "modulate", Color.RED, 0.10)
	if is_highlighted:
		tween.tween_property(self, "modulate", Color.GREEN, 0.20)
		return
	if is_aoe_highlighted:
		tween.tween_property(self, "modulate", Color(1, 0.5, 0), 0.20)
		return
	tween.tween_property(self, "modulate", Color.WHITE, 0.20)
