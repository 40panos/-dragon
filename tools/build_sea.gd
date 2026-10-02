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


func _dragon() -> void:
	for state in DRAGON:
		var names: Array = DRAGON[state]
		for i in names.size():
			var im := _load(RAW + names[i] + ".png")
			if im.get_size() != Vector2i(64, 64):
				push_error("%s: %s, περίμενα 64x64" % [names[i], im.get_size()])
				quit(1)
				return
			_save(im, "fisher_%s_%d" % [state, i + 1])
	_save(_load(RAW + "harpoon.png"), "harpoon")
	_save(_load(RAW + "hook_aoe.png"), "hook_aoe")
	print("δράκος: %d καταστάσεις, βλήματα harpoon / hook_aoe" % DRAGON.size())


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
