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
const FOG_PATCHES := 12
const FOG_SHAPES := 4
const FOG_W := 72              # art pixels
const FOG_H := 22
const FOG_ALPHA := 0.46        # πόσο πυκνό στο φουλ του
const FOG_COLOR := Color(0.72, 0.78, 0.76)

## Χιονοθύελλα (ο Wendigo παγωμένος): πάνω από τον καιρό της περιοχής, πυκνό
## χιόνι που το παίρνει ο αέρας, ομίχλη παντού και ένα λευκό πέπλο. Ανεβαίνει
## και πέφτει ομαλά (storm 0..1), ώστε να «έρχεται» και να «περνάει».
const STORM_FLAKES := 260
const STORM_FOG := 16
const STORM_WIND := 150.0       # px/s οριζόντια, στο φουλ της θύελλας
const STORM_RISE := 1.6         # δευτερόλεπτα ως το φουλ (και ως το τέλος)
const STORM_VEIL := 0.16

var m
var _flakes: Array = []
var _fog: Array = []
var _active := ""
var storm := 0.0
var _storm_want := 0.0
var _storm_flakes: Array = []
var _storm_fog: Array = []
static var _fog_tex: Array[Texture2D] = []


## `now`: χωρίς ομαλή μετάβαση (άλμα του TEST menu, αλλαγή περιοχής).
func set_storm(on: bool, now := false) -> void:
	_storm_want = 1.0 if on else 0.0
	if now:
		storm = _storm_want
	if on and _storm_flakes.is_empty():
		for i in STORM_FLAKES:
			var f := _new_flake(true)
			f.v *= 2.2
			_storm_flakes.append(f)
		for i in STORM_FOG:
			var g := _new_fog(true)
			g.wait = randf_range(0.0, 0.5)
			_storm_fog.append(g)


func _update_storm(delta: float) -> void:
	storm = move_toward(storm, _storm_want, delta / STORM_RISE)
	if storm <= 0.0 and _storm_want <= 0.0:
		_storm_flakes.clear()
		_storm_fog.clear()
		return
	var bottom: float = m.ui_top
	for f in _storm_flakes:
		f.t += delta
		f.p.y += f.v * delta
		f.p.x += (STORM_WIND * storm + sin(f.t * f.sway_f + f.phase) * f.sway) * delta
		if f.p.y > bottom or f.p.x > m.W + 10.0:
			var n := _new_flake(false)
			f.p = n.p
			# ο αέρας τις φέρνει από αριστερά: ξαναμπαίνουν και από την άκρη
			if randf() < 0.4:
				f.p = Vector2(-10.0, randf_range(m.PF_TOP - 36.0, bottom))
	for g in _storm_fog:
		g.t += delta
		g.p.x += (absf(g.v) + 40.0 * storm) * delta
		if g.t >= g.life + g.wait:
			var ng := _new_fog(false)
			ng.wait = randf_range(0.0, 0.5)
			for k in ng:
				g[k] = ng[k]


func _process(delta: float) -> void:
	if m == null:
		return
	if storm > 0.0 or _storm_want > 0.0:
		_update_storm(delta)
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
	var scale := 3.0 if randf() < 0.6 else 4.0
	var w := FOG_W * scale
	# γεννιέται μέσα στο ταμπλό (μπορεί να ξεχειλίζει λίγο), όχι πάνω στο
	# πλαίσιο — εκεί χανόταν και η ομίχλη έμοιαζε αραιή
	var x0: float = m.pf_left - w * 0.25
	var x1: float = maxf(x0, m.pf_right - w * 0.75)
	return {
		"p": Vector2(randf_range(x0, x1), randf_range(top, bottom - 40.0)),
		"v": v,
		"shape": randi() % FOG_SHAPES,
		"scale": scale,
		"life": life,
		"wait": randf_range(0.3, 2.5),
		"t": randf_range(0.0, life) if anywhere else 0.0,
		"flip": randf() < 0.5,
	}


## `crop`: μόνο το κομμάτι που πέφτει μέσα στην πίστα. Η θύελλα το θέλει —
## αλλιώς τα μπαλώματα απλώνονταν πάνω στους τοίχους και στο σκοτάδι γύρω.
func _draw_fog(list: Array, strength: float, crop := false) -> void:
	var tex := fog_textures()
	var field := Rect2(m.pf_left, m.PF_TOP - 36.0, m.PF_W, m.ui_top - m.PF_TOP + 36.0)
	for f in list:
		if f.t >= f.life:
			continue
		# σβήσιμο-άναμμα στο πρώτο και στο τελευταίο τρίτο της ζωής του
		var edge: float = f.life / 3.0
		var a: float = minf(f.t / edge, (f.life - f.t) / edge)
		a = clampf(a, 0.0, 1.0) * FOG_ALPHA * strength
		var s: float = f.scale
		var size := Vector2(FOG_W * s, FOG_H * s)
		var p := Vector2(floorf(f.p.x / GRID) * GRID, floorf(f.p.y / GRID) * GRID)
		if crop:
			var dst := Rect2(p, size)
			var inter := dst.intersection(field)
			if not inter.has_area():
				continue
			# η περιοχή της υφής, σε ακέραια art pixels ώστε να μένει στο πλέγμα
			# (στρογγυλεμένα προς τα μέσα: ποτέ ούτε ένα pixel έξω από την πίστα)
			var sx := ceilf((inter.position.x - dst.position.x) / s)
			var sx2 := floorf((inter.end.x - dst.position.x) / s)
			var sy := ceilf((inter.position.y - dst.position.y) / s)
			var sy2 := floorf((inter.end.y - dst.position.y) / s)
			if sx2 <= sx or sy2 <= sy:
				continue
			var src := Rect2(sx, sy, sx2 - sx, sy2 - sy)
			var out := Rect2(dst.position + src.position * s, src.size * s)
			if f.flip:
				# Το draw_texture_rect_region ΔΕΝ καθρεφτίζει με αρνητικό πλάτος (το
				# κανονικοποιεί και το μετατοπίζει έξω από την πίστα): καθρέφτισμα
				# με μετασχηματισμό γύρω από τη μέση του κομματιού, και η περιοχή της
				# υφής από την απέναντι μεριά
				src.position.x = FOG_W - src.end.x
				var cx := out.get_center().x
				draw_set_transform(Vector2(cx * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
				draw_texture_rect_region(tex[f.shape], out, src, Color(FOG_COLOR, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				draw_texture_rect_region(tex[f.shape], out, src, Color(FOG_COLOR, a))
			continue
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
		_draw_fog(_fog, 1.0)
	elif _active == "snow":
		_draw_flakes(_flakes, 1.0)
	if storm > 0.0:
		# λευκό πέπλο σε όλη την πίστα, ομίχλη, και το χιόνι της θύελλας από πάνω
		draw_rect(Rect2(m.pf_left, m.PF_TOP - 36.0, m.PF_W, m.ui_top - m.PF_TOP + 36.0),
			Color(0.86, 0.93, 1.0, STORM_VEIL * storm))
		_draw_fog(_storm_fog, 1.3 * storm, true)
		_draw_flakes(_storm_flakes, storm)


func _draw_flakes(list: Array, strength: float) -> void:
	var top: float = m.PF_TOP - 36.0
	for f in list:
		if f.p.y < top:
			continue
		var p := Vector2(floorf(f.p.x / GRID) * GRID, floorf(f.p.y / GRID) * GRID)
		draw_rect(Rect2(p, Vector2(f.size, f.size)), Color(0.93, 0.97, 1.0, f.a * strength))
