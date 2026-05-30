extends Node

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
