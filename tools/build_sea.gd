extends SceneTree
## Περνάει στο art/ τα γραφικά του Drowned Coast (4η περιοχή) και του δράκου
## ψαρά, από τα αρχικά του PixelLab που μένουν στο bbdragon-art-proposals/sea/raw.
##
##   godot --headless --path . --script tools/build_sea.gd
##   godot --headless --path . --script tools/build_floor.gd
##   godot --headless --path . --script tools/build_frame.gd
##   godot --headless --path . --script tools/build_sea_theme.gd
##   godot --headless --path . --script tools/write_fisher.gd
##   godot --headless --path . --script tools/write_drowned_coast.gd
##
## Πλακίδια -> art/sea_01..10_<καρέ>.png. Κάθε πλακίδιο έχει δικά του καρέ
## κύματος (animate_image με το τελευταίο καρέ καρφωμένο στο πρώτο, οπότε ο
## βρόχος κλείνει). Το build_floor.gd στρώνει το ίδιο σχέδιο δαπέδου μία φορά
## ανά καρέ, και το main τα παίζει σε βρόχο.
## Το νερό ήρθε πολύ φωτεινό και κορεσμένο: πάνω του χάνονταν ο Murkfin και η
## μέδουσα. Όλα τα πλακίδια περνάνε από την ίδια κλίμακα τόνου (ίδια για όλα,
## ώστε να μη βγει σκακιέρα) — μόνο χρώμα, ποτέ αναδειγματοληψία.
##
## Εχθροί -> art/<όνομα>.png, <όνομα>_idle_1..N, <όνομα>_hit_1..N, όπως στο
## build_graveyard.gd: το καρφωμένο τελευταίο καρέ πετιέται.
##
## Δράκος -> art/fisher_<κατάσταση>_1..3.png, από το σχέδιο του χρήστη
## (raw/fisher.png, βγαλμένο από το screenshot στο πλέγμα του) και από
## edit_image_pro_flash πάνω του. Βλήματα: καμάκι και τριπλό αγκίστρι.
## Λάμψη χτυπήματος: τα καρέ του death ξαναβαμμένα σε αφρό θάλασσας.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/sea/raw/"

## όνομα στο art/ -> [αρχείο raw, καθρέφτισμα ("", "h", "v")]
const TILES := [
	["sea_01", "tile_a", ""],
	["sea_02", "tile_a", "h"],
	["sea_03", "tile_b", ""],
	["sea_04", "tile_c", ""],
	["sea_05", "tile_c", "h"],
	["sea_06", "tile_foam", ""],
	["sea_07", "tile_rocks", ""],
	["sea_08", "tile_kelp", ""],
	["sea_09", "tile_wreck", ""],    # accent: συντρίμμια ναυαγίου
	["sea_10", "tile_bones", ""],    # accent: σκελετός ψαριού κάτω από το νερό
]
## Πόσα καρέ κύματος έχει κάθε πλακίδιο (χωρίς το καρφωμένο τελευταίο).
const WAVE_FRAMES := 4

## Κλίμακα τόνου του νερού: φωτεινότητα και κορεσμός.
const WATER_GAIN := 0.74
const WATER_SAT := 0.80

const ENEMIES := ["murkfin", "razorjaw", "shellback", "drift_jelly", "bitefin", "angler"]
## Καρέ που μένουν έξω (δείκτες του raw). Στο 4ο idle της μέδουσας βγήκε μια
## μαύρη κηλίδα πάνω στο κεφάλι — ο βρόχος θα τρεμόπαιζε.
const SKIP := {"drift_jelly_idle": [4]}

## Ο δράκος: κατάσταση -> τα τρία καρέ, με τη σειρά που παίζουν (ping-pong).
const DRAGON := {
	"idle": ["fisher", "fisher_idle_b", "fisher_idle_c"],
	"ready": ["fisher_ready_a", "fisher_ready_b", "fisher_ready_c"],
	"fire": ["fisher_fire_b", "fisher_fire_a", "fisher_fire_c"],
}

