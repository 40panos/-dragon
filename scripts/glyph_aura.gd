extends Node2D
## Αύρα από παγωμένες ρούνες γύρω από δράκους με `glyph_aura` (η εξελιγμένη
## μορφή του frost). Δίνει ζωή σε ένα σχέδιο που από μόνο του είναι στατικό:
##   - ρούνες που γεννιούνται γύρω από το κεφάλι, ανεβαίνουν αργά και σβήνουν
##   - παγωμένη σκόνη που αιωρείται γύρω του
##   - στη βολή, έκρηξη από ρούνες προς τα έξω
##
## Οι ρούνες είναι μικρά bitmap 5x5, κάθε pixel τους 2 art pixels (4px οθόνης)
## του παιχνιδιού και πάνω στο πλέγμα των 2px — ίδια πυκνότητα pixel με τον
## ίδιο τον δράκο, χωρίς θόλωμα. Ζει μέσα στο Main (ακολουθεί το shake), πάνω
## από τον δράκο και κάτω από τα εφέ των χτυπημάτων.

const PX := 2.0                  # ένα art pixel στην οθόνη
const MAX_RUNES := 12
const RUNE_PX := 4.0             # ένα pixel της ρούνας = 2 art pixels: αλλιώς δεν διαβάζεται
const MAX_MOTES := 26
const CORE := Color("b8f2ff")
const EDGE := Color("0c1a33")     # σκούρο περίγραμμα: πάνω στο ανοιχτό χιόνι αλλιώς χάνονται
const GLOW := Color("3fb8ff")

## Τα σχήματα: 5 γραμμές των 5, "#" = αναμμένο pixel. Γωνιώδη, σαν χαραγμένα.
const SHAPES := [
	["..#..", ".###.", "#.#.#", "..#..", "..#.."],
	["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
	["###..", "#....", "###..", "..#..", "..###"],
	["..#..", ".#.#.", "#...#", ".#.#.", "..#.."],
	["#.#.#", "#.#.#", "#####", "..#..", "..#.."],
	[".###.", "#...#", "..#..", "#...#", ".###."],
	["#....", "##...", "#.#..", "#..#.", "#####"],
	["..#..", "#.#.#", ".###.", "#.#.#", "..#.."],
]

var m
var _runes: Array = []
var _motes: Array = []
var _spawn := 0.0
var _last_recoil := 0.0


func _active() -> DragonType:
	if m == null:
		return null
	var dg: DragonType = m.active_dragon()
	return dg if dg and dg.glyph_aura else null


## Κέντρο και ακτίνα του κεφαλιού, όπως το ζωγραφίζει το main._draw_dragon.
func _head() -> Array:
	var dg: DragonType = m.active_dragon()
	var tex: Texture2D = dg.frame_for("aim", false, 0.0)
	var w: float = dg.draw_width
	var h := w * float(tex.get_height()) / float(tex.get_width())
	var base: Vector2 = m.dragon_base()
	return [base + Vector2(0, -h * 0.52), w * 0.42]


func _process(delta: float) -> void:
	if m == null or m.frozen_world_paused():
		queue_redraw()
		return
	var dg := _active()
	if dg == null:
		_runes.clear()
		_motes.clear()
		queue_redraw()
		return
	var head: Array = _head()
	var c: Vector2 = head[0]
	var r: float = head[1]

	# ρούνες: μία κάθε ~0.35s, σε τυχαίο σημείο ενός δακτυλίου γύρω από το κεφάλι
	_spawn -= delta
	if _spawn <= 0.0 and _runes.size() < MAX_RUNES:
		_spawn = randf_range(0.22, 0.45)
		var a := randf_range(PI * 1.05, PI * 1.95)       # πάνω μισό, όχι μέσα στο HUD
		_runes.append(_rune(c + Vector2(cos(a), sin(a)) * r * randf_range(0.75, 1.05),
			Vector2(randf_range(-10.0, 10.0), randf_range(-34.0, -18.0)), randf_range(1.4, 2.2)))

	# στη βολή (η κλωτσιά μόλις ανέβηκε): έκρηξη ρουνών προς τα έξω
	var rec: float = m.recoil
	if rec > 0.9 and _last_recoil < 0.9:
		for i in 6:
			var a := randf_range(PI * 1.1, PI * 1.9)
			_runes.append(_rune(c + Vector2(cos(a), sin(a)) * r * 0.4,
				Vector2(cos(a), sin(a)) * randf_range(110.0, 170.0), randf_range(0.45, 0.7)))
	_last_recoil = rec

	while _motes.size() < MAX_MOTES:
		var a := randf() * TAU
		_motes.append({
			"p": c + Vector2(cos(a), sin(a) * 0.7) * r * randf_range(0.3, 1.3),
			"v": Vector2(randf_range(-8.0, 8.0), randf_range(-16.0, -4.0)),
			"life": randf_range(1.0, 2.6), "max": 2.6,
			"size": 2.0 if randf() < 0.7 else 4.0,
		})

	for list in [_runes, _motes]:
		var i: int = list.size() - 1
		while i >= 0:
			var p: Dictionary = list[i]
			p.life -= delta
			if p.life <= 0.0:
				list.remove_at(i)
			else:
				p.p += p.v * delta
				p.v *= 1.0 - minf(delta * 1.2, 0.5)       # φρενάρει, σαν μέσα σε κρύο αέρα
			i -= 1
	queue_redraw()


func _rune(p: Vector2, v: Vector2, life: float) -> Dictionary:
	return {"p": p, "v": v, "life": life, "max": life, "shape": randi() % SHAPES.size()}


func _draw() -> void:
	if _active() == null:
		return
	for d in _motes:
		var f: float = clampf(d.life / d.max, 0.0, 1.0)
		var p: Vector2 = (d.p / PX).floor() * PX
		draw_rect(Rect2(p, Vector2(d.size, d.size)), Color(GLOW, 0.55 * f))
	for d in _runes:
		var f: float = clampf(d.life / d.max, 0.0, 1.0)
		# ανάβει γρήγορα, σβήνει αργά
		var a := minf(1.0, (1.0 - f) * 6.0) * f
		var shape: Array = SHAPES[d.shape]
		var o: Vector2 = ((d.p - Vector2(2.5, 2.5) * RUNE_PX) / PX).floor() * PX
		# τρία περάσματα, ώστε κάθε στρώση να σκεπάζει ολόκληρη την προηγούμενη:
		# σκούρο περίγραμμα, γαλάζια λάμψη, φωτεινός πυρήνας
		for pass_ in 3:
			for y in 5:
				var row: String = shape[y]
				for x in 5:
					if row[x] != "#":
						continue
					var q: Vector2 = o + Vector2(x, y) * RUNE_PX
					match pass_:
						0: draw_rect(Rect2(q - Vector2(PX, PX), Vector2(RUNE_PX + PX * 2.0, RUNE_PX + PX * 2.0)), Color(EDGE, 0.85 * a))
						1: draw_rect(Rect2(q, Vector2(RUNE_PX, RUNE_PX)), Color(GLOW, a))
						2: draw_rect(Rect2(q + Vector2(PX, 0), Vector2(PX, PX)), Color(CORE, a))
