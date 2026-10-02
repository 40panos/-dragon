extends SceneTree
## Χτίζει το φόντο κάθε περιοχής από τα πλακίδιά της:
##   art/background.png        ← art/floor_01..19.png   (Goblin Land)
##   art/background_frost.png  ← art/ice_01..10.png     (Frost Marches)
##   art/background_grave.png  ← art/grave_01..09.png   (Graveyard)
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
		#
		# Το Frost Marches έχει δικό του πλέγμα: 8 στήλες με κελί 72 (βλ.
		# AreaDef.cols), όπου τα 32px σχέδια βγαίνουν ακριβώς x2. Το πλακίδιο
		# του πατώματος γίνεται 36 art pixels (x2 = ένα κελί): ΚΟΜΜΑΤΙ 36x36 από
		# τα 64px πλακίδια, όχι μίκρεμα — τα pixel μένουν ίδια, απλώς δείχνονται
		# στο x2 αντί για το x1.34. Η λακκούβα (06) είναι πλατύτερη από 36 και
		# θα έβγαινε κομμένη στη μέση της, οπότε μένει έξω.
		"prefix": "ice",
		"count": 10,
		"out": "res://art/background_frost.png",
		"seed": 20260926,
		"tile": 36,
		"cols": 8,
		"rows": 14,              # (ui_top - PF_TOP) / 72 = 13.2
		"crop": {
			1: Vector2i(14, 14), 2: Vector2i(14, 14), 3: Vector2i(14, 14), 4: Vector2i(14, 14),
			5: Vector2i(14, 14), 7: Vector2i(4, 4), 8: Vector2i(14, 14),
			9: Vector2i(24, 10),   # το κρανίο, δεξιά στο πλακίδιο
			10: Vector2i(2, 4),    # η ασπίδα, πάνω αριστερά
		},
		"weights": {
			1: 14,    # σκέτο χιόνι — η βάση
			2: 12,    # χιόνι με κυματισμούς από τον αέρα
			3: 10,    # χιόνι με παγωμένες άκρες χόρτου
			4: 3,     # μπαλώματα πάγου
			5: 1,     # ραγισμένος πάγος — σκουραίνει, ελάχιστος
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
]


func _load_tiles(prefix: String, count: int) -> Dictionary:
	var out := {}
	for i in range(1, count + 1):
		var path := "res://art/%s_%02d.png" % [prefix, i]
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
	var tiles := _load_tiles(set_.prefix, set_.count)
	# σετ με δικό του πλέγμα: κομμάτια των πλακιδίων, στο δικό τους μέγεθος
	var tile: int = set_.get("tile", TILE)
	var cols: int = set_.get("cols", COLS)
	var rows: int = set_.get("rows", ROWS)
	var crop: Dictionary = set_.get("crop", {})
	for id in crop:
		tiles[id] = tiles[id].get_region(Rect2i(crop[id], Vector2i(tile, tile)))
	var rng := RandomNumberGenerator.new()
	rng.seed = set_.seed

	var bag: Array[int] = []
	for id in set_.weights:
		for _i in int(set_.weights[id]):
			bag.append(id)

	# πρώτα κληρώνεται όλο το δάπεδο από τα ήσυχα πλακίδια
	var plan := []
	for r in rows:
		var line := []
		for c in cols:
			line.append(bag[rng.randi() % bag.size()])
		plan.append(line)

	# μετά μπαίνουν τα accents, σε ξεχωριστά κελιά και όχι ψηλά στο ταμπλό
	var spots := []
	for r in range(ACCENT_MIN_ROW, rows):
		for c in cols:
			spots.append(Vector2i(c, r))
	var accents: Array = set_.accents
	for i in int(set_.accent_count):
		if spots.is_empty():
			break
		var pick := rng.randi() % spots.size()
		var spot: Vector2i = spots[pick]
		spots.remove_at(pick)
		plan[spot.y][spot.x] = accents[i % accents.size()]

	var sheet := Image.create(cols * tile, rows * tile, false, Image.FORMAT_RGBA8)
	var used := {}
	for r in rows:
		for c in cols:
			var id: int = plan[r][c]
			used[id] = int(used.get(id, 0)) + 1
			sheet.blit_rect(tiles[id], Rect2i(0, 0, tile, tile), Vector2i(c * tile, r * tile))

	var err := sheet.save_png(ProjectSettings.globalize_path(set_.out))
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	var ids := used.keys()
	ids.sort()
	var report := []
	for id in ids:
		report.append("%d:%d" % [id, used[id]])
	print("γράφτηκε %s — %dx%d (%dx%d πλακίδια)"
		% [set_.out, sheet.get_width(), sheet.get_height(), cols, rows])
	print("  χρήση: ", ", ".join(report))


func _initialize() -> void:
	for set_ in SETS:
		_build(set_)
	quit(0)
