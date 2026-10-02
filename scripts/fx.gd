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


## Χρυσές αλυσίδες από κάθε τυμπανιστή στον boss όσο κρατάει η ασπίδα:
## τετράγωνα που κυλάνε προς τον πύργο, ώστε να φαίνεται ΠΟΙΟΣ τον προστατεύει.
func _draw_tethers() -> void:
	var b = m.boss
	if b == null or not is_instance_valid(b) or not b.shield_on:
		return
	var t := Time.get_ticks_msec() / 1000.0
	for d in m.grid.blocks():
		if d.kind != "war_drummer" or d.is_vanishing():
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
			draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1.0, 0.81, 0.35, a))


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
