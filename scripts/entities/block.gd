extends StaticBody2D
## Εχθρός στο ταμπλό. Μπορεί να πιάνει παραπάνω από ένα κελί (boss).

signal damaged(destroyed: bool, amount: float)

const HEART_TEX := preload("res://art/ui_heart.png")
const SHIELD_TEX := preload("res://art/ui_shield.png")
const OUTLINE_OFFSETS := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

# περίγραμμα κελιού: διακριτικό άσπρο, στη θέση του παλιού γεμάτου φόντου.
# Από κάτω του μπαίνει μια σκούρα γραμμή, αλλιώς χάνεται πάνω στα ανοιχτά
# πλακάκια του δαπέδου — ίδιο κόλπο με το περίγραμμα των αριθμών.
const EDGE_COLOR := Color(1, 1, 1, 0.42)
const EDGE_SHADOW := Color(0, 0, 0, 0.32)
const GLOW_RINGS := 4          # ομόκεντροι δακτύλιοι λάμψης όταν φάει χτύπημα
const GLOW_ALPHA := 0.9        # ένταση του πιο μέσα δακτυλίου, στο φουλ της λάμψης
# λίγος παραπάνω χρόνος από το tween του κατεβάσματος, ώστε το περίγραμμα να
# μην ξαναεμφανιστεί ένα καρέ πριν ακουμπήσει ο εχθρός στη νέα του σειρά
const MOVE_GRACE := 0.05

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

# πόσο μέρος του κελιού πιάνει το πορτρέτο· αφορά μόνο τη σχεδίαση
var sprite_scale := 1.0

# ήρεμη στάση (idle loop) — προαιρετική, αλλιώς μένει στο στατικό sprite
var frames_idle: Array[Texture2D] = []
var fps_idle := 6.0
var idle_t := 0.0

# αντίδραση σε χτύπημα — παίζει ΜΙΑ φορά κάθε φορά που δέχεται ζημιά
var frames_hit: Array[Texture2D] = []
var fps_hit := 12.0
var hit_t := 0.0
var hit_playing := false

# μονή αναπαραγωγή που ζητάει μια ικανότητα — π.χ. το ουρλιαχτό του βασιλιά
# όταν καλεί. Η αντίδραση σε χτύπημα έχει προτεραιότητα: αν φας μπάλα μέσα στο
# ουρλιαχτό, βλέπεις το χτύπημα.
var act_frames: Array[Texture2D] = []
var act_fps := 10.0
var act_t := 0.0
var act_playing := false

# χρόνος που απομένει στο κατέβασμα σειράς· όσο τρέχει, ο εχθρός μετράει ως
# «σε κίνηση» και κρύβει το περίγραμμά του. Μετράει μόνος του αντίστροφα, ώστε
# να μη χρειάζεται callback από το tween που μπορεί να μην έρθει ποτέ.
var move_t := 0.0

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
		p_ability: EnemyAbility, p_cw: int = 1, p_ch: int = 1,
		p_frames_idle: Array[Texture2D] = [], p_fps_idle: float = 6.0,
		p_frames_hit: Array[Texture2D] = [], p_fps_hit: float = 12.0,
		p_sprite_scale: float = 1.0) -> void:
	hp = p_hp
	max_hp = p_hp
	box = p_box
	kind = p_kind
	sprite = p_sprite
	cw = p_cw
	ch = p_ch
	frames_idle = p_frames_idle
	fps_idle = p_fps_idle
	frames_hit = p_frames_hit
	fps_hit = p_fps_hit
	sprite_scale = clampf(p_sprite_scale, 0.3, 1.0)
	# ξεκίνα από τυχαίο σημείο του βρόχου, ώστε τα ίδια πλάσματα να μην
	# χτυπάνε συγχρονισμένα σαν στρατός
	idle_t = randf() * 10.0
	# κάθε εχθρός παίρνει δικό του αντίγραφο, ώστε οι μετρητές να μην είναι κοινοί
	ability = p_ability.clone() if p_ability else null
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
	if not frames_hit.is_empty():
		hit_t = 0.0
		hit_playing = true
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


