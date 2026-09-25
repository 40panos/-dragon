extends SceneTree
## Ετοιμάζει τα καρέ του φλογερού περιγράμματος — τη λάμψη που ανάβει γύρω από
## έναν εχθρό τη στιγμή που τον χτυπάς. Κάθε δράκος έχει το δικό του.
##
##   godot --headless --path . --script tools/build_glow.gd
##
## Παίρνει τα ακατέργαστα καρέ από τον φάκελο των προτάσεων και γράφει τα
## art/glow_<σετ>_1..N.png.
##
## Η δουλειά που κάνει: ΑΔΕΙΑΖΕΙ ΤΟ ΚΕΝΤΡΟ. Το PixelLab βγάζει το δαχτυλίδι με
## συμπαγές λευκό μέσα του — το no_background καθαρίζει μόνο ό,τι ακουμπάει την
## άκρη του καμβά, και το κέντρο είναι κλεισμένο από το ίδιο το σχέδιο. Χωρίς
## αυτό το πέρασμα, η λάμψη θα σκέπαζε τον εχθρό με μια λευκή πλάκα.
##
## Το γέμισμα ξεκινάει από τη ΜΕΣΗ και απλώνεται, σταματώντας στο σκούρο
## περίγραμμα του σχεδίου· έτσι οι φλόγες απ' έξω μένουν ανέγγιχτες.

## Κάθε σετ δείχνει στον φάκελο με τα ακατέργαστα καρέ του και στο πρόθεμα
## που έχουν εκεί. Ο δράκος διαλέγει σετ μέσω του write_<δράκος>.gd.
const SETS := [
	{
		"name": "fire",
		"dir": "C:/Users/panos/Documents/bbdragon-art-proposals/glow",
		"prefix": "raw",
	},
	{
		"name": "death",
		"dir": "C:/Users/panos/Documents/bbdragon-art-proposals/death",
		"prefix": "glowraw",
	},
	{
		# σκοτεινή φλόγα, για τη μορφή του death χωρίς μάσκα
		"name": "void",
		"dir": "C:/Users/panos/Documents/bbdragon-art-proposals/death",
		"prefix": "voidglow",
	},
]

const FRAMES := 3            # όσα καρέ κρατάμε — λίγα φτάνουν, η λάμψη είναι στιγμιαία
## Ποια από τα καρέ που ήρθαν κρατάμε. Το PixelLab δίνει 5 (το αρχικό + 4)·
## παίρνουμε ένα στα δύο, ώστε τα τρία να απέχουν αισθητά μεταξύ τους.
const PICK := [1, 3, 5]

## Το γέμισμα περνάει ΜΟΝΟ από σχεδόν λευκό ή ήδη διάφανο. Πρώτη δοκιμή ήταν
## «σταμάτα στο σκούρο», αλλά οι φλόγες έχουν ανοιχτά κίτρινα που πέρναγαν το
## κατώφλι: σε ένα καρέ το γέμισμα δραπέτευσε από το κέντρο και έφαγε μισό
## δαχτυλίδι. Το λευκό του γεμίσματος είναι άχρωμο, οι φλόγες όχι — οπότε το
## κριτήριο δεν είναι η φωτεινότητα αλλά το πόσο κοντά είναι τα τρία κανάλια.
## Το γέμισμα δεν είναι πάντα καθαρό λευκό: σε ένα καρέ ο μισός κύκλος βγήκε
## γκρι. Το κατώφλι κατεβαίνει ως εκεί, και μένει πάνω από το μαύρο περίγραμμα.
const FILL_MIN := 0.28         # πόσο φωτεινό πρέπει να είναι το πιο σκούρο κανάλι
const FILL_SPREAD := 0.12      # πόσο μακριά επιτρέπεται να πέφτουν μεταξύ τους


## Αληθές μόνο για το λευκό γέμισμα και για ό,τι είναι ήδη διάφανο.
func _is_fill(c: Color) -> bool:
	if c.a < 0.5:
		return true
	var lo := minf(c.r, minf(c.g, c.b))
	var hi := maxf(c.r, maxf(c.g, c.b))
	return lo > FILL_MIN and (hi - lo) < FILL_SPREAD


## Αδειάζει ό,τι επικοινωνεί με το κέντρο χωρίς να περάσει χρωματιστό pixel.
func _hollow(im: Image) -> int:
	var w := im.get_width()
	var h := im.get_height()
	var seen := {}
	var queue := [Vector2i(w / 2, h / 2)]
	var cleared := 0
	while not queue.is_empty():
		var p: Vector2i = queue.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h:
			continue
		if seen.has(p):
			continue
		seen[p] = true
		var c := im.get_pixel(p.x, p.y)
		# ό,τι δεν είναι το λευκό γέμισμα είναι τοίχος: εκεί σταματάει
		if not _is_fill(c):
			continue
		if c.a > 0.0:
			im.set_pixel(p.x, p.y, Color(0, 0, 0, 0))
			cleared += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			queue.append(p + d)
	return cleared


func _initialize() -> void:
	for s in SETS:
		for i in FRAMES:
			var src := "%s/%s_%d.png" % [s["dir"], s["prefix"], PICK[i]]
			var im := Image.load_from_file(src)
			if im == null:
				push_error("λείπει: " + src)
				quit(1)
			im.convert(Image.FORMAT_RGBA8)
			var cleared := _hollow(im)
			var path := "res://art/glow_%s_%d.png" % [s["name"], i + 1]
			var err := im.save_png(ProjectSettings.globalize_path(path))
			if err != OK:
				push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
				quit(1)
			print("  %s — άδειασαν %d pixel" % [path, cleared])
		print("%d καρέ για το σετ '%s'" % [FRAMES, s["name"]])
	quit(0)
