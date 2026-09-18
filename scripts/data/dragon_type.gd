class_name DragonType
extends Resource
## Ορισμός δράκου: εμφάνιση, special που φορτώνει με ζημιά, και passive.

@export var id := "ember"
@export var display_name := "Ember"

## Εφεδρικό sprite, όταν δεν υπάρχουν ξεχωριστές καταστάσεις.
@export var sprite: Texture2D

## Καταστάσεις: ηρεμία, στόχευση, βολή. Αν λείπουν, χρησιμοποιείται το sprite.
@export var sprite_idle: Texture2D
@export var sprite_ready: Texture2D
@export var sprite_fire: Texture2D

## Πλάτος σχεδίασης σε pixel· το ύψος βγαίνει από την αναλογία της εικόνας.
@export var draw_width := 120.0

@export var tint := Color.WHITE


## Επιστρέφει το sprite που ταιριάζει στη φάση του παιχνιδιού.
func sprite_for(phase: String, aiming: bool) -> Texture2D:
	var chosen: Texture2D = null
	if phase == "shoot":
		chosen = sprite_fire
	elif aiming:
		chosen = sprite_ready
	else:
		chosen = sprite_idle
	if chosen == null:
		chosen = sprite_idle
	if chosen == null:
		chosen = sprite
	return chosen

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