## Το καλεί το main όταν ξεκινάει το κατέβασμα σειράς, με τη διάρκεια του tween.
func begin_move(duration: float) -> void:
	move_t = duration + MOVE_GRACE
	queue_redraw()


func is_moving() -> bool:
	return move_t > 0.0


## Παίζει ένα σετ καρέ μία φορά, κατόπιν αιτήματος ικανότητας.
func play_act(frames: Array[Texture2D], fps: float) -> void:
	if frames.is_empty():
		return
	act_frames = frames
	act_fps = maxf(fps, 0.1)
	act_t = 0.0
	act_playing = true
	queue_redraw()


## Αλλάζει το σετ ηρεμίας στον αέρα — το χρησιμοποιεί η οργή του boss, ώστε
## το δεύτερο στάδιο να φαίνεται χωρίς δεύτερο εχθρό στο ταμπλό.
func set_idle(frames: Array[Texture2D], fps: float) -> void:
	if frames.is_empty():
		return
	frames_idle = frames
	fps_idle = maxf(fps, 0.1)
	idle_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	if move_t > 0.0:
		move_t = maxf(0.0, move_t - delta)
		if move_t == 0.0:
			queue_redraw()      # σταμάτησε — ξαναδείξε το περίγραμμα
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 6.0)
		queue_redraw()
	if hit_playing:
		hit_t += delta
		if hit_t >= float(frames_hit.size()) / fps_hit:
			hit_playing = false      # τέλειωσε η αντίδραση, γύρνα στο idle
		queue_redraw()
	if act_playing:
		act_t += delta
		if act_t >= float(act_frames.size()) / act_fps:
			act_playing = false
		queue_redraw()
	if not hit_playing and not act_playing and frames_idle.size() > 1:
		idle_t += delta
		queue_redraw()


## Το καρέ ήρεμης στάσης που πρέπει να φαίνεται τώρα· βρόχος προς τα εμπρός
## (0,1,2,...,τέλος,0,...), όχι ping-pong — το σετ είναι φτιαγμένο να κλείνει.
func idle_frame() -> Texture2D:
	if frames_idle.is_empty():
		return sprite
	if frames_idle.size() == 1:
		return frames_idle[0]
	var i := int(idle_t * fps_idle) % frames_idle.size()
	return frames_idle[i]


## Το πορτρέτο που πρέπει να φαίνεται τώρα: η αντίδραση σε χτύπημα παίζει
## ΜΙΑ φορά (δεν κάνει loop, σταματάει στο τελευταίο καρέ αν προλάβει να
## ξαναζωγραφιστεί πριν το _process την κλείσει) και έχει προτεραιότητα
## έναντι του idle.
func portrait_frame() -> Texture2D:
	if hit_playing and not frames_hit.is_empty():
		var i := int(hit_t * fps_hit)
		i = clampi(i, 0, frames_hit.size() - 1)
		return frames_hit[i]
	if act_playing and not act_frames.is_empty():
		var j := int(act_t * act_fps)
		j = clampi(j, 0, act_frames.size() - 1)
		return act_frames[j]
	return idle_frame()


