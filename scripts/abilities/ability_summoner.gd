class_name SummonerAbility
extends EnemyAbility
## Καλεστής: κάθε Ν γύρους γεννάει minion σε τυχαίο ελεύθερο κελί.
##
## Η ζωή του minion είναι ποσοστό της δικής του και μειώνεται όσο πιο μπροστά
## (χαμηλά) γεννιέται. Απαγορεύεται στις πρώτες γραμμές.

@export var every := 3
@export var hp_ratio := 0.5
@export var min_row := 2
## Η χαμηλότερη σειρά όπου επιτρέπεται να γεννηθεί minion, ώστε να μη γεννιέται
## μία ανάσα πριν από το game over.
@export var max_row := 7
@export var minion_id := "goblin"

var _rounds := 0


func on_round_end(block, game) -> void:
	_rounds += 1
	if _rounds % every != 0:
		return
	game.summon_minion(block, minion_id, hp_ratio, min_row, max_row)


func badge() -> String:
	return "*"
