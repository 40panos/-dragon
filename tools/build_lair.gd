extends SceneTree
## Συνθέτει το art/lair.png — την ηφαιστειακή φωλιά του δράκου, τη λωρίδα
## που κάθεται πάνω στην αμάχητη σειρά, ανάμεσα στη γραμμή θανάτου και το HUD.
##
##   godot --headless --path . --script tools/build_lair.gd
##
## Ίδια λογική με build_floor.gd / build_frame.gd: το main τραβάει ΕΝΑ έτοιμο
## texture, οπότε η διάταξη ψήνεται εδώ μια φορά με σταθερό seed. Έτσι η
## πυκνότητα και οι θέσεις ρυθμίζονται χωρίς να ξαναφτιάχνονται τα στοιχεία.
##
## Ο καμβάς είναι σε art pixels· το παιχνίδι τον δείχνει στο x2 (ίδια κλίμακα
## με τον δράκο: texture 64 -> draw_width 128), οπότε ΚΑΘΕ διάσταση εδώ είναι
## η μισή της οθόνης. Μεγέθυνση μόνο ακέραια, καμία αναδειγματοληψία.

const W := 360               # 360 * 2 = 720 = όλο το πλάτος της οθόνης, ώστε
                             # τα ηφαίστεια να πατάνε ΠΑΝΩ στα ξύλινα πλαϊνά
const H := 64                # 64 * 2 = 128, ψηλότερο από τη ζώνη ώστε να
                             # ξεπροβάλλουν τα ψηλά στοιχεία πάνω της
const SEED := 20260921

## Πού πέφτει το πλαίσιο μέσα στον καμβά (BORDER 60 οθόνη = 30 art). Τα ψηλά
## στοιχεία κάθονται γύρω από αυτά τα σημεία, όχι μέσα στην πίστα.
const BORDER := 30
const PF_RIGHT := W - BORDER

## Το κέντρο ανήκει στον δράκο και μένει άδειο — εκεί περνάει και η βολή.
## Ο δράκος πιάνει 128 οθόνη = 64 art γύρω από το x=180· η ζώνη είναι πολύ
## πλατύτερη από αυτόν επίτηδες, ώστε το βλέμμα να πηγαίνει στα άκρα.
const KEEP_CLEAR_MIN := 110
const KEEP_CLEAR_MAX := 250

var rng := RandomNumberGenerator.new()
var cache := {}


func _img(name_: String) -> Image:
	if cache.has(name_):
		return cache[name_]
	var tex: Texture2D = load("res://art/%s.png" % name_)
	if tex == null:
		push_error("λείπει: " + name_)
		quit(1)
	var im := tex.get_image()
	im.convert(Image.FORMAT_RGBA8)
	cache[name_] = im
	return im


## Τοποθετεί ένα στοιχείο ώστε το ΑΔΙΑΦΑΝΟ του κομμάτι να κάθεται με το κέντρο
## του στο cx και τη βάση του στο baseline. Χωρίς αυτό κάθε στοιχείο θα
## κρεμόταν διαφορετικά, γιατί το κενό κάτω από το σχέδιο διαφέρει ανά καμβά.
func _place(out: Image, name_: String, cx: int, baseline: int, flip := false) -> void:
	var im := _img(name_)
	if flip:
		im = Image.create_from_data(im.get_width(), im.get_height(),
			false, im.get_format(), im.get_data())
		im.flip_x()
	var r := im.get_used_rect()
	var x := cx - r.position.x - int(r.size.x * 0.5)
	var y := baseline - r.position.y - r.size.y
	# blend, όχι blit: τα στοιχεία έχουν διάφανο φόντο και πρέπει να πατήσουν
	# πάνω σε ό,τι μπήκε πριν, όχι να το τρυπήσουν
	out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))


## Αληθές όσο το x απέχει από τη θέση του δράκου. Χωρίς αυτό οι φλόγες
## έβγαιναν πίσω και ανάμεσα στα πόδια του, και τον έπνιγαν.
func _clear(x: int) -> bool:
	return x < KEEP_CLEAR_MIN or x > KEEP_CLEAR_MAX


func _initialize() -> void:
	rng.seed = SEED
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)

	# --- 1. το πάτωμα: μακρόστενη κρούστα σε όλο το πλάτος.
	# Το αδιάφανο της crust_a είναι 14 art px = 28 οθόνη, δηλαδή περίπου το
	# ένα τρίτο ενός κελιού (85.7 / 3 = 28.6).
	var strip := ["vol_crust_a", "vol_crust_b", "vol_crust_a", "vol_crust_b",
		"vol_crust_a"]
	for i in strip.size():
		_place(out, strip[i], 36 + i * 72, H + rng.randi_range(0, 1), i % 2 == 1)

	# --- 2. ψηλά στοιχεία. Κάθονται ΠΑΝΩ στα ξύλινα πλαϊνά και αμέσως δίπλα
	# τους, ώστε να κορνιζάρουν την πίστα αντί να στέκονται μέσα της.
	_place(out, "vol_vent", BORDER - 16, H)
	_place(out, "vol_spire", BORDER + 22, H)
	_place(out, "vol_vent", PF_RIGHT + 16, H, true)
	_place(out, "vol_spire", PF_RIGHT - 22, H, true)

	# --- 3. βράχοι: όλοι στριμωγμένοι στις δύο άκρες, κανένας στο κέντρο
	for x in [4, 46, 84, W - 84, W - 46, W - 4]:
		_place(out, "vol_rock", x, H - rng.randi_range(0, 2), rng.randf() < 0.5)

	# --- 4. φλόγες. Ανομοιόμορφες αποστάσεις επίτηδες: σε ίσο βήμα έμοιαζαν
	# με κάγκελα. Το _clear() τις κρατάει έξω από τη θέση του δράκου.
	for x in [24, 66, W - 66, W - 24]:
		if _clear(x):
			_place(out, "vol_flame_lg", x, H - 5 - rng.randi_range(0, 3))
	for x in [6, 44, 92, W - 92, W - 44, W - 6]:
		if _clear(x):
			_place(out, "vol_flame_sm", x, H - rng.randi_range(0, 2), rng.randf() < 0.5)

	var path := "res://art/lair.png"
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
		quit(1)
	print("γράφτηκε %s — %dx%d (οθόνη %dx%d)" % [path, W, H, W * 2, H * 2])
	quit(0)
