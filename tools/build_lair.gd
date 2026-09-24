extends SceneTree
## Συνθέτει τις λωρίδες της φωλιάς — τη ζώνη που κάθεται πάνω στην αμάχητη
## σειρά, ανάμεσα στη γραμμή θανάτου και το HUD.
##
##   godot --headless --path . --script tools/build_lair.gd
##
## Βγάζει ΔΥΟ σετ με κοινή γεωμετρία, art/lair_1..5.png (ηφαιστειακό) και
## art/castle_1..5.png (κάστρο). Ποιο παίζει το λέει το LAIR_SET του main.
##
## Ίδια λογική με build_floor.gd / build_frame.gd: το main τραβάει έτοιμα
## textures, οπότε η διάταξη ψήνεται εδώ μια φορά με σταθερό seed. Έτσι η
## πυκνότητα και οι θέσεις ρυθμίζονται χωρίς να ξαναφτιάχνονται τα στοιχεία.
##
## Ο καμβάς είναι σε art pixels· το παιχνίδι τον δείχνει στο x2 (ίδια κλίμακα
## με τον δράκο: texture 64 -> draw_width 128), οπότε ΚΑΘΕ διάσταση εδώ είναι
## η μισή της οθόνης. Μεγέθυνση μόνο ακέραια, καμία αναδειγματοληψία.
##
## Κάθε καρέ βγαίνει από το αντίστοιχο καρέ κάθε στοιχείου. Το main τα παίζει
## ping-pong (1-2-3-4-5-4-3-2), γιατί τα καρέ δεν κλείνουν κύκλο: η λάβα
## φτάνει πιο φωτεινή στο 5 απ' ό,τι ξεκίνησε στο 1, και σε ευθύ βρόχο θα
## πηδούσε. Το πάτωμα μένει επίτηδες ακίνητο — επαναλαμβάνεται πέντε φορές
## και θα χτυπούσε το μάτι.

const W := 360               # 360 * 2 = 720 = όλο το πλάτος της οθόνης, ώστε
                             # τα ψηλά στοιχεία να πατάνε ΠΑΝΩ στα ξύλινα πλαϊνά
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

const FRAMES := 5            # όσα καρέ έχει κάθε ζωντανεμένο στοιχείο

## Τα δύο σετ. Κάθε ρόλος δείχνει σε ένα αρχείο του art/· το "tall_in" μπορεί
## να μείνει κενό, και τότε η πλευρά έχει ένα μόνο ψηλό στοιχείο. Το "animated"
## λέει ποια στοιχεία έχουν αριθμημένα καρέ (x_1..5) και ποια είναι σκέτα.
const SETS := [
	{
		"out": "lair",
		"floor_a": "vol_crust_a", "floor_b": "vol_crust_b",
		"tall_out": "vol_vent", "tall_in": "vol_spire",
		"rock": "vol_rock", "fire": "vol_flame_lg",
		"animated": ["vol_vent", "vol_spire", "vol_crust_b", "vol_rock",
			"vol_flame_lg"],
	},
	{
		# Το κάστρο έχει ΕΝΑΝ πυργίσκο ανά πλευρά — δύο συνολικά, στη θέση που
		# είχαν τα ηφαίστεια. Οι πολεμίστρες είναι χαμηλές όσο και η κρούστα
		# λάβας, οπότε δεν κρύβουν τον δράκο. Μόνο το μαγκάλι κινείται.
		"out": "castle",
		"floor_a": "cas_wall_a", "floor_b": "cas_wall_b",
		"tall_out": "cas_turret_wide", "tall_in": "cas_turret",
		"rock": "cas_rubble", "fire": "",
		"animated": [],
	},
]

var rng := RandomNumberGenerator.new()
var cache := {}
var frame := 1               # ποιο καρέ χτίζεται τώρα
var animated: Array = []     # τα ζωντανεμένα του σετ που χτίζεται τώρα


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


## Το αρχείο του στοιχείου για το τρέχον καρέ. Τα ακίνητα στοιχεία δεν έχουν
## αρίθμηση και επιστρέφουν πάντα το ίδιο.
func _file(name_: String) -> String:
	return "%s_%d" % [name_, frame] if animated.has(name_) else name_