## Σχεδιάζει κείμενο με μαύρο περίγραμμα, ώστε να διαβάζεται πάνω σε οτιδήποτε.
func _draw_outline_text(pos: Vector2, text: String, size: int, color: Color) -> void:
	for off in OUTLINE_OFFSETS:
		draw_string(ThemeDB.fallback_font, pos + off, text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("000000"))
	draw_string(ThemeDB.fallback_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Πόση ασπίδα έχει τώρα ο εχθρός, μόνο αν έχει ShieldAbility.
func _shield_amount() -> int:
	if ability is ShieldAbility:
		return maxi(0, int(ceil((ability as ShieldAbility).shield)))
	return 0


## Διακριτικό περίγραμμα στη θέση του παλιού γεμάτου τετραγώνου: το πίσω μέρος
## του κελιού μένει διάφανο και φαίνεται το δάπεδο. Το περίγραμμα δείχνεται
## ΜΟΝΟ όσο ο εχθρός στέκεται ακίνητος — όταν κατεβαίνει σειρά σβήνει, ώστε να
## μη σέρνονται άσπρα κουτάκια στην οθόνη — και λάμπει όταν φάει χτύπημα.
func _draw_edge() -> void:
	var rect := Rect2(-box * 0.5, box)
	if not is_moving():
		draw_rect(rect.grow(1.0), EDGE_SHADOW, false, 1.0)
		draw_rect(rect, EDGE_COLOR, false, 1.0)
	if flash <= 0.02:
		return
	# λάμψη ζημιάς: ομόκεντροι δακτύλιοι που ξεθωριάζουν προς τα έξω
	for i in GLOW_RINGS:
		draw_rect(rect.grow(float(i)), Color(1, 1, 1, flash * GLOW_ALPHA / float(i + 1)),
			false, 1.0)


func _draw() -> void:
	var half := box * 0.5
	var band := minf(box.y * 0.14, 10.0)      # ύψος μπάρας ζωής — μικρή, ο αριθμός μιλάει

	_draw_edge()

	# πορτρέτο — αντίδραση σε χτύπημα > idle loop > στατικό sprite
	var portrait := portrait_frame()
	if portrait:
		# το sprite_scale μικραίνει μόνο το πορτρέτο, κεντραρισμένο μέσα στο
		# κελί — το κουτί, το περίγραμμα και οι ενδείξεις μένουν στη θέση τους
		var psize := (box - Vector2(6, 6)) * sprite_scale
		draw_texture_rect(portrait, Rect2(-psize * 0.5, psize), false)
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

	# ασπίδα — μόνο ο ασπιδοφόρος (ShieldAbility) την έχει· εικονίδιο + αριθμός
	var shield_amt := _shield_amount()
	if shield_amt > 0:
		var sic := 13.0
		var spos := Vector2(-half.x + 2.0, -half.y + 2.0)
		draw_texture_rect(SHIELD_TEX, Rect2(spos, Vector2(sic, sic)), false)
		_draw_outline_text(spos + Vector2(sic + 2.0, sic - 1.0), str(shield_amt), 13, Color("bfe6ff"))

	# μικρή μπάρα ζωής, χρωματισμένη ανάλογα με το ποσοστό
	var t := clampf(hp / maxf(max_hp, 0.001), 0.0, 1.0)
	var bar := Rect2(-half.x + 3.0, half.y - band - 1.0, box.x - 6.0, band)
	draw_rect(bar, Color(0.102, 0.102, 0.169, 0.55))
	var fill_color := Color.from_hsv(lerpf(0.0, 0.33, t), 0.72, 0.68)
	fill_color.a = 0.6
	draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2.0) * t, bar.size.y - 2.0)),
		fill_color)

	# καρδιά + αριθμός ζωής, πάνω από τη μπάρα — ίδιο ύφος με την ασπίδα
	var hic := 12.0
	var hpos := Vector2(-half.x + 2.0, bar.position.y - hic - 2.0)
	draw_texture_rect(HEART_TEX, Rect2(hpos, Vector2(hic, hic)), false)
	_draw_outline_text(hpos + Vector2(hic + 2.0, hic - 1.0), str(shown_hp()), 13, Color("ffffff"))

	# ένδειξη ικανότητας
	if ability:
		var tag := ability.badge()
		if tag != "":
			draw_string(ThemeDB.fallback_font, Vector2(-half.x + 4.0, -half.y + 18.0), tag,
				HORIZONTAL_ALIGNMENT_LEFT, box.x, 16, Color("ffe1ad"))


func _pix(ch_: String) -> Color:
	match ch_:
		"G": return Color("6ab04c")
		"S": return Color("9aa3ad")
		"B": return Color("6d5f8c")
		"Y": return Color("f7d060")
		"W": return Color.WHITE
		"K": return Color("15111f")
	return Color.MAGENTA
