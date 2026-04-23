const PUZZLES := {
	"slide": {
		"NL": {
			"title": "Schuifpuzzel",
			"description": "Beweeg de tegels om het plaatje compleet te maken.",
			"tips": [
				"Werk rij voor rij",
				"Begin vanaf boven"
			],
			"reward": "Hoe sneller je hem oplost, hoe meer coins te verdienen valt.\nElke seconde gaat er 1 coin af.\nSucces!"
		},
		"EN": {
			"title": "Slide Puzzle",
			"description": "Move the tiles to complete the image.",
			"tips": [
				"Work row by row",
				"Start from the top"
			],
			"reward": "The faster you solve it, the more coins you can earn.\n1 coin is deducted every second\nGood Luck!"
		}
	},
	"simon_says_normal": {
		"NL": {
			"title": "Simon Says (Normaal)",
			"description": "Onthoud de volgorde en herhaal deze correct.",
			"tips": [
				"Vind een patroon dat makkelijk te onthouden is"
			],
			"reward": "Deze puzzel levert [color=#1a7726]1 coin[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "Simon Says (Normal)",
			"description": "Remember the sequence and repeat it correctly.",
			"tips": [
				"Look for patterns that are easy to remember"
			],
			"reward": "You earn [color=#1a7726]1 coin[/color] for every round you survive\nGood luck!"
		}
	},
	"simon_says_speed": {
		"NL": {
			"title": "Simon Says (Snelheid)",
			"description": "Onthoud de volgorde en herhaal deze correct, maar de knoppen flikkeren sneller",
			"tips": [
				"Vind een patroon in de volgorde dat makkelijk te onthouden is"
			],
			"reward": "Deze puzzel levert [color=#1a7726]2 coins[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "Simon Says (Speed)",
			"description": "Remember the sequence and repeat it correctly, but the buttons flash faster.",
			"tips": [
				"Look for patterns that are easy to remember"
			],
			"reward": "You earn [color=#1a7726]2 coins[/color] for every round you survive\nGood luck!"
		}
	},
	"simon_says_mirror": {
		"NL": {
			"title": "syaS somiS (Gespiegeld)",
			"description": "Onthoud de volgorde en herhaal deze correct. \n Maar let op, doe hetgene in spiegelbeeld van wat hij laat zien.",
			"tips": [
				"Vind een patroon dat makkelijk te onthouden is",
				"Het patroon is in spiegelbeeld!"
			],
			"reward": "Deze puzzel levert [color=#1a7726]3 coins[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "syaS somiS (Mirrored)",
			"description": "Remember the sequence and repeat it correctly.\nBut be careful: you must mirror the sequence.",
			"tips": [
				"Look for patterns that are easy to remember",
				"The pattern is mirrored!"
			],
			"reward": "You earn [color=#1a7726]3 coins[/color] for every round you survive\nGood luck!"
		}
	},
	"simon_says_reverse": {
		"NL": {
			"title": "Says Simon (Omgedraaid)",
			"description": "Onthoud de volgorde en herhaal deze correct. \n Maar let op, de volgorde die gespeeld wordt, moet je andersom herhalen.\nVan het einde naar het begin dus!",
			"tips": [
				"Vind een patroon dat makkelijk te onthouden is",
				"Het patroon is van achter naar voren!",
				"Als het patroon 6, 3, 1 is, moet jij 1, 3, 6 indrukken in die volgorde"
			],
			"reward": "Deze puzzel levert [color=#1a7726]4 coins[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "Simon Says (Reverse)",
			"description": "Remember the sequence and repeat it correctly.\nBut be careful: you must repeat it in reverse order.\nFrom end to start!",
			"tips": [
				"Look for patterns that are easy to remember",
				"The pattern is reversed!",
				"If the pattern is 6, 3, 1, you must press 1, 3, 6"
			],
			"reward": "You earn [color=#1a7726]4 coins[/color] for every round you survive\nGood luck!"
		}
	},
	"simon_says_inverted": {
		"NL": {
			"title": "Inverted Says",
			"description": "Onthoud de volgorde en herhaal deze correct. \n Maar alle knoppen geven licht, behalve degene die jij nodig hebt!",
			"tips": [
				"Vind een patroon dat makkelijk te onthouden is",
				"Zit op een afstandje om beter overzicht te houden"
			],
			"reward": "Deze puzzel levert [color=#1a7726]3 coins[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "Simon Says (Inverted)",
			"description": "Remember the sequence and repeat it correctly.\nBut all buttons light up except the ones you need!",
			"tips": [
				"Look for patterns that are easy to remember",
				"Sit a bit further back to get a better overview"
			],
			"reward": "You earn [color=#1a7726]3 coins[/color] for every round you survive\nGood luck!"
		}
	},
	"simon_says_color": {
		"NL": {
			"title": "Colored Says (Gekleurd)",
			"description": "Onthoud de volgorde en herhaal deze correct. \n Maar er komen meerdere kleuren.\nJe moet de aangegeven kleur aanklikken en de rest met rust laten",
			"tips": [
				"Vind een patroon dat makkelijk te onthouden is",
				"Onthoud alleen de aangegeven kleur",
				"Nu moet je alleen de knoppen met deze kleur indrukken: "
			],
			"reward": "Deze puzzel levert [color=#1a7726]3 coins[/color] op per ronde dat je overleeft\nSucces!"
		},
		"EN": {
			"title": "Simon Says (Color)",
			"description": "Remember the sequence and repeat it correctly.\nMultiple colors will appear.\nBut only press the indicated color and ignore the others.",
			"tips": [
				"Look for patterns that are easy to remember",
				"Focus only on the indicated color",
				"Now you only need to press the buttons with this color: "
			],
			"reward": "You earn [color=#1a7726]3 coins[/color] for every round you survive\nGood luck!"
		}
	}
}

const SKIPPUZZLE := {
	"NL": "Puzzel Overslaan",
	"EN": "Skip Puzzle"
}

const CONTINUE := {
	"NL": "Doorgaan",
	"EN": "Continue"
}

const CLOSEEXPLANATION := {
	"NL": "Speel",
	"EN": "Play"
}
