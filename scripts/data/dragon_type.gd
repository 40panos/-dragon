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

## Καρέ animation ανά κατάσταση. Αν είναι άδεια, πέφτει στα sprite_* παραπάνω.
@export var frames_idle: Array[Texture2D] = []
@export var frames_ready: Array[Texture2D] = []
@export var frames_fire: Array[Texture2D] = []

## Το φλογερό περίγραμμα που ανάβει γύρω από τον εχθρό όταν τον χτυπάς. Ανήκει
## στον δράκο, όχι στον εχθρό: είναι το σημάδι του χτυπήματος του παίκτη, οπότε
## ο επόμενος δράκος θα αφήνει δικό του. Άδειο = οι παλιοί λευκοί δακτύλιοι.
@export var glow_frames: Array[Texture2D] = []

## Τα βλήματα του δράκου. Ο ember ρίχνει μπάλες φωτιάς, ο death δρεπάνια.
## Άδειο = πέφτει στα καθολικά fireball / fireball_aoe, ώστε οι παλιοί δράκοι
## να μη χρειάζονται αλλαγή.
@export var ball_sprite: Texture2D
@export var ball_aoe_sprite: Texture2D

## Το χρώμα που εκπέμπει ο δράκος: λάμψη στο στόμα, σπίθες στη βολή και στο
## χτύπημα. Ο ember είναι πορτοκαλί, ο death πράσινος. Χωρίς αυτό οι σπίθες
## έμεναν φωτιάς σε κάθε δράκο.
@export var accent := Color("ff9e2c")

## Στροφές ανά δευτερόλεπτο του βλήματος. 0 = δείχνει προς την πορεία του,
## που ταιριάζει σε μπάλα φωτιάς· τα δρεπάνια στριφογυρίζουν.
@export var ball_spin := 0.0

## Προς τα πού δείχνει η μύτη του σχεδίου του βλήματος, σε ακτίνια: PI για τη
## φωτιά (κοιτάει αριστερά), -PI/4 για έναν κρύσταλλο σχεδιασμένο πάνω-δεξιά.
## Το βλήμα γυρνάει ώστε η μύτη να πέφτει στην πορεία του.
@export var ball_heading := PI

## Χρωματισμός για τη φλόγα της μεταμόρφωσης. Τα καρέ είναι ήδη ζωγραφισμένα
## σε φωτιά, οπότε ο ember μένει στο λευκό — modulate με το ίδιο του το
## πορτοκαλί θα τα σκούραινε. Ο death το γυρίζει πράσινο.
@export var awaken_tint := Color.WHITE

## Πώς παίζει η αύρα της μεταμόρφωσης: "flame" = τα ζωγραφισμένα καρέ φωτιάς,
## "skull" = μαύρη νεκροκεφαλή που ανοίγει, φτιαγμένη από το ίδιο το κεφάλι
## του δράκου. Ο death δεν έχει δικά του καρέ φλόγας και δεν του ταιριάζουν.
@export_enum("flame", "skull") var awaken_style := "flame"

## Αντί για λάμψη στο στόμα, χύνεται σκοτάδι από τις κόγχες όταν ρίχνει.
@export var dark_eyes := false

## Αύρα από παγωμένες ρούνες γύρω από το κεφάλι (scripts/glyph_aura.gd):
## ρούνες που ανεβαίνουν, παγωμένη σκόνη, και έκρηξη ρουνών στη βολή.
@export var glyph_aura := false

@export var fps_idle := 3.0
@export var fps_ready := 7.0
@export var fps_fire := 11.0

## Πλάτος σχεδίασης σε pixel· το ύψος βγαίνει από την αναλογία της εικόνας.
@export var draw_width := 120.0

@export var tint := Color.WHITE

## Προαιρετική «ξυπνημένη» μορφή — ένας δεύτερος DragonType που παίρνει τη θέση
## αυτού όσο καίει το INFERNO. Δηλώνεται ως Resource και όχι ως DragonType
## γιατί ο τύπος θα αναφερόταν στον εαυτό του· το main κάνει τον έλεγχο.
@export var awakened: Resource


## Το καρέ που πρέπει να φαίνεται τώρα. Τα καρέ παίζουν ping-pong (0,1,2,1…)
## ώστε ο βρόχος να μην κάνει άλμα στο γύρισμα.
func frame_for(phase: String, aiming: bool, time: float) -> Texture2D:
	var arr: Array[Texture2D] = frames_idle
	var fps := fps_idle
	if phase == "shoot":
		arr = frames_fire
		fps = fps_fire
	elif aiming:
		arr = frames_ready
		fps = fps_ready

	if arr.is_empty():
		return sprite_for(phase, aiming)
	if arr.size() == 1:
		return arr[0]

	var period := arr.size() * 2 - 2
	var i := int(time * fps) % period
	if i >= arr.size():
		i = period - i
	return arr[i]


## Επιστρέφει το στατικό sprite που ταιριάζει στη φάση του παιχνιδιού.
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
## freeze  = παγώνει όλους τους εχθρούς για FREEZE_ROUNDS γύρους (βλ. main)
@export_enum("inferno", "swarm", "freeze") var special := "inferno"

## Πόσοι σκοτωμοί χρειάζονται για να γεμίσει το special.
@export var special_cost := 15.0

## every5_double = κάθε 5η μπάλα κάνει διπλή ζημιά
## ball_every5   = +1 μπάλα κάθε 5 γύρους
@export_enum("every5_double", "ball_every5") var passive := "every5_double"

## Ποια περιοχή πρέπει να έχει περαστεί για να ξεκλειδώσει (0 = εξαρχής).
@export var unlock_after_area := 0


func special_name() -> String:
	match special:
		"swarm": return "SWARM"
		"freeze": return "FREEZE"
		_: return "INFERNO"


## Σύντομες περιγραφές για την κάρτα επιλογής δράκου.
func special_desc() -> String:
	match special:
		"swarm": return "extra volley"
		"freeze": return "enemies freeze, 2 rounds"
		_: return "x3 damage, one volley"


func passive_desc() -> String:
	match passive:
		"ball_every5": return "+1 ball / 5 rounds"
		_: return "every 5th ball x2"
