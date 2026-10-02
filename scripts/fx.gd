extends Node2D
## Σπίθες, λάμψεις, ό,τι πετάει ο boss και οι εκρήξεις. Ζει σε ψηλό z_index
## ώστε να σχεδιάζεται πάνω από τους εχθρούς, αλλά μέσα στο Main ώστε να
## ακολουθεί το screen shake.

var m


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if m == null:
		return
	_draw_tethers()
	_draw_lobs()
	_draw_explosions()
	_draw_heal()
	_draw_glare()
	# υφή αντί για draw_circle: ίδια εικόνα, αλλά μπαίνει σε batch (βλ. ball.gd)
	var dot := Ball.dot_tex()
	for s in m.sparks:
		var f: float = clampf(s["life"] / s["max"], 0.0, 1.0)
		var c: Color = s["c"]
		var p: Vector2 = s["p"]
		# λαμπερός πυρήνας με απαλό φωτοστέφανο
		var halo: float = s["r"] * f * 2.2
		var core: float = s["r"] * f
		draw_texture_rect(dot, Rect2(p.x - halo, p.y - halo, halo * 2.0, halo * 2.0), false,
			Color(c.r, c.g, c.b, f * 0.18))
		draw_texture_rect(dot, Rect2(p.x - core, p.y - core, core * 2.0, core * 2.0), false,
			Color(c.r, c.g, c.b, f))


## Βλήματα σε καμπύλη: σκιά στο έδαφος που μεγαλώνει καθώς πλησιάζει, και
## το αντικείμενο να στριφογυρίζει. Η σκιά λέει στον παίκτη πού θα πέσει.
func _draw_lobs() -> void:
	var dot := Ball.dot_tex()
	for l in m.lobs:
		if l.get("hidden", false):
			continue
		var k: float = clampf(l.t / l.dur, 0.0, 1.0)
		var ground: Vector2 = (l.from as Vector2).lerp(l.to, k)
		var p: Vector2 = m.lob_pos(l)
		var sw := lerpf(10.0, 30.0, k)
		draw_texture_rect(dot, Rect2(ground.x - sw, ground.y - sw * 0.3, sw * 2.0, sw * 0.6), false,
			Color(0, 0, 0, 0.18 + 0.2 * k))
		var tex: Texture2D = l.tex
		# ζωντανό βλήμα (π.χ. νυχτερίδα που πετάει): παίζουν τα καρέ του
		if l.has("frames"):
			var fr: Array = l.frames
			tex = fr[int(l.t * float(l.fps)) % fr.size()]
		if tex == null:
			draw_texture_rect(dot, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false, Color("8a5a2b"))
			continue
		var s: Vector2 = tex.get_size() * float(l.scale)
		draw_set_transform(p, l.t * float(l.spin), Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, s), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Αλυσίδες από κάθε προστάτη στον boss όσο κρατάει η ασπίδα: τετράγωνα που
## κυλάνε προς αυτόν, ώστε να φαίνεται ΠΟΙΟΣ τον προστατεύει. Χρυσές από τους
## τυμπανιστές του Grukk, παγωμένες από το κύμα της θύελλας του Wendigo.
func _draw_tethers() -> void:
	var b = m.boss
	if b == null or not is_instance_valid(b) or not b.shield_on:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for d in m.grid.blocks():
		if d.is_vanishing():
			continue
		var col := Color(1.0, 0.81, 0.35)
		var ice: bool = d.has_meta("wave")
		if ice:
			col = Color("2f7fd8")      # σκούρο μπλε: το ανοιχτό χανόταν πάνω στο χιόνι
		elif d.kind != "war_drummer":
			continue
		var from: Vector2 = d.position
		var to: Vector2 = b.position
		var len := from.distance_to(to)
		var steps := int(len / 14.0)
		for i in steps:
			var k := fmod(float(i) / steps + t * 0.8, 1.0)
			var p := from.lerp(to, k)
			p = (p / 2.0).floor() * 2.0
			var a := 0.35 + 0.5 * sin(k * PI)
			if ice:
				# σκούρο τετράγωνο με λευκή καρδιά, σαν κρύσταλλος
				draw_rect(Rect2(p - Vector2(4, 4), Vector2(8, 8)), Color(0.08, 0.2, 0.4, a))
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(col, a))
				draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, a))
			else:
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(col, a))