## Η εξελιγμένη μορφή (128x128, στα 2x = 256): ο ψαράς που τον κυρίεψε η
## θάλασσα — πτερύγια, λέπια, δόλωμα πεσκαδρίτσας, δόντια ψαριού. Βγήκε με
## edit_image_pro_flash πάνω στο σχέδιό του μεγεθυμένο x2 (raw/evo_d), και τα
## καρέ του με edits πάνω σε αυτό. -> art/fisher_awake_<κατάσταση>_1..3.
## Το idle και των δύο μορφών: ΟΧΙ τρία ανεξάρτητα edits (διέφεραν σε μικρές
## λεπτομέρειες και στο παίξιμο το κεφάλι «γκλιτσάριζε»), αλλά βρόχος από το
## animate_image με πρώτο και τελευταίο καρέ καρφωμένα στο ίδιο σχέδιο
## (raw/anim/<όνομα>_N). Κάθε καρέ περνάει από _stabilize(). -> art/<prefix>_idle_1..N
const IDLE_ANIM := {
	"fisher": ["fisher_idle_anim", "fisher"],
	"fisher_awake": ["evo_idle_anim", "evo_d"],
}
## Πόσο πρέπει να απέχει ένα pixel από το αρχικό για να μετρήσει ως κίνηση
## (άθροισμα διαφορών RGB). Κάτω από αυτό είναι θόρυβος του μοντέλου.
const STILL := 0.22
const IDLE_SKIP := {}

const EVOLVED := {
	"idle": ["evo_d", "evo_idle_b", "evo_idle_c"],
	"ready": ["evo_ready_a", "evo_ready_b", "evo_ready_c"],
	"fire": ["evo_fire_b", "evo_fire_a", "evo_fire_c"],
}


func _load(path: String) -> Image:
	var im := Image.load_from_file(path)
	if im == null:
		push_error("λείπει: " + path)
		quit(1)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name_: String) -> void:
	var dst := "res://art/%s.png" % name_
	im.save_png(ProjectSettings.globalize_path(dst))


