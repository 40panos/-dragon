extends StaticBody2D
## Εχθρός στο ταμπλό. Μπορεί να πιάνει παραπάνω από ένα κελί (boss).

signal damaged(destroyed: bool, amount: float)

var hp := 1.0
var max_hp := 1.0
var box := Vector2(72, 72)      # μέγεθος σε pixel
var col := 0
var row := 0
var cw := 1                      # αποτύπωμα σε κελιά
var ch := 1
var flash := 0.0
var kind := "goblin"
var sprite: Texture2D = null
var ability: EnemyAbility = null
var is_boss := false

# placeholder πορτρέτα 8x8, όταν λείπει sprite
const ART := {
	"goblin": [
		"..GGGG..", ".GGGGGG.", "GGGGGGGG", "G.WGGW.G",
		"GGGGGGGG", ".GKKKKG.", "..GGGG..", "...GG..."
	],
	"knight": [
		"...YY...", "..SSSS..", ".SSSSSS.", "SSSSSSSS",
		"SKKKKKKS", "SSSSSSSS", ".SSSSSS.", "..SSSS.."
	],
	"brute": [
		"..BBBB..", ".BBBBBB.", "BBBBBBBB", "BKKKKKKB",
		"BBBBBBBB", "B.BKKB.B", ".BBBBBB.", "..BBBB.."
	]
}


func setup(p_hp: float, p_box: Vector2, p_kind: String, p_sprite: Texture2D,
		p_ability: EnemyAbility, p_cw: int = 1, p_ch: int = 1) -> void:
	hp = p_hp
	max_hp = p_hp
	box = p_box
	kind = p_kind
	sprite = p_sprite
	cw = p_cw
	ch = p_ch
	# κάθε εχθρός παίρνει δικό του αντίγραφο, ώστε οι μετρητές να μην είναι κοινοί
	ability = p_ability.duplicate() if p_ability else null
	var shape := $CollisionShape2D.shape as RectangleShape2D
	shape.size = box
	if ability:
		ability.on_spawn(self)
	queue_redraw()


## Επιστρέφει πόση ζημιά πέρασε στη ζωή. Η ασπίδα μπορεί να την απορροφήσει.
func take_damage(amount: float) -> float:
	var through := amount
	if ability:
		through = ability.absorb(self, amount)
	flash = 1.0
	if through <= 0.0:
		queue_redraw()
		damaged.emit(false, amount)
		return 0.0
	hp -= through
	var destroyed := hp <= 0.001
	damaged.emit(destroyed, amount)
	if destroyed:
		queue_free()
	else:
		queue_redraw()
	return through


func shown_hp() -> int:
	return maxi(0, int(ceil(hp)))


func _process(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		queue_redraw()


func _draw() -> void:
	var half := box * 0.5
	var band := minf(box.y * 0.28, 22.0)      # ύψος μπάρας ζωής

	draw_rect(Rect2(-half, box), Color("232338"))
	draw_rect(Rect2(-half + Vector2(2, 2), box - Vector2(4, 4)), Color("31314d"))

	# πορτρέτο
	if sprite:
		draw_texture_rect(sprite, Rect2(-half + Vector2(3, 3), box - Vector2(6, 6)), false)
	else:
		var map: Array = ART.get(kind, ART["goblin"])
		var px := (minf(box.x, box.y) - 16.0) / 8.0
		var o := Vector2(-px * 4.0, -half.y + 6.0)
		for r in map.size():
			var line: String = map[r]
			for c in line.length():
				var ch_ := line[c]
				if ch_ == ".":
					continue
				draw_rect(Rect2(o + Vector2(c * px, r * px), Vector2(px, px)), _pix(ch_))

	# ασπίδα, αν υπάρχει και αντέχει
	var sh := _shield_ratio()
	if sh > 0.0:
		draw_rect(Rect2(-half, box), Color(0.45, 0.75, 1.0, 0.18))
		var sbar := Rect2(-half.x + 3.0, -half.y + 3.0, (box.x - 6.0) * sh, 5.0)
		draw_rect(sbar, Color("7ad0ff"))

	# μπάρα ζωής
	var t := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var bar := Rect2(-half.x + 3.0, half.y - band - 1.0, box.x - 6.0, band)
	draw_rect(bar, Color("1a1a2b"))
	draw_rect(Rect2(bar.position + Vector2(2, 2), Vector2((bar.size.x - 4.0) * t, bar.size.y - 4.0)),
		Color.from_hsv(lerpf(0.0, 0.33, t), 0.72, 0.68))
	draw_string(ThemeDB.fallback_font, Vector2(-half.x, half.y - 6.0), str(shown_hp()),
		HORIZONTAL_ALIGNMENT_CENTER, box.x, int(band * 0.8), Color("ffffff"))

	# ένδειξη ικανότητας
	if ability:
		var tag := ability.badge()
		if tag != "":
			draw_string(ThemeDB.fallback_font, Vector2(-half.x + 4.0, -half.y + 18.0), tag,
				HORIZONTAL_ALIGNMENT_LEFT, box.x, 16, Color("ffe1ad"))

	if flash > 0.02:
		draw_rect(Rect2(-half, box), Color(1, 1, 1, flash * 0.55))


func _shield_ratio() -> float:
	if ability is ShieldAbility:
		var s := ability as ShieldAbility
		if s.shield_max > 0.0:
			return clampf(s.shield / s.shield_max, 0.0, 1.0)
	return 0.0


func _pix(ch_: String) -> Color:
	match ch_:
		"G": return Color("6ab04c")
		"S": return Color("9aa3ad")
		"B": return Color("6d5f8c")
		"Y": return Color("f7d060")
		"W": return Color.WHITE
		"K": return Color("15111f")
	return Color.MAGENTA
