extends Node2D
## Σπίθες και λάμψεις. Ζει σε ψηλό z_index ώστε να σχεδιάζεται πάνω από τους
## εχθρούς, αλλά μέσα στο Main ώστε να ακολουθεί το screen shake.

var m


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if m == null:
		return
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
