extends Node2D
## Σπίθες και λάμψεις. Ζει σε ψηλό z_index ώστε να σχεδιάζεται πάνω από τους
## εχθρούς, αλλά μέσα στο Main ώστε να ακολουθεί το screen shake.

var m: Game


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if m == null:
		return
	for s in m.sparks:
		var f: float = clampf(s["life"] / s["max"], 0.0, 1.0)
		var c: Color = s["c"]
		# λαμπερός πυρήνας με απαλό φωτοστέφανο
		draw_circle(s["p"], s["r"] * f * 2.2, Color(c.r, c.g, c.b, f * 0.18))
		draw_circle(s["p"], s["r"] * f, Color(c.r, c.g, c.b, f))