func _tone(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var h := c.h
			var s := c.s * WATER_SAT
			var v := c.v * WATER_GAIN
			im.set_pixel(x, y, Color.from_hsv(h, s, v, c.a))


## Τα καρέ κύματος ενός πλακιδίου. Αν δεν υπάρχουν (δεν έχει τρέξει ακόμα το
## animation), μένει ένα: το ίδιο το πλακίδιο, ακίνητο.
func _wave(raw_name: String) -> Array[Image]:
	var out: Array[Image] = []
	var i := 0
	while FileAccess.file_exists(RAW + "anim/%s_wave_%d.png" % [raw_name, i]):
		out.append(_load(RAW + "anim/%s_wave_%d.png" % [raw_name, i]))
		i += 1
	if out.size() > 1:
		out.pop_back()             # καρφωμένο = ίδιο με το 0
	if out.is_empty():
		out.append(_load(RAW + raw_name + ".png"))
	return out


func _tiles() -> void:
	var frames := 0
	for t in TILES:
		var seq := _wave(t[1])
		# όλα τα πλακίδια πρέπει να έχουν όσα καρέ έχει το δάπεδο· όσα έχουν
		# λιγότερα επαναλαμβάνουν τα δικά τους κυκλικά
		for k in WAVE_FRAMES:
			var im: Image = seq[k % seq.size()].duplicate()
			if im.get_width() != 64 or im.get_height() != 64:
				push_error("%s: %s, περίμενα 64x64" % [t[1], im.get_size()])
				quit(1)
				return
			_tone(im)
			if t[2] == "h":
				im.flip_x()
			elif t[2] == "v":
				im.flip_y()
			_save(im, "%s_%d" % [t[0], k + 1])
		frames = maxi(frames, seq.size())
	print("πλακίδια: %d x %d καρέ (το πιο μακρύ raw: %d)" % [TILES.size(), WAVE_FRAMES, frames])


func _enemies() -> void:
	for e in ENEMIES:
		var base := _load(RAW + e + ".png")
		_save(base, e)
		for state in ["idle", "hit"]:
			var frames: Array[Image] = []
			var i := 0
			while FileAccess.file_exists(RAW + "anim/%s_%s_%d.png" % [e, state, i]):
				frames.append(_load(RAW + "anim/%s_%s_%d.png" % [e, state, i]))
				i += 1
			if frames.size() > 1:
				frames.pop_back()
			var skip: Array = SKIP.get("%s_%s" % [e, state], [])
			for k in range(frames.size() - 1, -1, -1):
				if skip.has(k):
					frames.remove_at(k)
			# ό,τι έμεινε από παλιότερο τρέξιμο με περισσότερα καρέ σβήνεται
			var stale := frames.size() + 1
			while FileAccess.file_exists(ProjectSettings.globalize_path("res://art/%s_%s_%d.png" % [e, state, stale])):
				DirAccess.remove_absolute(ProjectSettings.globalize_path("res://art/%s_%s_%d.png" % [e, state, stale]))
				stale += 1
			for j in frames.size():
				if frames[j].get_size() != base.get_size():
					push_error("%s_%s_%d: %s, περίμενα %s" % [e, state, j, frames[j].get_size(), base.get_size()])
					quit(1)
					return
				_save(frames[j], "%s_%s_%d" % [e, state, j + 1])
			print("%s: %s %d καρέ" % [e, state, frames.size()])


func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Σταθεροποιεί ένα καρέ του βρόχου απέναντι στο αρχικό σχέδιο:
##   - pixel που άλλαξαν λίγο (θόρυβος) παίρνουν πίσω ΑΚΡΙΒΩΣ το αρχικό
##   - όσα κινήθηκαν στ' αλήθεια κουμπώνουν στο πιο κοντινό χρώμα της
##     παλέτας του αρχικού, ώστε να μην εμφανίζονται ξένοι τόνοι
##   - η διαφάνεια γίνεται δυαδική, όπως στο αρχικό
func _stabilize(im: Image, base: Image, palette: Array) -> Image:
	var out := base.duplicate()
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var b := base.get_pixel(x, y)
			var on := c.a > 0.5
			if on == (b.a > 0.5) and (not on or _dist(c, b) < STILL):
				continue            # ίδιο με το αρχικό
			if not on:
				out.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var best: Color = palette[0]
			var bd := 99.0
			for p: Color in palette:
				var d := _dist(c, p)
				if d < bd:
					bd = d
					best = p
			out.set_pixel(x, y, best)
	return out


## Το μοντέλο μετακινεί ολόκληρο το κεφάλι 1-2 pixel από καρέ σε καρέ, άλλοτε
## ναι κι άλλοτε όχι — στο παίξιμο αυτό είναι το «γκλίτς». Βρίσκει τη
## μετατόπιση (dx, dy) που ταιριάζει καλύτερα το καρέ πάνω στο αρχικό και το
## γυρίζει πίσω, ώστε να μείνει μόνο η τοπική κίνηση (χάντρες, φτερά, πτερύγια).
## Η ήρεμη ανάσα του κεφαλιού έρχεται από τον κώδικα (main.dragon_xform).
func _align(im: Image, base: Image) -> Image:
	var w := im.get_width()
	var h := im.get_height()
	var best := Vector2i.ZERO
	var best_n := 1 << 30
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var n := 0
			for y in range(0, h, 2):
				for x in range(0, w, 2):
					var sx := x - dx
					var sy := y - dy
					var c := im.get_pixel(sx, sy) if sx >= 0 and sy >= 0 and sx < w and sy < h else Color(0, 0, 0, 0)
					var b := base.get_pixel(x, y)
					if (c.a > 0.5) != (b.a > 0.5) or (b.a > 0.5 and _dist(c, b) > STILL):
						n += 1
			if n < best_n:
				best_n = n
				best = Vector2i(dx, dy)
	if best == Vector2i.ZERO:
		return im
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.blit_rect(im, Rect2i(Vector2i.ZERO, im.get_size()), best)
	return out


func _palette(im: Image) -> Array:
	var seen := {}
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a > 0.5:
				seen[c.to_html(false)] = Color(c, 1.0)
	return seen.values()


## Το idle μιας μορφής από τον βρόχο του animate_image (βλ. IDLE_ANIM).
func _idle_loop(prefix: String, anim: String, base_name: String) -> void:
	var base := _load(RAW + base_name + ".png")
	var pal := _palette(base)
	var frames: Array[Image] = []
	var i := 0
	while FileAccess.file_exists(RAW + "anim/%s_%d.png" % [anim, i]):
		frames.append(_load(RAW + "anim/%s_%d.png" % [anim, i]))
		i += 1
	if frames.size() > 1:
		frames.pop_back()          # καρφωμένο = ίδιο με το 0
	var skip: Array = IDLE_SKIP.get(anim, [])
	var kept := 0
	for k in frames.size():
		if skip.has(k):
			continue
		var im := base if k == 0 else _stabilize(_align(frames[k], base), base, pal)
		kept += 1
		_save(im, "%s_idle_%d" % [prefix, kept])
	# ό,τι περίσσεψε από παλιότερο (μακρύτερο) σετ σβήνεται
	var stale := kept + 1
	while FileAccess.file_exists(ProjectSettings.globalize_path("res://art/%s_idle_%d.png" % [prefix, stale])):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://art/%s_idle_%d.png" % [prefix, stale]))
		DirAccess.remove_absolute(ProjectSettings.globalize_path("res://art/%s_idle_%d.png.import" % [prefix, stale]))
		stale += 1
	print("%s: idle βρόχος %d καρέ" % [prefix, kept])


func _dragon() -> void:
	for state in DRAGON:
		if state == "idle" and FileAccess.file_exists(RAW + "anim/%s_0.png" % IDLE_ANIM["fisher"][0]):
			_idle_loop("fisher", IDLE_ANIM["fisher"][0], IDLE_ANIM["fisher"][1])
			continue
		var names: Array = DRAGON[state]
		for i in names.size():
			var im := _load(RAW + names[i] + ".png")
			if im.get_size() != Vector2i(64, 64):
				push_error("%s: %s, περίμενα 64x64" % [names[i], im.get_size()])
				quit(1)
				return
			_save(im, "fisher_%s_%d" % [state, i + 1])
	for state in EVOLVED:
		if state == "idle" and FileAccess.file_exists(RAW + "anim/%s_0.png" % IDLE_ANIM["fisher_awake"][0]):
			_idle_loop("fisher_awake", IDLE_ANIM["fisher_awake"][0], IDLE_ANIM["fisher_awake"][1])
			continue
		var evo: Array = EVOLVED[state]
		for i in evo.size():
			var im := _load(RAW + evo[i] + ".png")
			if im.get_size() != Vector2i(128, 128):
				push_error("%s: %s, περίμενα 128x128" % [evo[i], im.get_size()])
				quit(1)
				return
			_save(im, "fisher_awake_%s_%d" % [state, i + 1])
	_save(_load(RAW + "harpoon.png"), "harpoon")
	_save(_load(RAW + "hook_aoe.png"), "hook_aoe")
	print("δράκος: %d καταστάσεις (+ εξελιγμένη μορφή), βλήματα harpoon / hook_aoe" % DRAGON.size())


## Η λάμψη του χτυπήματος: τα καρέ του death (πράσινη φλόγα) ξαναβαμμένα σε
## θαλασσί αφρό. Ίδιο σχήμα, μόνο απόχρωση — δεν χρειάζεται νέο generation.
func _glow() -> void:
	for i in range(1, 4):
		var tex: Texture2D = load("res://art/glow_death_%d.png" % i)
		var im := tex.get_image()
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				if c.a <= 0.0 or c.s < 0.15:
					continue
				# πράσινο -> κυανό· οι φωτεινές κορυφές προς το λευκό του αφρού
				var s := c.s * (0.55 if c.v > 0.8 else 0.85)
				im.set_pixel(x, y, Color.from_hsv(0.52, s, c.v, c.a))
		_save(im, "glow_sea_%d" % i)
	print("λάμψη: glow_sea_1..3")


func _initialize() -> void:
	_tiles()
	_enemies()
	_dragon()
	_save(_load(RAW + "wall_sea.png"), "wall_sea")
	_glow()
	quit(0)
