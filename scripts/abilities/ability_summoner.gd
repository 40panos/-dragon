class_name SummonerAbility
extends EnemyAbility
## Καλεστής: κάθε Ν γύρους γεννάει minion σε τυχαίο ελεύθερο κελί.
##
## Η ζωή του minion είναι ποσοστό της δικής του και μειώνεται όσο πιο μπροστά
## (χαμηλά) γεννιέται. Απαγορεύεται στις πρώτες γραμμές.

@export var every := 3
@export var hp_ratio := 0.5
@export var min_row := 2
@export var minion_id := "goblin"

## Πόσες σειρές αμέσως πριν τη γραμμή θανάτου μένουν απαγορευμένες. Χωρίς αυτό
## ο καλεστής μπορούσε να πετάξει minion μία ανάσα πάνω από τον δράκο, εκεί που
## δεν προλαβαίνεις να αντιδράσεις.
@export var keep_clear := 2

var _rounds := 0


func on_round_end(block, game) -> void:
	_rounds += 1
	if _rounds % every != 0:
		return
	game.summon_minion(block, minion_id, hp_ratio, min_row, keep_clear)


func badge() -> String:
	return "*"
