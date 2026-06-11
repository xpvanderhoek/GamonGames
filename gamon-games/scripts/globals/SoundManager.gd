extends Node

func _ready() -> void:
	play_main_menu_music()

func play_main_menu_music() -> void:
	if !$BGMMainMenu.playing:
		$BGMMainMenu.play()

func stop_main_menu_music() -> void:
	$BGMMainMenu.stop()

func play_combat_music() -> void:
	if $BGMCombat.playing:
		return
	$BGMCombat.volume_db = -40.0
	$BGMCombat.play()
	var tween = get_tree().create_tween().bind_node(self)
	tween.tween_property($BGMCombat, "volume_db", -10.0, 1.5)

func stop_combat_music() -> void:
	if !$BGMCombat.playing:
		return
	var tween = get_tree().create_tween().bind_node(self)
	tween.tween_property($BGMCombat, "volume_db", -40.0, 1.5)
	tween.tween_callback($BGMCombat.stop)
	tween.tween_callback(func(): $BGMCombat.volume_db = -10.0)

func play_shop_music() -> void:
	if $BGMShop.playing:
		return
	$BGMShop.volume_db = -40.0
	$BGMShop.play()
	var tween = get_tree().create_tween().bind_node(self)
	tween.tween_property($BGMShop, "volume_db", -10.0, 1.5)

func stop_shop_music() -> void:
	if !$BGMShop.playing:
		return
	var tween = get_tree().create_tween().bind_node(self)
	tween.tween_property($BGMShop, "volume_db", -40.0, 1.5)
	tween.tween_callback($BGMShop.stop)
	tween.tween_callback(func(): $BGMShop.volume_db = -10.0)

func play_click():
	$SFXClick.play()

func play_hover():
	$SFXHover.play()

func play_potion():
	$SFXPotion.play()

func play_pencil():
	$SFXPencil.play()

func play_purchase():
	$SFXPurchase.play()

func play_failsound():
	$SFXFailSound.play()

func play_miss():
	$SFXMiss.play()

func play_xpbar_tick(pitch: float = 1.0) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = $SFXXPBarTick.stream
	player.bus = &"SFX"
	player.pitch_scale = pitch
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func play_levelup():
	$SFXLevelUp.play()

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
