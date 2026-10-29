extends SceneTree
## Χτίζει το φόντο κάθε περιοχής από τα πλακίδιά της:
##   art/background.png        ← art/floor_01..19.png   (Goblin Land)
##   art/background_frost.png  ← art/ice_01..10.png     (Frost Marches)
##   art/background_grave.png  ← art/grave_01..09.png   (Graveyard)
##   art/background_sea_1..4.png ← art/sea_01..10_1..4.png (Drowned Coast, κυματίζει)
##
##   godot --headless --path . --script tools/build_floor.gd
##
## Το δάπεδο είναι ΕΝΑ έτοιμο texture (το main το τεντώνει σε όλο το πεδίο),
## όχι tilemap — οπότε η μίξη αποφασίζεται εδώ, μια φορά, με σταθερό seed
## ώστε το ίδιο τρέξιμο να βγάζει πάντα το ίδιο δάπεδο. Ποιο φόντο παίρνει
## κάθε περιοχή το λέει το `background` της (βλ. tools/write_frost_marches.gd).
##
## Η λογική της μίξης: το βλέμμα πρέπει να πέφτει στους εχθρούς, όχι στο
## πάτωμα. Άρα ήσυχα πλακίδια παντού, και τα «διηγηματικά» (κρανία, όπλα,
## αίμα) πολύ σπάνια — με σκληρό πλαφόν, γιατί με σκέτο βάρος η τύχη
## μπορεί να τα μαζέψει όλα σε μια γωνιά.

const COLS := 7
## Αρκετές σειρές ώστε το φόντο να φτάνει ως το HUD με ΤΕΤΡΑΓΩΝΑ πλακίδια.
## Το main το στρώνει με μονάδα το κελί (85.7 οθόνη), οπότε χρειάζεται
## (ui_top - PF_TOP) / cell = 11.1 σειρές· οι 12 το καλύπτουν με περίσσευμα
## που κρύβεται πίσω από το HUD. Με 10 σειρές το φόντο τεντωνόταν κάθετα
## και οι ραφές του ξέφευγαν από το πλέγμα.
const ROWS := 12
const TILE := 64
const ACCENT_MIN_ROW := 2      # όχι στις δύο πάνω σειρές, από όπου μπαίνουν οι εχθροί

## Ένα σετ ανά περιοχή. `weights`: πλακίδιο -> βάρος στην κλήρωση των ήσυχων.
## `accents`: κρανία, όπλα κ.λπ. — μετριούνται στο χέρι, όχι στην τύχη.
const SETS := [
	{
		"prefix": "floor",
		"count": 19,
		"out": "res://art/background.png",
		"seed": 20260921,
		"weights": {
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
		},
		"accents": [14, 15, 16],
		"accent_count": 2,
	},
	{
		# Χιόνι ΣΤΗ ΣΚΙΑ, γκρι-μπλε και μεσαίας φωτεινότητας, όχι λαμπερό
		# λευκό: πάνω σε λευκό θα χάνονταν οι λύκοι και ο Yeti.
		# Τα χιονισμένα πλακίδια (όλα εκτός από τον σκούρο πάγο και τα
		# accents) έχουν εξισωμένο μέσο τόνο: όπως ήρθαν από το PixelLab, το
		# ένα ήταν γαλάζιο κι ανοιχτό, το άλλο γκρι και σκούρο, και το πάτωμα
		# έβγαινε σκακιέρα. Τα αρχικά είναι στο bbdragon-art-proposals/ice/tiles_raw.
		"prefix": "ice",
		"count": 10,
		"out": "res://art/background_frost.png",
		"seed": 20260926,
		"weights": {
			1: 14,    # σκέτο χιόνι — η βάση
			2: 12,    # χιόνι με κυματισμούς από τον αέρα
			3: 10,    # χιόνι με παγωμένες άκρες χόρτου
			4: 3,     # μπαλώματα πάγου
			5: 1,     # ραγισμένος πάγος — σκουραίνει, ελάχιστος
			6: 1,     # παγωμένη λακκούβα — τραβάει το μάτι, ελάχιστη
			7: 3,     # πέτρες με χιόνι
			8: 2,     # ίχνη λύκου
		},
		"accents": [9, 10],   # κόκαλα στο χιόνι, ασπίδα Viking στον πάγο
		"accent_count": 2,
	},
	{
		# Graveyard: μαύρο χώμα με ξερό χορτάρι. Τα πλακίδια περνάνε από το
		# tools/build_graveyard.gd, που εξισώνει τον τόνο τους· 02, 04, 05
		# είναι καθρεφτίσματα των ήσυχων, για ποικιλία.
		"prefix": "grave",
		"count": 9,
		"out": "res://art/background_grave.png",
		"seed": 20260928,
		"weights": {
			1: 12,    # ξερό χορτάρι σε μαύρο χώμα — η βάση
			2: 12,
			3: 9,     # χώμα με βότσαλα
			4: 9,
			5: 6,
			6: 2,     # πλάκες μονοπατιού — σπάνιες, τραβάνε το μάτι
		},
		"accents": [7, 8, 9],   # τάφος, κόκαλα με κρανίο, πεσμένος σταυρός
		"accent_count": 3,
	},
	{
		# Drowned Coast: σκούρα θάλασσα που κυματίζει. Κάθε πλακίδιο έχει
		# `frames` καρέ (art/sea_NN_<καρέ>.png, από το tools/build_sea.gd)· το
		# ΙΔΙΟ σχέδιο δαπέδου στρώνεται μία φορά ανά καρέ, οπότε βγαίνουν τα
		# background_sea_1..N και κάθε κελί κυματίζει στη θέση του.
		"prefix": "sea",
		"count": 10,
		"frames": 4,
		"out": "res://art/background_sea.png",
		"seed": 20261003,
		"weights": {
			1: 12,    # ήρεμο νερό — η βάση
			2: 10,
			3: 10,    # νερό με διαγώνια κύματα
			4: 8,     # βαθύ, σκουρότερο νερό
			5: 8,
			6: 3,     # λωρίδες αφρού
			7: 2,     # βράχια με αφρό — τραβάνε το μάτι, σπάνια
			8: 2,     # φύκια
		},
		"accents": [9, 10],   # συντρίμμια ναυαγίου, σκελετός ψαριού
		"accent_count": 2,
	},
]


