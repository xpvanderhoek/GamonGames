extends Interactable

var is_introduced : bool = PlayerStats.knows_ghost
var is_deal_offered : bool = false

signal open_portal

func get_prompt_text() -> String:
	return "Talk"

func interact():
	if is_busy:
		return

	is_busy = true

	if !is_introduced:
		DialogueManager.start_dialogue("limbo_intro_1")
		await DialogueManager.dialogue_finished
		is_introduced = true
		is_deal_offered = true
	
	elif is_deal_offered:
		DialogueManager.start_dialogue("limbo_intro_2")
		await DialogueManager.dialogue_finished
		is_introduced = true
		is_deal_offered = false
		open_portal.emit()
		PlayerStats.knows_ghost = true
	
	else:
		DialogueManager.start_dialogue("ghost_greeting")
		await DialogueManager.dialogue_finished

	is_busy = false
