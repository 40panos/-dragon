class_name DragonType
extends Resource
## Ορισμός δράκου: εμφάνιση, special που φορτώνει με ζημιά, και passive.

@export var id := "ember"
@export var display_name := "Ember"
@export var sprite: Texture2D
@export var tint := Color.WHITE

## inferno = η επόμενη βολή κάνει τριπλή ζημιά
## swarm   = ρίχνει αμέσως μια ολόκληρη έξτρα βολή
@export_enum("inferno", "swarm") var special := "inferno"

## Πόση συνολική ζημιά χρειάζεται για να γεμίσει το special.
@export var special_cost := 150.0

## every5_double = κάθε 5η μπάλα κάνει διπλή ζημιά
## ball_every5   = +1 μπάλα κάθε 5 γύρους
@export_enum("every5_double", "ball_every5") var passive := "every5_double"

## Ποια περιοχή πρέπει να έχει περαστεί για να ξεκλειδώσει (0 = εξαρχής).
@export var unlock_after_area := 0


func special_name() -> String:
	match special:
		"swarm": return "SWARM"
		_: return "INFERNO"
