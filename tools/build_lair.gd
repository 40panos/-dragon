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

const W := 300               # 300 * 2 = 600 = PF_W
const H := 64                # 64 * 2 = 128, ψηλότερο από τη ζώνη ώστε να
                             # ξεπροβάλλουν τα ψηλά στοιχεία πάνω της
const SEED := 20260921

## Το κέντρο ανήκει στον δράκο — τα ψηλά στοιχεία το αποφεύγουν για να μην
## τον κρύβουν. Ο δράκος πιάνει 128 οθόνη = 64 art, κεντραρισμένος.
const KEEP_CLEAR_MIN := 108
const KEEP_CLEAR_MAX := 192

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
	var strip := ["vol_crust_a", "vol_crust_b", "vol_crust_a", "vol_crust_b"]
	for i in strip.size():
		_place(out, strip[i], 38 + i * 76, H + rng.randi_range(0, 1), i % 2 == 1)

	# --- 2. ψηλά στοιχεία, μόνο στα άκρα
	_place(out, "vol_vent", 26, H)
	_place(out, "vol_spire", 72, H)
	_place(out, "vol_spire", 230, H, true)
	_place(out, "vol_vent", 274, H, true)

	# --- 3. βράχοι: πυκνοί στα άκρα, αραιοί στη μέση
	for x in [8, 48, 94, 206, 252, 292]:
		_place(out, "vol_rock", x, H - rng.randi_range(0, 2), rng.randf() < 0.5)

	# --- 4. φλόγες. Ανομοιόμορφες αποστάσεις επίτηδες: σε ίσο βήμα έμοιαζαν
	# με κάγκελα. Το _clear() τις κρατάει έξω από τη θέση του δράκου.
	for x in [42, 88, 216, 264]:
		if _clear(x):
			_place(out, "vol_flame_lg", x, H - 5 - rng.randi_range(0, 3))
	for x in [16, 64, 116, 186, 238, 288]:
		if _clear(x):
			_place(out, "vol_flame_sm", x, H - rng.randi_range(0, 2), rng.randf() < 0.5)

	var path := "res://art/lair.png"
	var err := out.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
		quit(1)
	print("γράφτηκε %s — %dx%d (οθόνη %dx%d)" % [path, W, H, W * 2, H * 2])
	quit(0)
