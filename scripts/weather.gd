extends Node2D
## Καιρός της περιοχής: χιόνι ή ομίχλη. Διαβάζει το `weather` της περιοχής
## (AreaDef): "snow" ρίχνει νιφάδες πάνω από το ταμπλό, "fog" περνάει
## σποραδικά μπαλώματα ομίχλης. Ζει μέσα στο Main με z_index πάνω από τους εχθρούς, κάτω
## από τα εφέ και το HUD, ώστε να ακολουθεί το screen shake όπως όλος ο κόσμος.
##
## Οι νιφάδες είναι τετράγωνα 4x4 και 6x6 — δηλαδή 2 και 3 art pixels στην
## κλίμακα x2 του παιχνιδιού — και οι θέσεις τους πέφτουν στο πλέγμα των 2px,
## ώστε να κάθονται στο ίδιο πλέγμα με το υπόλοιπο pixel art και όχι να
## θολώνουν ανάμεσα σε pixel.

const FLAKES := 150
const GRID := 2.0

## Ομίχλη: λίγα μπαλώματα που εμφανίζονται σποραδικά, περνάνε αργά οριζόντια
## και σβήνουν — όχι σταθερό πέπλο, που θα έκρυβε τους εχθρούς. Τα σχέδιά
## τους φτιάχνονται μία φορά σε art pixels (x2 στην οθόνη), με διαφάνεια σε
## σκαλοπάτια αντί για ομαλή, ώστε να διαβάζονται σαν pixel art.
const FOG_PATCHES := 7
const FOG_SHAPES := 4
const FOG_W := 72              # art pixels
const FOG_H := 22
const FOG_ALPHA := 0.36        # πόσο πυκνό στο φουλ του
const FOG_COLOR := Color(0.72, 0.78, 0.76)

var m
var _flakes: Array = []
var _fog: Array = []
var _active := ""
static var _fog_tex: Array[Texture2D] = []


func _process(delta: float) -> void:
	if m == null:
		return
	# η περιοχή που φαίνεται: στο cinematic αλλάζει μόνο στο μαύρο
	var area = m.visual_area()
	var kind: String = area.weather if area else ""
	if kind != _active:
		_active = kind
		_flakes.clear()
		_fog.clear()
		if kind == "snow":
			for i in FLAKES:
				_flakes.append(_new_flake(true))
		if kind == "fog":
			for i in FOG_PATCHES:
				_fog.append(_new_fog(true))
	if _active == "fog":
		for f in _fog:
			f.t += delta
			f.p.x += f.v * delta
			if f.t >= f.life + f.wait:
				var nf := _new_fog(false)
				for k in nf:
					f[k] = nf[k]
	if _active == "snow":
		var bottom: float = m.ui_top
		for f in _flakes:
			f.t += delta
			f.p.y += f.v * delta
			f.p.x += sin(f.t * f.sway_f + f.phase) * f.sway * delta
			if f.p.y > bottom:
				var n := _new_flake(false)
				f.p = n.p
				f.v = n.v
	queue_redraw()


## Τα σχήματα της ομίχλης: θολή έλλειψη με «μπουκλωτές» άκρες από θόρυβο,
## κβαντισμένη σε 4 επίπεδα διαφάνειας. Σταθερό seed: ίδια σχήματα πάντα.
static func fog_textures() -> Array[Texture2D]:
	if not _fog_tex.is_empty():
		return _fog_tex
	var noise := FastNoiseLite.new()
	noise.seed = 1928
	noise.frequency = 0.09
	for s in FOG_SHAPES:
		var img := Image.create(FOG_W, FOG_H, false, Image.FORMAT_RGBA8)
		for y in FOG_H:
			for x in FOG_W:
				var dx := (float(x) - FOG_W * 0.5) / (FOG_W * 0.5)
				var dy := (float(y) - FOG_H * 0.5) / (FOG_H * 0.5)
				var d := sqrt(dx * dx + dy * dy)
				var n := noise.get_noise_2d(x + s * 97.0, y * 1.6 + s * 31.0) * 0.45
				var v := clampf(1.0 - d + n, 0.0, 1.0)
				var q := floorf(v * 4.0) / 3.0          # 0, 1/3, 2/3, 1
				img.set_pixel(x, y, Color(1, 1, 1, clampf(q, 0.0, 1.0)))
		_fog_tex.append(ImageTexture.create_from_image(img))
	return _fog_tex