## `frame` > 0: το καρέ κύματος του πλακιδίου (<prefix>_NN_<frame>.png).
func _load_tiles(prefix: String, count: int, frame := 0) -> Dictionary:
	var out := {}
	for i in range(1, count + 1):
		var path := "res://art/%s_%02d.png" % [prefix, i]
		if frame > 0:
			path = "res://art/%s_%02d_%d.png" % [prefix, i, frame]
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


func _build(set_: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = set_.seed

	var bag: Array[int] = []
	for id in set_.weights:
		for _i in int(set_.weights[id]):
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
	var accents: Array = set_.accents
	for i in int(set_.accent_count):
		if spots.is_empty():
			break
		var pick := rng.randi() % spots.size()
		var spot: Vector2i = spots[pick]
		spots.remove_at(pick)
		plan[spot.y][spot.x] = accents[i % accents.size()]

	# στατικό δάπεδο: ένα φύλλο. Κινούμενο: ένα ανά καρέ, με το ίδιο σχέδιο,
	# και το πρώτο γράφεται και ως σκέτο `out` (εφεδρεία, εικονίδια)
	var frames := int(set_.get("frames", 0))
	var used := {}
	for f in range(0, maxi(frames, 1)):
		var frame := f + 1 if frames > 0 else 0
		var tiles := _load_tiles(set_.prefix, set_.count, frame)
		var sheet := Image.create(COLS * TILE, ROWS * TILE, false, Image.FORMAT_RGBA8)
		for r in ROWS:
			for c in COLS:
				var id: int = plan[r][c]
				if f == 0:
					used[id] = int(used.get(id, 0)) + 1
				sheet.blit_rect(tiles[id], Rect2i(0, 0, TILE, TILE), Vector2i(c * TILE, r * TILE))
		var outs: Array[String] = [set_.out]
		if frames > 0:
			outs.clear()
			outs.append(String(set_.out).replace(".png", "_%d.png" % frame))
			if f == 0:
				outs.append(set_.out)
		for o in outs:
			var err := sheet.save_png(ProjectSettings.globalize_path(o))
			if err != OK:
				push_error("η αποθήκευση απέτυχε: %d" % err)
				quit(1)
			print("γράφτηκε %s — %dx%d (%dx%d πλακίδια)"
				% [o, sheet.get_width(), sheet.get_height(), COLS, ROWS])
	var ids := used.keys()
	ids.sort()
	var report := []
	for id in ids:
		report.append("%d:%d" % [id, used[id]])
	print("  χρήση: ", ", ".join(report))


func _initialize() -> void:
	for set_ in SETS:
		_build(set_)
	quit(0)
