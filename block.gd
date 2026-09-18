extends StaticBody2D
## Εχθρός: πορτρέτο πάνω, μπάρα HP κάτω (όπως στο mockup).
## Αν υπάρχει sprite στο res://art/, ζωγραφίζεται αυτό αντί για το placeholder.

signal damaged(destroyed: bool)

var hp := 1
var max_hp := 1
var size := 78.0
var row := 0
var flash := 0.0
var kind := "goblin"
var sprite: Texture2D = null

# placeholder πορτρέτα 8x8
const ART := {
	"goblin": [
		"..GGGG..",
		".GGGGGG.",
		"GGGGGGGG",
		"G.WGGW.G",
		"GGGGGGGG",
		".GKKKKG.",
		"..GGGG..",
		"...GG..."
	],
	"knight": [
		"...YY...",
		"..SSSS..",
		".SSSSSS.",
		"SSSSSSSS",
		"SKKKKKKS",
		"SSSSSSSS",
		".SSSSSS.",
		"..SSSS.."
	],
	"brute": [
		"..BBBB..",
		".BBBBBB.",
		"BBBBBBBB",
		"BKKKKKKB",
		"BBBBBBBB",
		"B.BKKB.B",
		".BBBBBB.",
		"..BBBB.."
	]
}


func setup(p_hp: int, p_size: float, p_kind: String, p_sprite: Texture2D) -> void:
	hp = p_hp
	max_hp = p_hp
	size = p_size
	kind = p_kind
	sprite = p_sprite
	var shape := $CollisionShape2D.shape as RectangleShape2D
	shape.size = Vector2(size, size)
	queue_redraw()


func hit() -> void:
	hp -= 1
	flash = 1.0
	var destroyed := hp <= 0
	damaged.emit(destroyed)
	if destroyed:
		queue_free()
	else:
		queue_redraw()


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var s := size
	var half := s * 0.5
	var band := s * 0.28                       # ύψος μπάρας HP

	# πλαίσιο
	draw_rect(Rect2(-half, -half, s, s), Color("232338"))
	draw_rect(Rect2(-half + 2.0, -half + 2.0, s - 4.0, s - 4.0), Color("31314d"))

	# πορτρέτο — τετράγωνο, γεμίζει το κελί· η μπάρα HP μπαίνει από πάνω
	if sprite:
		draw_texture_rect(sprite, Rect2(-half + 3.0, -half + 3.0, s - 6.0, s - 6.0), false)
	else:
		var map: Array = ART.get(kind, ART["goblin"])
		var px := (s - 16.0) / 8.0
		var o := Vector2(-px * 4.0, -half + 6.0)
		for r in map.size():
			var line: String = map[r]
			for c in line.length():
				var ch := line[c]
				if ch == ".":
					continue
				draw_rect(Rect2(o + Vector2(c * px, r * px), Vector2(px, px)), _pix(ch))

	# μπάρα HP
	var t := clampf(float(hp) / float(maxi(max_hp, 1)), 0.0, 1.0)
	var bar := Rect2(-half + 3.0, half - band - 1.0, s - 6.0, band)
	draw_rect(bar, Color("1a1a2b"))
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4.0) * t, bar.size.y - 4.0)),
		Color.from_hsv(lerpf(0.0, 0.33, t), 0.72, 0.68))
	draw_string(ThemeDB.fallback_font, Vector2(-half, half - 6.0), str(hp),
		HORIZONTAL_ALIGNMENT_CENTER, s, int(band * 0.85), Color("ffffff"))

	if flash > 0.02:
		draw_rect(Rect2(-half, -half, s, s), Color(1, 1, 1, flash * 0.55))


func _pix(ch: String) -> Color:
	match ch:
		"G": return Color("6ab04c")     # goblin
		"S": return Color("9aa3ad")     # ατσάλι
		"B": return Color("6d5f8c")     # brute
		"Y": return Color("f7d060")     # λοφίο
		"W": return Color.WHITE         # μάτια
		"K": return Color("15111f")     # σκιά / στόμα
	return Color.MAGENTA
