extends Node2D
## Η εμφάνιση του δράκου — καρέ, ανάσα, στροφή κεφαλιού, κλωτσιά, λάμψη στόματος.
##
## Το main κρατάει μόνο τη λογική του παιχνιδιού και εκθέτει την κατάσταση που
## διαβάζει αυτός ο κόμβος. Κάθε αλλαγή στην εμφάνιση του δράκου γίνεται εδώ.

var m: Game

var tilt := 0.0            # στροφή προς τη στόχευση, με εξομάλυνση
var recoil := 0.0          # κλωτσιά όταν φεύγει μπάλα, σβήνει γρήγορα


func _process(delta: float) -> void:
	if m == null or m.paused:
		return
	recoil = maxf(0.0, recoil - delta * 5.5)

	var want := 0.0
	if m.phase == "aim" and m.aiming:
		want = clampf(m.aim_dir.x, -1.0, 1.0) * 0.30
	elif m.phase == "shoot":
		want = clampf(m.aim_dir.x, -1.0, 1.0) * 0.20
	tilt = lerpf(tilt, want, clampf(delta * 9.0, 0.0, 1.0))

	queue_redraw()


## Το main το καλεί τη στιγμή που φεύγει μπάλα.
func kick() -> void:
	recoil = 1.0


## Ύψος σχεδίασης του τρέχοντος καρέ — ώστε στόμα και εικόνα να συμφωνούν.
func draw_height() -> float:
	if m == null or m.dragon == null:
		return 60.0
	var tex := m.dragon.frame_for(m.phase, m.aiming, m.t)
	if tex == null:
		return 60.0
	return m.dragon.draw_width * float(tex.get_height()) / float(tex.get_width())


## Από εδώ βγαίνει η φωτιά, ακολουθώντας τη στροφή του κεφαλιού.
func mouth_pos() -> Vector2:
	if m == null:
		return Vector2.ZERO
	return Vector2(m.launch_x, m.floor_y) + Vector2(0, -draw_height() * 0.45).rotated(tilt)


func _draw() -> void:
	if m == null:
		return
	var base := Vector2(m.launch_x, m.floor_y)
	var tex: Texture2D = m.dragon.frame_for(m.phase, m.aiming, m.t) if m.dragon else null

	if tex == null:
		_draw_placeholder(base)
		return

	var w: float = m.dragon.draw_width
	var h := draw_height()

	var bob := 0.0
	var breathe := 1.0
	if m.phase == "aim" and not m.aiming:
		bob = sin(m.t * 2.1) * 2.5                      # ήρεμη ανάσα
		breathe = 1.0 + sin(m.t * 2.1) * 0.018
	elif m.phase == "aim" and m.aiming:
		bob = 3.0 + sin(m.t * 26.0) * 0.9               # τρέμουλο έντασης

	var kick_off: Vector2 = -m.aim_dir * recoil * 9.0
	var pivot: Vector2 = base + Vector2(0, bob) + kick_off

	draw_set_transform(pivot, tilt, Vector2(1.0, breathe))
	draw_texture_rect(tex, Rect2(-w * 0.5, -h, w, h), false, m.dragon.tint)
	if recoil > 0.05:
		var g := recoil
		draw_circle(Vector2(0, -h * 0.45), 26.0 * g, Color(1.0, 0.62, 0.18, 0.30 * g))
		draw_circle(Vector2(0, -h * 0.45), 12.0 * g, Color(1.0, 0.92, 0.70, 0.55 * g))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Εφεδρικός δράκος με pixel, όταν δεν υπάρχει καθόλου γραφικό.
func _draw_placeholder(base: Vector2) -> void:
	var px := 7.0
	var map := [
		"......RR....", ".WW..RRRR...", ".WWW.RRERR..", ".WWWWRRRRRR.",
		"..WWRRRRRR..", "...RRRRRR...", "..T.RR.RR...", "....RR.RR..."
	]
	var o := base + Vector2(-map[0].length() * px * 0.5, -map.size() * px)
	for r in map.size():
		var line: String = map[r]
		for c in line.length():
			var ch := line[c]
			if ch == ".":
				continue
			var col := Color("d4453a")
			if ch == "W":
				col = Color("a33028")
			elif ch == "E":
				col = Color.WHITE
			elif ch == "T":
				col = Color("8e2a22")
			draw_rect(Rect2(o + Vector2(c * px, r * px), Vector2(px, px)), col)
