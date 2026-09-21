extends SceneTree
## Χτίζει το art/background.png από τα 19 πλακίδια art/floor_*.png.
##
##   godot --headless --path . --script tools/build_floor.gd
##
## Το δάπεδο είναι ΕΝΑ έτοιμο texture (το main το τεντώνει σε όλο το πεδίο),
## όχι tilemap — οπότε η μίξη αποφασίζεται εδώ, μια φορά, με σταθερό seed
## ώστε το ίδιο τρέξιμο να βγάζει πάντα το ίδιο δάπεδο.
##
## Η λογική της μίξης: το βλέμμα πρέπει να πέφτει στους εχθρούς, όχι στο
## πάτωμα. Άρα ήσυχα πλακίδια παντού, και τα «διηγηματικά» (κρανία, όπλα,
## αίμα) πολύ σπάνια — με σκληρό πλαφόν, γιατί με σκέτο βάρος η τύχη
## μπορεί να τα μαζέψει όλα σε μια γωνιά.

const COLS := 7
const ROWS := 10
const TILE := 64
const OUT := "res://art/background.png"
const SEED := 20260921

# πλακίδιο -> βάρος στην κλήρωση. Το 0 σημαίνει «μόνο ως accent, βλ. παρακάτω».
const WEIGHTS := {
	17: 14,   # σχεδόν σκέτο γρασίδι — αυτό είναι η βάση, όχι τα «γεμάτα»
	18: 12,
	19: 10,
	 1: 3,    # γρασίδι με μπαλώματα χώματος — πλέον παραλλαγή, όχι βάση
	 2: 4,
	 3: 3,
	 4: 2,
	 5: 1,    # λάσπη με πατημασιές — σκουραίνει, ελάχιστη
	 6: 1,
	 7: 1,
	 8: 1,
	 9: 1,    # γρασίδι με βότσαλα
	10: 1,
	11: 3,
	12: 2,
	13: 1,    # χώμα ποτισμένο αίμα
}
# κρανία, τσεκούρια, δόρατα: μετριούνται στο χέρι, όχι στην τύχη
const ACCENTS := [14, 15, 16]
const ACCENT_COUNT := 2
const ACCENT_MIN_ROW := 2      # όχι στις δύο πάνω σειρές, από όπου μπαίνουν οι εχθροί


func _load_tiles() -> Dictionary:
	var out := {}
	for i in range(1, 20):
		var path := "res://art/floor_%02d.png" % i
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει το πλακίδιο: " + path)
			quit(1)
		if tex.get_width() != TILE or tex.get_height() != TILE:
			push_error("%s: %dx%d, περίμενα %dx%d"
				% [path, tex.get_width(), tex.get_height(), TILE, TILE])
			quit(1)
		var im := tex.get_image()
		im.convert(Image.FORMAT_RGBA8)
		out[i] = im
	return out


func _initialize() -> void:
	var tiles := _load_tiles()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED

	var bag: Array[int] = []
	for id in WEIGHTS:
		for _i in int(WEIGHTS[id]):
			bag.append(id)

	# πρώτα κληρώνεται όλο το δάπεδο από τα ήσυχα πλακίδια
	var plan := []
	for r in ROWS:
		var line := []
		for c in COLS:
			line.append(bag[rng.randi() % bag.size()])
		plan.append(line)

	# μετά μπαίνουν τα accents, σε ξεχωριστά κελιά και όχι ψηλά στο ταμπλό
	var spots := []
	for r in range(ACCENT_MIN_ROW, ROWS):
		for c in COLS:
			spots.append(Vector2i(c, r))
	for i in ACCENT_COUNT:
		if spots.is_empty():
			break
		var pick := rng.randi() % spots.size()
		var spot: Vector2i = spots[pick]
		spots.remove_at(pick)
		plan[spot.y][spot.x] = ACCENTS[i % ACCENTS.size()]

	var sheet := Image.create(COLS * TILE, ROWS * TILE, false, Image.FORMAT_RGBA8)
	var used := {}
	for r in ROWS:
		for c in COLS:
			var id: int = plan[r][c]
			used[id] = int(used.get(id, 0)) + 1
			sheet.blit_rect(tiles[id], Rect2i(0, 0, TILE, TILE), Vector2i(c * TILE, r * TILE))

	var err := sheet.save_png(ProjectSettings.globalize_path(OUT))
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	var ids := used.keys()
	ids.sort()
	var report := []
	for id in ids:
		report.append("%d:%d" % [id, used[id]])
	print("γράφτηκε %s — %dx%d (%dx%d πλακίδια)"
		% [OUT, sheet.get_width(), sheet.get_height(), COLS, ROWS])
	print("χρήση: ", ", ".join(report))
	quit(0)