## Ένα μπάλωμα ομίχλης. Ζει `life` δευτερόλεπτα (σβήνει-ανάβει στις άκρες)
## και μετά περιμένει `wait` αόρατο — από εκεί βγαίνει το «σποραδικό».
func _new_fog(anywhere: bool) -> Dictionary:
	var top: float = m.PF_TOP
	var bottom: float = m.floor_y
	var v := randf_range(10.0, 24.0) * (1.0 if randf() < 0.5 else -1.0)
	var life := randf_range(7.0, 13.0)
	return {
		"p": Vector2(randf_range(m.pf_left - 80.0, m.pf_right - 60.0), randf_range(top, bottom - 40.0)),
		"v": v,
		"shape": randi() % FOG_SHAPES,
		"scale": 2.0 if randf() < 0.6 else 3.0,
		"life": life,
		"wait": randf_range(0.5, 5.0),
		"t": randf_range(0.0, life) if anywhere else 0.0,
		"flip": randf() < 0.5,
	}


func _draw_fog() -> void:
	var tex := fog_textures()
	for f in _fog:
		if f.t >= f.life:
			continue
		# σβήσιμο-άναμμα στο πρώτο και στο τελευταίο τρίτο της ζωής του
		var edge: float = f.life / 3.0
		var a: float = minf(f.t / edge, (f.life - f.t) / edge)
		a = clampf(a, 0.0, 1.0) * FOG_ALPHA
		var s: float = f.scale
		var size := Vector2(FOG_W * s, FOG_H * s)
		var p := Vector2(floorf(f.p.x / GRID) * GRID, floorf(f.p.y / GRID) * GRID)
		if f.flip:
			# καθρέφτισμα με αρνητικό πλάτος — όχι με το 5ο όρισμα (transpose)
			draw_texture_rect(tex[f.shape], Rect2(p.x + size.x, p.y, -size.x, size.y), false,
				Color(FOG_COLOR, a))
		else:
			draw_texture_rect(tex[f.shape], Rect2(p, size), false, Color(FOG_COLOR, a))


## Μια νιφάδα. Όσες είναι μεγάλες πέφτουν πιο γρήγορα και φωτεινότερες, ώστε
## να δίνουν βάθος: κοντινές μπροστά, μακρινές αχνές και αργές.
func _new_flake(anywhere: bool) -> Dictionary:
	var big := randf() < 0.3
	var top: float = m.PF_TOP - 36.0
	var y := randf_range(top, m.ui_top) if anywhere else top - randf_range(0.0, 60.0)
	return {
		"p": Vector2(randf_range(0.0, m.W), y),
		"v": randf_range(46.0, 70.0) if big else randf_range(22.0, 40.0),
		"size": 6.0 if big else 4.0,
		"a": randf_range(0.75, 0.95) if big else randf_range(0.45, 0.7),
		"sway": randf_range(8.0, 22.0),
		"sway_f": randf_range(0.6, 1.4),
		"phase": randf() * TAU,
		"t": 0.0,
	}


func _draw() -> void:
	if _active == "fog":
		_draw_fog()
		return
	if _active != "snow":
		return
	var top: float = m.PF_TOP - 36.0
	for f in _flakes:
		if f.p.y < top:
			continue
		var p := Vector2(floorf(f.p.x / GRID) * GRID, floorf(f.p.y / GRID) * GRID)
		draw_rect(Rect2(p, Vector2(f.size, f.size)), Color(0.93, 0.97, 1.0, f.a))