## Τοποθετεί ένα στοιχείο ώστε το ΑΔΙΑΦΑΝΟ του κομμάτι να κάθεται με το κέντρο
## του στο cx και τη βάση του στο baseline. Χωρίς αυτό κάθε στοιχείο θα
## κρεμόταν διαφορετικά, γιατί το κενό κάτω από το σχέδιο διαφέρει ανά καμβά.
##
## Η ευθυγράμμιση διαβάζεται ΠΑΝΤΑ από το πρώτο καρέ. Αν κάθε καρέ στοιχιζόταν
## στο δικό του bbox, μια φλόγα που μικραίνει θα τραβούσε τον εαυτό της προς
## τα κάτω και το στοιχείο θα πηδούσε μέσα στον βρόχο.
##
## Κενό όνομα σημαίνει «αυτός ο ρόλος δεν υπάρχει σε αυτό το σετ».
func _place(out: Image, name_: String, cx: int, baseline: int, flip := false) -> void:
	if name_.is_empty():
		return
	var im := _img(_file(name_))
	var r := _img("%s_1" % name_).get_used_rect() if animated.has(name_) \
		else im.get_used_rect()
	if flip:
		im = Image.create_from_data(im.get_width(), im.get_height(),
			false, im.get_format(), im.get_data())
		im.flip_x()
		r.position.x = im.get_width() - r.position.x - r.size.x
	var x := cx - r.position.x - int(r.size.x * 0.5)
	var y := baseline - r.position.y - r.size.y
	# blend, όχι blit: τα στοιχεία έχουν διάφανο φόντο και πρέπει να πατήσουν
	# πάνω σε ό,τι μπήκε πριν, όχι να το τρυπήσουν
	out.blend_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), Vector2i(x, y))


## Αληθές όσο το x απέχει από τη θέση του δράκου. Χωρίς αυτό οι φωτιές
## έβγαιναν πίσω και ανάμεσα στα πόδια του, και τον έπνιγαν.
func _clear(x: int) -> bool:
	return x < KEEP_CLEAR_MIN or x > KEEP_CLEAR_MAX


## Χτίζει ΕΝΑ καρέ ενός σετ. Το rng ξεκινάει από το ίδιο seed κάθε φορά, ώστε
## οι θέσεις και τα καθρεφτίσματα να είναι ίδια σε όλα τα καρέ — αλλιώς η
## φωλιά θα ανακατευόταν ολόκληρη σε κάθε βήμα του βρόχου.
func _build(s: Dictionary) -> Image:
	rng.seed = SEED
	var out := Image.create(W, H, false, Image.FORMAT_RGBA8)

	# --- 1. το πάτωμα, σε όλο το πλάτος. Το αδιάφανό του είναι γύρω στα 14
	# art px = 28 οθόνη, δηλαδή περίπου το ένα τρίτο ενός κελιού (85.7 / 3).
	# Το floor_b (η χαλασμένη εκδοχή) μπαίνει ΜΙΑ φορά μόνο: εναλλάξ με το
	# floor_a έδειχνε το μισό τείχος γκρεμισμένο. Όχι στη μέση — εκεί στέκεται
	# ο δράκος και το έκρυβε ολόκληρο.
	for i in 5:
		var tile: String = s["floor_b"] if i == 1 else s["floor_a"]
		_place(out, tile, 36 + i * 72, H + rng.randi_range(0, 1), i % 2 == 1)

	# --- 2. ψηλά στοιχεία. Κάθονται ΠΑΝΩ στα ξύλινα πλαϊνά και αμέσως δίπλα
	# τους, ώστε να κορνιζάρουν την πίστα αντί να στέκονται μέσα της.
	_place(out, s["tall_out"], BORDER - 16, H)
	_place(out, s["tall_in"], BORDER + 22, H)
	_place(out, s["tall_out"], PF_RIGHT + 16, H, true)
	_place(out, s["tall_in"], PF_RIGHT - 22, H, true)

	# --- 3. πέτρες: όλες στριμωγμένες στις δύο άκρες, καμία στο κέντρο
	for x in [4, 46, 84, W - 84, W - 46, W - 4]:
		_place(out, s["rock"], x, H - rng.randi_range(0, 2), rng.randf() < 0.5)

	# --- 4. φωτιές. Ανομοιόμορφες αποστάσεις επίτηδες: σε ίσο βήμα έμοιαζαν
	# με κάγκελα. Το _clear() τις κρατάει έξω από τη θέση του δράκου.
	for x in [24, 66, W - 66, W - 24]:
		if _clear(x):
			_place(out, s["fire"], x, H - 5 - rng.randi_range(0, 3))

	return out


func _initialize() -> void:
	for s in SETS:
		animated = s["animated"]
		for f in range(1, FRAMES + 1):
			frame = f
			var path := "res://art/%s_%d.png" % [s["out"], f]
			var err := _build(s).save_png(ProjectSettings.globalize_path(path))
			if err != OK:
				push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
				quit(1)
		print("γράφτηκε %s_1..%d — %dx%d (οθόνη %dx%d)" % [
			s["out"], FRAMES, W, H, W * 2, H * 2])
	quit(0)
