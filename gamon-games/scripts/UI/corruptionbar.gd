extends TextureProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	RunData.time_remaining_changed.connect(update)

func update():
	var elapsed_time = RunData.RUN_DURATION - RunData.time_remaining
	value = elapsed_time * 100 / RunData.RUN_DURATION
