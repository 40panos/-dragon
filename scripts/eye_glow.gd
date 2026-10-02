extends Node2D
## Λάμψη στα μάτια για δράκους με `eye_glow` > 0 (ο ψαράς και, πιο δυνατά, η
## εξελιγμένη του μορφή). Ζωγραφίζεται με ΠΡΟΣΘΕΤΙΚΗ μίξη, οπότε πάνω στο
## σκούρο κεφάλι ανάβει πραγματικά αντί να βάφει από πάνω.
##   - στη στόχευση: ήρεμη άλω που πάλλεται
##   - στη βολή: η άλω φουντώνει, ο πυρήνας ασπρίζει, μια οριζόντια λάμψη
##     (flare) ανοίγει δεξιά-αριστερά, και ίχνη φωτός ξεφεύγουν προς τα πάνω
##     και έξω σαν φλόγα — κάθε ριπή τα πετάει με ορμή
## Όλα πάνω στο πλέγμα των 2px (1 art pixel του δράκου στα 2x), για να μένουν
## pixel art. Η θέση των ματιών έρχεται από το DragonType.eye_pos και
## ακολουθεί τη στροφή, την ανάσα και την κλωτσιά μέσω του main.dragon_xform().

const PX := 2.0
const MAX_WISPS := 70

var m
var _wisps: Array = []
var _heat := 0.0          # 0 ήρεμα, ~0.4 στόχευση, 1 στη βολή — ομαλά
var _last_recoil := 0.0


func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat


func _active() -> DragonType:
	if m == null:
		return null
	var dg: DragonType = m.active_dragon()
	return dg if dg and dg.eye_glow > 0.0 else null


## Οι δύο θέσεις των ματιών στην οθόνη (αριστερό, δεξί).
func eyes() -> Array:
	var dg: DragonType = m.active_dragon()
	var size: Vector2 = m.dragon_size()
	var xf: Transform2D = m.dragon_xform()
	# το καρέ που φαίνεται τώρα: στη βολή τα μάτια αλλάζουν θέση ανά καρέ
	var ep := dg.eyes_for(dg.frame_for(m.dragon_phase(), m.aiming, m.t))
	var out := []
	for sx: float in [-1.0, 1.0]:
		out.append(xf * Vector2(sx * size.x * ep.x, -size.y * ep.y))
	return out


func _process(delta: float) -> void:
	if m == null or m.frozen_world_paused():
		queue_redraw()
		return
	var dg := _active()
	if dg == null:
		_wisps.clear()
		_heat = 0.0
		queue_redraw()
		return
	var shooting: bool = m.dragon_phase() == "shoot"
	var want := 1.0 if shooting else (0.42 if m.aiming else 0.0)
	_heat = move_toward(_heat, want, delta * (6.0 if want > _heat else 2.2))

	var ey := eyes()
	var size: Vector2 = m.dragon_size()
	var s: float = dg.eye_glow
	# ίχνη: συνεχώς όσο καίει, και μια ριπή σε κάθε βολή
	var rate := _heat * 34.0 * s
	if randf() < rate * delta and _wisps.size() < MAX_WISPS:
		_spawn(ey, size, s, 1.0)
	var rec: float = m.recoil
	if rec > 0.9 and _last_recoil < 0.9:
		for i in int(6 * s):
			_spawn(ey, size, s, 2.2)
	_last_recoil = rec

	var i := _wisps.size() - 1
	while i >= 0:
		var w: Dictionary = _wisps[i]
		w.life -= delta
		if w.life <= 0.0:
			_wisps.remove_at(i)
		else:
			w.p += w.v * delta
			w.v.y -= 40.0 * delta              # ανεβαίνουν, σαν φλόγα
			w.v.x *= 1.0 - minf(delta * 1.5, 0.5)
		i -= 1
	queue_redraw()


func _spawn(ey: Array, size: Vector2, s: float, boost: float) -> void:
	var side := randi() % 2
	var sx := -1.0 if side == 0 else 1.0
	var p: Vector2 = ey[side] + Vector2(randf_range(-3.0, 3.0), randf_range(-2.0, 2.0))
	_wisps.append({
		"p": p,
		# προς τα έξω και πάνω: από τις άκρες του κεφαλιού, όχι μέσα στο πρόσωπο
		"v": Vector2(sx * randf_range(30.0, 75.0) * boost, randf_range(-50.0, -20.0) * boost),
		"life": randf_range(0.35, 0.7) * (0.8 + s * 0.3), "max": 0.7,
		"size": 4.0 if randf() < 0.35 * s else 2.0,
	})


## Δίσκος στο πλέγμα των 2px.
func _disc(c: Vector2, r: float, col: Color) -> void:
	var n := int(ceil(r / PX))
	var o := (c / PX).floor() * PX
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			if gx * gx + gy * gy > n * n:
				continue
			draw_rect(Rect2(o + Vector2(gx, gy) * PX, Vector2(PX, PX)), col)


func _draw() -> void:
	var dg := _active()
	if dg == null or _heat <= 0.01 and _wisps.is_empty():
		return
	var s: float = dg.eye_glow
	var col: Color = dg.eye_color
	var white := Color(0.85, 1.0, 1.0)
	var size: Vector2 = m.dragon_size()
	var unit: float = size.x / 128.0          # 1 στον μικρό (128 οθόνης), 2 στον μεγάλο
	var pulse := 0.85 + sin(m.t * 7.0) * 0.15
	var h := _heat * pulse * s
	for e: Vector2 in eyes():
		# άλω σε τρεις στρώσεις, από έξω προς τα μέσα
		_disc(e, (10.0 + 8.0 * h) * unit, Color(col, 0.10 * h))
		_disc(e, (6.0 + 5.0 * h) * unit, Color(col, 0.22 * h))
		_disc(e, (3.0 + 2.0 * h) * unit, Color(col, 0.55 * h))
		# πυρήνας: ασπρίζει όσο ανεβαίνει η ένταση
		_disc(e, 2.0 * unit, Color(col.lerp(white, minf(h, 1.0)), 0.9 * minf(h * 1.6, 1.0)))
		# flare: οριζόντια λάμψη μόνο όταν καίει για τα καλά (βολή)
		var fl := clampf((h - 0.45) / 0.55, 0.0, 1.0)
		if fl > 0.0:
			var reach := int((14.0 + 22.0 * fl) * unit / PX)
			var o := (e / PX).floor() * PX
			for k in range(1, reach + 1):
				var a := fl * (1.0 - float(k) / float(reach + 1))
				for sx: float in [-1.0, 1.0]:
					draw_rect(Rect2(o + Vector2(sx * k * PX, 0), Vector2(PX, PX)), Color(col.lerp(white, 0.5), 0.75 * a))
			# μικρή κάθετη, για αστεράκι
			for k in range(1, int(reach * 0.35) + 1):
				var a2 := fl * (1.0 - float(k) / float(reach * 0.35 + 1))
				for sy: float in [-1.0, 1.0]:
					draw_rect(Rect2(o + Vector2(0, sy * k * PX), Vector2(PX, PX)), Color(white, 0.6 * a2))
	for w in _wisps:
		var f: float = clampf(w.life / w.max, 0.0, 1.0)
		var p: Vector2 = (w.p / PX).floor() * PX
		var c := col.lerp(white, f * 0.6)
		draw_rect(Rect2(p, Vector2(w.size, w.size)), Color(c, 0.85 * f))
