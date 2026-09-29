extends Node2D
## Το μαύρο του cinematic αλλαγής περιοχής. Ζει σε δικό του CanvasLayer πάνω
## από το HUD και το Book, ώστε να σκεπάζει τα πάντα· στο μαύρο γράφει το
## όνομα της νέας περιοχής.

const GOLD := Color("ffd98a")
const DIM := Color("a89f8a")
const INK := Color("100c10")

var m


func _process(_delta: float) -> void:
	if m and (m.in_transition() or visible):
		visible = m.in_transition()
		queue_redraw()


func _draw() -> void:
	if m == null:
		return
	var a: float = m.transition_alpha()
	if a <= 0.0:
		return
	draw_rect(Rect2(Vector2.ZERO, Vector2(m.W, m.H)), Color(0.02, 0.015, 0.03, a))
	# το κείμενο μόνο αφού έχει αλλάξει ήδη το σκηνικό από κάτω
	if not m._trans_swapped:
		return
	var area = m.current_area()
	if area == null:
		return
	var ta := clampf((a - 0.5) * 2.0, 0.0, 1.0)
	var y: float = m.H * 0.44
	_line(y, "AREA %d" % (m.area_index + 1), 22, Color(DIM, ta))
	_line(y + 56.0, area.display_name.to_upper(), 44, Color(GOLD, ta))


func _line(y: float, s: String, size: int, col: Color) -> void:
	var font: Font = m.font
	draw_string_outline(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, m.W, size, 4, Color(INK, col.a))
	draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, m.W, size, col)
