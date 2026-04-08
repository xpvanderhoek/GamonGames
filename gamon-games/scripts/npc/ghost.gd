extends Interactable

func get_prompt_text() -> String:
	return "Talk"

func interact():
	if is_busy:
		return
	
	is_busy = true

	DialogueManager.start_dialogue("limbo_intro")
	await DialogueManager.dialogue_finished
	is_busy = false
