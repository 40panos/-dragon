extends SceneTree
## Περνάει στο art/ τα γραφικά του μεγάλου boss του Goblin Land (Grukk's
## Siege Tower) και ό,τι ρίχνει. Τα αρχικά του PixelLab μένουν στο
## bbdragon-art-proposals/siege/raw.
##
##   godot --headless --path . --script tools/build_siege.gd
##   godot --headless --path . --script tools/write_siege.gd
##
## Καρέ: τα animate_image βγήκαν με το τελευταίο καρέ καρφωμένο στο πρώτο
## (ο βρόχος κλείνει)· το καρφωμένο δεν μπαίνει. Η έκρηξη δεν είναι βρόχος:
## ξεκινάει από τον πυρήνα της (το κέντρο του σχεδίου, κομμένο — όχι
## μικραμένο), σκάει ολόκληρη και διαλύεται σε καπνό (anim/explosion_1..6).

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/siege/raw/"

## όνομα στο art/ -> [σχέδιο raw, {κατάσταση: πρόθεμα raw/anim}]
const SPRITES := {
	"siege_tower": ["tower", {"idle": "tower_idle", "hit": "tower_hit", "throw": "tower_throw"}],
	"war_drummer": ["drummer", {"idle": "war_drummer_idle", "hit": "war_drummer_hit"}],
	"powder_keg": ["powder_keg", {"idle": "powder_keg_idle"}],
	"barricade": ["barricade", {}],
	"spawn_barrel": ["spawn_barrel", {}],
	"boulder": ["boulder", {}],
}
## Καρέ που μένουν έξω: στο 2ο idle του τυμπανιστή το κεφάλι μαυρίζει.
const SKIP := {"war_drummer_idle": [1]}


func _load(path: String) -> Image:
	var im := Image.load_from_file(path)
	if im == null:
		push_error("λείπει: " + path)
		quit(1)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name_: String) -> void:
	im.save_png(ProjectSettings.globalize_path("res://art/%s.png" % name_))


func _initialize() -> void:
	for name_ in SPRITES:
		var spec: Array = SPRITES[name_]
		var base := _load(RAW + spec[0] + ".png")
		_save(base, name_)
		var states: Dictionary = spec[1]
		for state in states:
			var prefix: String = states[state]
			var frames: Array[Image] = []
			var i := 0
			while FileAccess.file_exists(RAW + "anim/%s_%d.png" % [prefix, i]):
				frames.append(_load(RAW + "anim/%s_%d.png" % [prefix, i]))
				i += 1
			if frames.size() > 1:
				frames.pop_back()          # το καρφωμένο τελευταίο = το πρώτο
			var skip: Array = SKIP.get(prefix, [])
			var n := 1
			for k in frames.size():
				if skip.has(k):
					continue
				if frames[k].get_size() != base.get_size():
					push_error("%s_%d: %s, περίμενα %s" % [prefix, k, frames[k].get_size(), base.get_size()])
					quit(1)
					return
				_save(frames[k], "%s_%s_%d" % [name_, state, n])
				n += 1
			print("%s: %s %d καρέ" % [name_, state, n - 1])

	# έκρηξη: πυρήνας -> ολόκληρη -> καπνός
	var full := _load(RAW + "explosion.png")
	var out: Array[Image] = []
	# πυρήνας: μόνο όσα pixel πέφτουν μέσα σε κύκλο γύρω από το κέντρο —
	# τετράγωνο κόψιμο έβγαζε κουτί με κοφτές γωνίες
	var cx := full.get_width() * 0.5
	var cy := full.get_height() * 0.5
	for keep: float in [0.22, 0.45]:
		var core := Image.create(full.get_width(), full.get_height(), false, Image.FORMAT_RGBA8)
		var rad := full.get_width() * 0.5 * keep
		for y in full.get_height():
			for x in full.get_width():
				if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= rad:
					core.set_pixel(x, y, full.get_pixel(x, y))
		out.append(core)
	var j := 0
	while FileAccess.file_exists(RAW + "anim/explosion_%d.png" % j):
		out.append(_load(RAW + "anim/explosion_%d.png" % j))
		j += 1
	if j == 0:
		out.append(full)
	for k in out.size():
		_save(out[k], "explosion_%d" % (k + 1))
	print("explosion: %d καρέ" % out.size())
	quit(0)
