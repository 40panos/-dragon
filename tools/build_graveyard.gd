extends SceneTree
## Περνάει στο art/ τα γραφικά του Graveyard (3η περιοχή) από τα αρχικά του
## PixelLab, που μένουν στο bbdragon-art-proposals/graveyard/raw.
##
##   godot --headless --path . --script tools/build_graveyard.gd
##   godot --headless --path . --script tools/build_floor.gd
##   godot --headless --path . --script tools/build_grave_theme.gd
##   godot --headless --path . --script tools/write_graveyard.gd
##
## Πλακίδια -> art/grave_01..09.png. Ήρθαν σε δύο τόνους: τα ήσυχα (ξερό
## χορτάρι σε μαύρο χώμα) ψυχρά και σκούρα, τα «διηγηματικά» (τάφος, κόκαλα,
## σταυρός, πλάκες) καφέ-κίτρινα και φωτεινά. Εξισώνονται στον μέσο τόνο των
## ήσυχων και χάνουν κορεσμό· αλλιώς το πάτωμα βγαίνει σκακιέρα, όπως είχε
## γίνει με τον πάγο. Τα κόκαλα μένουν φωτεινότερα από το χώμα γύρω τους,
## γιατί η κλίμακα είναι ίδια για όλο το πλακίδιο.
## Για ποικιλία, τα ήσυχα μπαίνουν και καθρεφτισμένα — καθρέφτης, όχι στροφή
## με αναδειγματοληψία, οπότε τα pixel μένουν ίδια.
##
## Εχθροί -> art/<όνομα>.png, <όνομα>_idle_1..N, <όνομα>_hit_1..N. Τα καρέ
## βγήκαν με το animate_image με το τελευταίο καρέ καρφωμένο στο πρώτο, ώστε
## ο βρόχος να κλείνει· το καρφωμένο δεν μπαίνει (θα έδειχνε δύο φορές την
## ίδια στάση). Το raw/anim/<όνομα>_<κατάσταση>_0 είναι το ίδιο το σχέδιο.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/graveyard/raw/"

## όνομα στο art/ -> [αρχείο raw, καθρέφτισμα ("", "h", "v"), εξίσωση τόνου]
const TILES := [
	["grave_01", "tile_a", "", false],
	["grave_02", "tile_a", "h", false],
	["grave_03", "tile_b", "", false],
	["grave_04", "tile_b", "h", false],
	["grave_05", "tile_b", "v", false],
	["grave_06", "tile_path", "", true],    # πλάκες μονοπατιού
	["grave_07", "tile_grave", "", true],   # τάφος με ταφόπλακα — accent
	["grave_08", "tile_bones", "", true],   # κόκαλα και κρανίο — accent
	["grave_09", "tile_cross", "", true],   # πεσμένος σταυρός — accent
]

## εχθρός -> όνομα αρχείου στο raw
const ENEMIES := ["skeleton", "skeleton_warrior", "ghoul", "ghost", "grave_bat", "reaper"]

## Καρέ που μένουν έξω (δείκτες του raw). Στο τελευταίο idle του Skeleton
## Warrior το κράνος σκουραίνει απότομα και ο βρόχος θα τρεμόπαιζε προς το
## μαύρο — ό,τι ακριβώς χάλαγε τον Frost Imp.
const SKIP := {"skeleton_warrior_idle": [7]}


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


func _mean_lum(im: Image) -> float:
	var s := 0.0
	for y in im.get_height():
		for x in im.get_width():
			s += im.get_pixel(x, y).get_luminance()
	return s / float(im.get_width() * im.get_height())


## Φέρνει το πλακίδιο στον τόνο των ήσυχων: ίδια μέση φωτεινότητα, λίγος
## κορεσμός, και απόχρωση προς το ψυχρό γκρι-καφέ του χώματος.
func _match(im: Image, target: float) -> void:
	var k := target / maxf(_mean_lum(im), 0.001)
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var l := clampf(c.get_luminance() * k, 0.0, 1.0)
			var grey := Color(l * 0.98, l * 0.97, l * 1.02)
			var scaled := Color(clampf(c.r * k, 0, 1), clampf(c.g * k, 0, 1), clampf(c.b * k, 0, 1))
			var out := scaled.lerp(grey, 0.62)
			out.a = c.a
			im.set_pixel(x, y, out)


func _initialize() -> void:
	# --- πλακίδια
	var quiet := _load(RAW + "tile_a.png")
	var quiet2 := _load(RAW + "tile_b.png")
	var target := (_mean_lum(quiet) + _mean_lum(quiet2)) * 0.5
	for t in TILES:
		var im := _load(RAW + t[1] + ".png")
		if im.get_width() != 64 or im.get_height() != 64:
			push_error("%s: %s, περίμενα 64x64" % [t[1], im.get_size()])
			quit(1)
			return
		if t[3]:
			_match(im, target)
		if t[2] == "h":
			im.flip_x()
		elif t[2] == "v":
			im.flip_y()
		_save(im, t[0])
	print("πλακίδια: %d (μέσος τόνος %.3f)" % [TILES.size(), target])

	# --- εχθροί
	for e in ENEMIES:
		var base := _load(RAW + e + ".png")
		_save(base, e)
		for state in ["idle", "hit"]:
			# όσα καρέ υπάρχουν, χωρίς το τελευταίο (καρφωμένο = ίδιο με το 0)
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
			for j in frames.size():
				if frames[j].get_size() != base.get_size():
					push_error("%s_%s_%d: %s, περίμενα %s" % [e, state, j, frames[j].get_size(), base.get_size()])
					quit(1)
					return
				_save(frames[j], "%s_%s_%d" % [e, state, j + 1])
			print("%s: %s %d καρέ" % [e, state, frames.size()])
	quit(0)