## Γιατρειά του Wendigo: σταγόνες ζωής που ταξιδεύουν σε καμπύλη από το κύμα
## ως την καρδιά του (τετράγωνα στο πλέγμα των 2px, με ουρά), και το «+N» που
## ανεβαίνει και σβήνει.
func _draw_heal() -> void:
	var dot := Ball.dot_tex()
	for mo in m.heal_motes:
		if mo.t < 0.0:
			continue
		var k: float = clampf(mo.t / mo.dur, 0.0, 1.0)
		var e := k * k * (3.0 - 2.0 * k)
		var from: Vector2 = mo.from
		var to: Vector2 = mo.to
		for tail in 3:
			var kk := clampf(e - tail * 0.06, 0.0, 1.0)
			var p := from.lerp(to, kk) + Vector2(0, -60.0 * sin(kk * PI))
			p = (p / 2.0).floor() * 2.0
			var sz := 8.0 - tail * 2.0
			var a := 1.0 - tail * 0.3
			draw_texture_rect(dot, Rect2(p - Vector2(sz, sz) * 1.5, Vector2(sz, sz) * 3.0), false,
				Color(m.HEAL_COL, 0.18 * a))
			draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
				Color(m.HEAL_COL.lightened(0.3 if tail == 0 else 0.0), a))
	for hp in m.heal_pops:
		var k: float = hp.t / 1.2
		var p: Vector2 = (hp.pos as Vector2) + Vector2(0, -50.0 * k)
		var a := clampf((1.0 - k) / 0.4, 0.0, 1.0)
		for o in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(m.font, p + o - Vector2(60, 0), hp.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 30,
				Color(0.04, 0.12, 0.1, a))
		draw_string(m.font, p - Vector2(60, 0), hp.text, HORIZONTAL_ALIGNMENT_CENTER, 120, 30,
			Color(m.HEAL_COL, a))


## Το βλέμμα του Wendigo: τα μάτια αστράφτουν (δύο λευκοί πυρήνες με γαλάζιο
## φωτοστέφανο), όλη η πίστα παίρνει μια παγωμένη λάμψη, και ένα κύμα κρύου
## — δαχτυλίδι από τετράγωνα — απλώνεται από τα μάτια με την ταχύτητα που
## παγώνουν οι μπάλες.
func _draw_glare() -> void:
	var g: float = m.glare_t
	if g < 0.0:
		return
	var dot := Ball.dot_tex()
	var eyes: Vector2 = m.glare_eyes
	var b = m.boss
	var gap := 22.0
	if b and is_instance_valid(b) and b.ability is WendigoAbility:
		gap = b.ability.eyes_gap * b.box.x * 0.5
	# άναμμα ως το GLARE_FREEZE, μετά σβήνει αργά
	var up := clampf(g / m.GLARE_FREEZE, 0.0, 1.0)
	var down := clampf(1.0 - (g - m.GLARE_FREEZE) / 0.8, 0.0, 1.0)
	var power := up * down
	if power > 0.0:
		draw_rect(Rect2(m.pf_left, m.PF_TOP, m.PF_W, m.floor_y - m.PF_TOP),
			Color(0.45, 0.78, 1.0, 0.24 * power))
		for sx: float in [-1.0, 1.0]:
			var e := eyes + Vector2(sx * gap, 0)
			var halo := 30.0 + 50.0 * power
			draw_texture_rect(dot, Rect2(e - Vector2(halo, halo), Vector2(halo, halo) * 2.0), false,
				Color(0.45, 0.85, 1.0, 0.7 * power))
			var core := 6.0 + 4.0 * power
			draw_rect(Rect2((e / 2.0).floor() * 2.0 - Vector2(core, core) * 0.5, Vector2(core, core)),
				Color(1, 1, 1, power))
			# ακτίνες σε σχήμα σταυρού, σαν λάμψη από φακό
			for d: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
				var L := 30.0 * power
				var r := Rect2(e + d * L * 0.5 - Vector2(L * absf(d.x) + 2.0, L * absf(d.y) + 2.0) * 0.5,
					Vector2(L * absf(d.x) + 2.0, L * absf(d.y) + 2.0))
				draw_rect(r, Color(0.8, 0.96, 1.0, 0.8 * power))
	# το κύμα κρύου
	var wt: float = g - m.GLARE_FREEZE
	if wt > 0.0:
		var rad: float = wt * m.GLARE_SPEED
		var a := clampf(1.0 - wt / 0.9, 0.0, 1.0)
		if a > 0.0:
			var n := int(clampf(rad * 0.35, 12.0, 220.0))
			for i in n:
				if i % 6 == 5:
					continue
				var ang := TAU * float(i) / n
				var p := eyes + Vector2(cos(ang), sin(ang)) * rad
				if p.y > m.floor_y or p.y < m.PF_TOP - 20.0:
					continue
				p = (p / 2.0).floor() * 2.0
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(0.6, 0.88, 1.0, 0.3 * a))
				draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(0.9, 0.98, 1.0, a))


## Εφέ πάνω από τους εχθρούς (εκρήξεις, βελάκια, ασπίδες, emotes). Όσα είναι
## στο πάτωμα τα ζωγραφίζει το main, κάτω από τους εχθρούς.
func _draw_explosions() -> void:
	for a in m.fx_anims:
		if a.floor:
			continue
		var st: Array = m.fx_state(a)
		var tex: Texture2D = st[0]
		var s: Vector2 = tex.get_size() * float(st[1])
		draw_texture_rect(tex, Rect2((a.pos as Vector2) - s * 0.5, s), false, Color(1, 1, 1, st[2]))
