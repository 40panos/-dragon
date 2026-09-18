extends Area2D
## Pickup: "ball" = +1 μπάλα, "triple" = Triple Shot για 3 γύρους.

var col := 0
var row := 0
var kind := "ball"
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var y := sin(t * 3.0) * 3.0
	var c := Color("ffb638") if kind == "ball" else Color("7ad0ff")
	draw_circle(Vector2(0, y), 24.0, Color(c.r, c.g, c.b, 0.20))
	draw_circle(Vector2(0, y), 13.0, c)
	var label := "+1" if kind == "ball" else "x3"
	draw_string(ThemeDB.fallback_font, Vector2(-24, y + 6.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, 48, 20, Color("2a1500"))
