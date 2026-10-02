class_name Block
extends StaticBody2D
## Εχθρός στο ταμπλό. Μπορεί να πιάνει παραπάνω από ένα κελί (boss).

signal damaged(destroyed: bool, amount: float)

const HEART_TEX := preload("res://art/ui_heart.png")
const SHIELD_TEX := preload("res://art/ui_shield.png")
const OUTLINE_OFFSETS := [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]

# περίγραμμα κελιού: ίσα-ίσα ορατό άσπρο, στη θέση του παλιού γεμάτου φόντου.
# Από κάτω του μπαίνει μια σκούρα γραμμή, αλλιώς χάνεται πάνω στα ανοιχτά
# πλακάκια του δαπέδου — ίδιο κόλπο με το περίγραμμα των αριθμών. Η σκιά
# μένει λίγο πιο δυνατή από το άσπρο: αυτή κάνει τη δουλειά πάνω σε φωτεινό
# φόντο, ενώ το άσπρο μόνο υπαινίσσεται το κελί.
const EDGE_COLOR := Color(1, 1, 1, 0.13)
const EDGE_SHADOW := Color(0, 0, 0, 0.16)
const GLOW_RINGS := 4          # ομόκεντροι δακτύλιοι λάμψης όταν φάει χτύπημα
const GLOW_ALPHA := 0.9        # ένταση του πιο μέσα δακτυλίου, στο φουλ της λάμψης
const BURST_TIME := 0.32       # διάρκεια της έκρηξης πίσω από boss/minions
const BURST_PX := 4.0          # «pixel» της έκρηξης: 2 art pixels, πάνω στο πλέγμα
const BURST_RAYS := 10

# Φλογερό περίγραμμα: το σχέδιο είναι ένα τετράγωνο δαχτυλίδι 48x48 με άδεια
# μέση (tools/build_glow.gd). Μπαίνει σαν πλαίσιο εννιά κομματιών — γωνίες
# ατόφιες, πλευρές ΕΠΑΝΑΛΑΜΒΑΝΟΜΕΝΕΣ — γιατί το κουτί αλλάζει μέγεθος: 80px
# για απλό κελί, 251x165 για boss. Τεντωμένο θα έλιωναν τα pixel του.
const RING_SRC := 48.0         # ο καμβάς του σχεδίου
const RING_MARGIN := 16.0      # πόσο πιάνει η γωνία μέσα στο σχέδιο
const RING_SCALE := 2.0        # ίδια κλίμακα με τον δράκο και τη φωλιά
const RING_GROW := 6.0         # ξεχειλίζει λίγο έξω από το κελί, όπως η λάμψη
const RING_FPS := 14.0
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

# Καρέ του φλογερού περιγράμματος. Έρχονται από τον ΔΡΑΚΟ, όχι από τον εχθρό:
# η λάμψη είναι το χτύπημα του παίκτη, οπότε ο δράκος της φωτιάς αφήνει φλόγες
# και ο επόμενος θα αφήνει κάτι δικό του. Άδειο = οι παλιοί λευκοί δακτύλιοι.
var glow_frames: Array[Texture2D] = []
## Χρώμα της έκρηξης πίσω από boss και minions (βλ. _draw_burst). Το δίνει το
## main από τον ενεργό δράκο, όπως και τα glow_frames.
var burst_color := Color("ff9e2c")
var burst_t := 1.0                 # χρόνος από το τελευταίο χτύπημα, σε κλάσματα του BURST_TIME
var glow_t := 0.0

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

# ---- αντικείμενα και μεγάλος boss
var invulnerable := false       # οδόφραγμα: η ζημιά χάνεται, οι μπάλες αναπηδούν
var show_hp := true             # καρδιά και μπάρα ζωής
var fuse := -1                  # βαρέλι: γύροι ως την έκρηξη (<0 = δεν έχει)
var life_turns := -1            # οδόφραγμα: γύροι ως το γκρέμισμα (<0 = μόνιμο)
var life_max := 0
var is_final := false           # ο μεγάλος boss της περιοχής
var shield_on := false          # ο μεγάλος boss προστατεύεται (π.χ. από τύμπανα)
var shield_hit_t := 1.0         # χρόνος από το τελευταίο χτύπημα στην ασπίδα
var weak_rect := Rect2()        # αδύναμο σημείο σε τοπικές συντεταγμένες (μέγεθος 0 = κανένα)
var bump_t := 1.0               # τράνταγμα όταν χτυπιέται κάτι άθραυστο

# ---- ασπίδα που μπλοκάρει (ShieldAbility): αντί για σπίθες, ένα φωτεινό
# τετράγωνο προστασίας στην πλευρά απ' όπου ήρθε το χτύπημα
const GUARD_TIME := 0.35
static var guard_frames: Array[Texture2D] = []
var guard_t := 1.0
var guard_dir := Vector2.DOWN

# ---- εμφάνιση / εξαφάνιση: τίποτα δεν πετάγεται ούτε χάνεται σε ένα καρέ
const APPEAR_TIME := 0.38
const VANISH_TIME := 0.45
var appear_mode := ""           # "" τίποτα, "pop" βγαίνει από βαρέλι, "rise" υψώνεται από το έδαφος
var appear_t := 1.0
var vanish_t := -1.0            # >=0: σβήνει και μετά φεύγει

# Παγωμένος από το FREEZE: νιφάδα πάνω του όσο κρατάει. Το frozen_t μετράει
# από τη στιγμή που πάγωσε, για το σβήσιμο-άναμμα της νιφάδας.
var frozen := false
var frozen_t := 0.0

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
	if vanish_t >= 0.0:
		return 0.0
	# άθραυστο: τρανταγμα και τίποτα άλλο — ούτε ζημιά ούτε πόντοι
	if invulnerable:
		bump_t = 0.0
		queue_redraw()
		return 0.0
	# ο μεγάλος boss πίσω από ασπίδα: η ασπίδα αστράφτει, η ζημιά χάνεται
	if shield_on:
		shield_hit_t = 0.0
		bump_t = 0.0
		queue_redraw()
		return 0.0
	var through := amount
	if ability:
		through = ability.absorb(self, amount)
	# η ασπίδα το κράτησε ολόκληρο: φαίνεται μόνο το τετράγωνο προστασίας
	# (guard_flash, από το main), όχι η φλόγα του χτυπήματος
	if through <= 0.0 and ability is ShieldAbility:
		damaged.emit(false, amount)
		return 0.0
	flash = 1.0
	burst_t = 0.0
	glow_t = 0.0        # η φλόγα ξεκινάει από την αρχή σε κάθε χτύπημα
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


## Γιατρειά (π.χ. RegenerateAbility). Ποτέ πάνω από τη μέγιστη ζωή.
func heal(amount: float) -> void:
	hp = minf(max_hp, hp + maxf(amount, 0.0))
	queue_redraw()


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
		glow_t += delta
		queue_redraw()
	if burst_t < 1.0:
		burst_t = minf(1.0, burst_t + delta / BURST_TIME)
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
	if frozen and frozen_t < FLAKE_LIFE:
		frozen_t += delta
		queue_redraw()
	if appear_t < 1.0:
		appear_t = minf(1.0, appear_t + delta / APPEAR_TIME)
		queue_redraw()
	if guard_t < 1.0:
		guard_t = minf(1.0, guard_t + delta / GUARD_TIME)
		queue_redraw()
	if bump_t < 1.0:
		bump_t = minf(1.0, bump_t + delta * 6.0)
		queue_redraw()
	if shield_on or shield_hit_t < 1.0:
		shield_hit_t = minf(1.0, shield_hit_t + delta * 3.0)
		queue_redraw()
	if fuse >= 0 or weak_rect.has_area():
		queue_redraw()          # φυτίλι που τρεμοπαίζει, στόχαστρο που πάλλεται
	if vanish_t >= 0.0:
		vanish_t += delta
		var k := clampf(vanish_t / VANISH_TIME, 0.0, 1.0)
		modulate.a = 1.0 - k
		if k >= 1.0:
			queue_free()
		queue_redraw()


## Η ασπίδα κράτησε ένα χτύπημα από την κατεύθυνση `from` (σε τοπικές
## συντεταγμένες). Η πλευρά κουμπώνει στον κοντινότερο άξονα: το τετράγωνο
## στέκεται πάνω, κάτω, αριστερά ή δεξιά του εχθρού, όχι λοξά.
func guard_flash(from: Vector2) -> void:
	if absf(from.x) > absf(from.y):
		guard_dir = Vector2(signf(from.x), 0.0)
	else:
		guard_dir = Vector2(0.0, signf(from.y) if from.y != 0.0 else 1.0)
	guard_t = 0.0
	queue_redraw()


func _draw_guard() -> void:
	if guard_frames.is_empty():
		return
	var i := clampi(int(guard_t * guard_frames.size()), 0, guard_frames.size() - 1)
	var tex := guard_frames[i]
	var s := minf(box.x, box.y) * 0.62
	var c := guard_dir * (box * 0.5 - Vector2(s, s) * 0.18)
	var a := 1.0 - guard_t * guard_t
	draw_texture_rect(tex, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(1, 1, 1, a))


## Ξεκινάει το animation εμφάνισης. "pop": πετάγεται από το βαρέλι που
## έσπασε — μικρό, πηδάει, ξεπερνάει λίγο το μέγεθός του και κάθεται. "rise":
## υψώνεται από το έδαφος, με τη βάση καρφωμένη (οδόφραγμα που στήνεται).
func appear(mode: String) -> void:
	appear_mode = mode
	appear_t = 0.0
	queue_redraw()


## Σβήνει και φεύγει μόνο του. Το κελί ελευθερώνεται αμέσως από όποιον το
## καλεί· η σύγκρουση κλείνει, ώστε οι μπάλες να περνάνε από το φάντασμα.
func vanish() -> void:
	if vanish_t >= 0.0:
		return
	vanish_t = 0.0
	remove_from_group("block")
	$CollisionShape2D.set_deferred("disabled", true)


func is_vanishing() -> bool:
	return vanish_t >= 0.0


## Ο μετασχηματισμός του animation εμφάνισης (και του τραντάγματος), που
## εφαρμόζεται σε όλο το _draw — πορτρέτο, περίγραμμα, ενδείξεις μαζί.
func _appear_xform() -> Transform2D:
	var s := Vector2.ONE
	var off := Vector2.ZERO
	if appear_t < 1.0:
		var k := appear_t
		if appear_mode == "rise":
			var e := 1.0 - pow(1.0 - k, 3.0)
			s = Vector2(1.0 + (1.0 - e) * 0.15, maxf(e, 0.02))
			off.y = box.y * 0.5 * (1.0 - s.y)       # η βάση μένει στο έδαφος
		else:
			# μικρό άλμα με υπερακόντιση: 0.35 -> 1.15 -> 1.0
			var e := 1.0 - pow(1.0 - k, 2.0)
			var over := sin(k * PI) * 0.18
			var sc := lerpf(0.35, 1.0, e) + over
			s = Vector2(sc, sc)
			off.y = -sin(k * PI) * box.y * 0.35
	if bump_t < 1.0:
		off.x += sin(bump_t * 40.0) * (1.0 - bump_t) * 3.0
	return Transform2D(0.0, s, 0.0, off)


func set_frozen(on: bool) -> void:
	if on and not frozen:
		frozen_t = 0.0
	frozen = on
	queue_redraw()


# ---------------------------------------------------------------- νιφάδα

const FLAKE_N := 13              # καμβάς της νιφάδας σε art pixels
const FLAKE_FADE := 0.25         # άναμμα όταν παγώνει
const FLAKE_LIFE := 1.8          # πόσο μένει η νιφάδα· μετά μένει μόνο το γαλάζιο χρώμα
const FLAKE_OUT := 0.45          # σβήσιμο στο τέλος της ζωής της
static var _flake: Texture2D
static var _flake_tips: Array[Vector2i] = []


## Νιφάδα σε pixel art, φτιαγμένη μία φορά για όλους: οκτώ ακτίνες
## (οριζόντια, κάθετη, διαγώνιες), με κλαδάκια σε σχήμα V στις ευθείες,
## λευκό κέντρο και σκούρο μπλε περίγραμμα ώστε να διαβάζεται σε κάθε φόντο.
static func flake_tex() -> Texture2D:
	if _flake:
		return _flake
	var n := FLAKE_N
	var c := n / 2
	var body := {}
	var put := func(x: int, y: int, col: Color) -> void:
		if x >= 1 and y >= 1 and x < n - 1 and y < n - 1:
			body[Vector2i(x, y)] = col
	var arm := Color("bfeaff")
	var core := Color("ffffff")
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		for i in range(1, 6):
			put.call(c + d.x * i, c + d.y * i, arm)
		# κλαδάκι V κοντά στην άκρη της ακτίνας
		var side := Vector2i(d.y, d.x)
		for s in [1, -1]:
			put.call(c + d.x * 4 + side.x * s, c + d.y * 4 + side.y * s, arm)
		_flake_tips.append(Vector2i(c + d.x * 5, c + d.y * 5))
	for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		for i in range(1, 4):
			put.call(c + d.x * i, c + d.y * i, arm)
		_flake_tips.append(Vector2i(c + d.x * 3, c + d.y * 3))
	put.call(c, c, core)
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		put.call(c + d.x, c + d.y, core)
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var outline := Color("163a63")
	for p in body:
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = p + o
			if not body.has(q) and q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
				img.set_pixelv(q, outline)
	for p in body:
		img.set_pixelv(p, body[p])
	_flake = ImageTexture.create_from_image(img)
	return _flake


## Η νιφάδα στο κέντρο του εχθρού, πάνω από το σώμα του, τη στιγμή που
## παγώνει· σβήνει μετά από FLAKE_LIFE. Μέγεθος σε ακέραια πολλαπλάσια του
## art pixel ανάλογα με το κουτί (ο boss παίρνει μεγαλύτερη), και μια λάμψη
## που τρέχει από ακτίνα σε ακτίνα.
func _draw_snowflake() -> void:
	if frozen_t >= FLAKE_LIFE:
		return
	var tex := flake_tex()
	var k := maxf(2.0, floorf(minf(box.x, box.y) / 26.0))
	var size := FLAKE_N * k
	var pos := (Vector2(-size, -size) * 0.5).floor()
	var a := clampf(minf(frozen_t / FLAKE_FADE, (FLAKE_LIFE - frozen_t) / FLAKE_OUT), 0.0, 1.0)
	draw_texture_rect(tex, Rect2(pos, Vector2(size, size)), false, Color(1, 1, 1, a))
	if _flake_tips.is_empty():
		return
	var tip: Vector2i = _flake_tips[int(frozen_t * 6.0) % _flake_tips.size()]
	draw_rect(Rect2(pos + Vector2(tip) * k, Vector2(k, k)), Color(1, 1, 1, a))


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
	# boss και minions: αντί για δαχτυλίδι στο κουτί, έκρηξη πίσω τους (_draw_burst)
	if uses_burst():
		return
	if flash <= 0.02:
		return
	# λάμψη ζημιάς: το φλογερό δαχτυλίδι του δράκου, αν υπάρχει
	if not glow_frames.is_empty():
		var gi := int(glow_t * RING_FPS) % glow_frames.size()
		_draw_ring(glow_frames[gi], rect.grow(RING_GROW), flash)
		return
	# αλλιώς οι παλιοί ομόκεντροι δακτύλιοι, που ξεθωριάζουν προς τα έξω
	for i in GLOW_RINGS:
		draw_rect(rect.grow(float(i)), Color(1, 1, 1, flash * GLOW_ALPHA / float(i + 1)),
			false, 1.0)


## Boss (πολλά κελιά) και minions (μικρότερο πορτρέτο) δεν ταιριάζουν με το
## δαχτυλίδι γύρω από το κουτί: στον boss βγαίνει ένα τεράστιο ορθογώνιο, στο
## minion μένει άδειος χώρος ανάμεσα στο πλάσμα και το περίγραμμα.
func uses_burst() -> bool:
	return is_boss or sprite_scale < 0.99


## Η λάμψη ζημιάς για boss και minions: έκρηξη που σκάει ΠΙΣΩ από το πλάσμα —
## ακτίνες από τετράγωνα που τρέχουν προς τα έξω κι ένας δίσκος που φουσκώνει
## και σβήνει, στο χρώμα του δράκου. Όλα πάνω στο πλέγμα των BURST_PX, ώστε να
## διαβάζεται σαν pixel art και όχι σαν θολή λάμψη.
func _draw_burst(psize: Vector2) -> void:
	if burst_t >= 1.0:
		return
	var k := burst_t                                   # 0 -> 1
	var fade := 1.0 - k * k                            # κρατάει, και σβήνει στο τέλος
	# μετριέται από το ΜΙΣΟ του μικρότερου άξονα: έτσι η έκρηξη βγαίνει έξω
	# από το σώμα σε όλες τις πλευρές, αλλιώς στον boss κρυβόταν ολόκληρη
	var reach := minf(psize.x, psize.y) * 0.5
	var hot := burst_color.lerp(Color.WHITE, 0.35)
	var snap := func(v: Vector2) -> Vector2:
		return (v / BURST_PX).floor() * BURST_PX
	# δαχτυλίδι: ξεκινάει στην άκρη του πλάσματος και ανοίγει προς τα έξω
	var r_out := reach * (0.95 + 0.75 * sqrt(k))
	var r_in := r_out - reach * (0.55 - 0.35 * k)
	var n := int(ceil(r_out / BURST_PX))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var q := Vector2(gx, gy) * BURST_PX
			var d := q.length()
			if d > r_out or d < r_in:
				continue
			var edge := clampf((d - r_in) / maxf(r_out - r_in, 1.0), 0.0, 1.0)
			draw_rect(Rect2(q, Vector2(BURST_PX, BURST_PX)),
				Color(hot if edge > 0.55 else burst_color, fade * (0.35 + 0.5 * edge)))
	# ακτίνες: κομμάτια που εκτοξεύονται πέρα από το δαχτυλίδι
	for i in BURST_RAYS:
		var ang := TAU * float(i) / BURST_RAYS + (0.31 if i % 2 else 0.0)
		var dir := Vector2(cos(ang), sin(ang))
		var head := reach * (1.0 + (1.1 if i % 2 == 0 else 0.8) * sqrt(k))
		for st in 4:
			var at := head - float(st) * BURST_PX * 1.5
			var q: Vector2 = snap.call(dir * at)
			var sz := BURST_PX * (2.0 if st == 0 else 1.0)
			draw_rect(Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)),
				Color(hot if st == 0 else burst_color, fade * (1.0 - float(st) * 0.22)))


## Πλαίσιο εννιά κομματιών: οι τέσσερις γωνίες μπαίνουν ατόφιες και οι πλευρές
## επαναλαμβάνονται όσες φορές χρειάζεται, με το τελευταίο κομμάτι κομμένο στο
## μέτρο. Ίδια λογική με το _draw_band() του hud.gd.
func _draw_ring(tex: Texture2D, r: Rect2, alpha: float) -> void:
	var sm := RING_MARGIN
	var dm := sm * RING_SCALE
	var far := RING_SRC - sm
	var col := Color(1, 1, 1, clampf(alpha, 0.0, 1.0))
	# πολύ μικρό κουτί: οι γωνίες θα επικαλύπτονταν, μπαίνει σκέτο το σχέδιο
	if r.size.x < dm * 2.0 or r.size.y < dm * 2.0:
		draw_texture_rect(tex, r, false, col)
		return

	# --- γωνίες
	draw_texture_rect_region(tex, Rect2(r.position, Vector2(dm, dm)),
		Rect2(0, 0, sm, sm), col)
	draw_texture_rect_region(tex, Rect2(Vector2(r.end.x - dm, r.position.y), Vector2(dm, dm)),
		Rect2(far, 0, sm, sm), col)
	draw_texture_rect_region(tex, Rect2(Vector2(r.position.x, r.end.y - dm), Vector2(dm, dm)),
		Rect2(0, far, sm, sm), col)
	draw_texture_rect_region(tex, Rect2(r.end - Vector2(dm, dm), Vector2(dm, dm)),
		Rect2(far, far, sm, sm), col)

	# --- πάνω και κάτω πλευρά
	var step := (RING_SRC - sm * 2.0) * RING_SCALE
	var x := r.position.x + dm
	while x < r.end.x - dm:
		var w := minf(step, r.end.x - dm - x)
		var sw := w / RING_SCALE
		draw_texture_rect_region(tex, Rect2(x, r.position.y, w, dm),
			Rect2(sm, 0, sw, sm), col)
		draw_texture_rect_region(tex, Rect2(x, r.end.y - dm, w, dm),
			Rect2(sm, far, sw, sm), col)
		x += step

	# --- αριστερή και δεξιά πλευρά
	var y := r.position.y + dm
	while y < r.end.y - dm:
		var h := minf(step, r.end.y - dm - y)
		var sh := h / RING_SCALE
		draw_texture_rect_region(tex, Rect2(r.position.x, y, dm, h),
			Rect2(0, sm, sm, sh), col)
		draw_texture_rect_region(tex, Rect2(r.end.x - dm, y, dm, h),
			Rect2(far, sm, sm, sh), col)
		y += step


func _draw() -> void:
	var half := box * 0.5
	var band := minf(box.y * 0.14, 10.0)      # ύψος μπάρας ζωής — μικρή, ο αριθμός μιλάει
	var xf := _appear_xform()
	draw_set_transform(xf.origin, 0.0, xf.get_scale())

	if shield_on or shield_hit_t < 1.0:
		_draw_shield()
	# ούτε περίγραμμα κελιού όσο στήνεται ή σβήνει: θα έδειχνε το κουτί πριν το πλάσμα
	if appear_t >= 1.0 and vanish_t < 0.0:
		_draw_edge()

	# πορτρέτο — αντίδραση σε χτύπημα > idle loop > στατικό sprite
	var portrait := portrait_frame()
	if portrait:
		# το sprite_scale μικραίνει μόνο το πορτρέτο, κεντραρισμένο μέσα στο
		# κελί — το κουτί, το περίγραμμα και οι ενδείξεις μένουν στη θέση τους
		var psize := (box - Vector2(6, 6)) * sprite_scale
		if uses_burst():
			_draw_burst(psize)
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

	if guard_t < 1.0:
		_draw_guard()
	if weak_rect.has_area():
		_draw_weak_point()
	if fuse >= 0:
		_draw_fuse()
	if life_turns >= 0:
		_draw_life_pips()
	if not show_hp:
		if frozen:
			_draw_snowflake()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

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

	if frozen:
		_draw_snowflake()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Τα σύμβολα ικανότητας (## !! *) δεν σχεδιάζονται πια: γέμιζαν το κελί με
	# σημάδια που δεν διάβαζε κανείς. Το badge() μένει στο EnemyAbility — το
	# χρησιμοποιούν τα tests, και είναι εκεί αν ξαναχρειαστεί ένδειξη.


## Ασπίδα γύρω από τον μεγάλο boss: δαχτυλίδι από τετράγωνα 4x4 (2 art
## pixels) που αναπνέει, και αστράφτει άσπρο όταν τη χτυπάει μπάλα.
const SHIELD_COL := Color("ffcf5a")


func _draw_shield() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var flash := 1.0 - shield_hit_t
	# χτύπος σαν τύμπανο: απότομο άναμμα και σβήσιμο, όχι ομαλό ημίτονο
	var beat := pow(1.0 - fmod(t * 1.6, 1.0), 3.0)
	var a := (0.55 + 0.35 * beat) if shield_on else 0.0
	a = maxf(a, flash)
	if a <= 0.01:
		return
	var r := box * 0.5 + Vector2(12, 12)
	var col := SHIELD_COL.lerp(Color.WHITE, flash * 0.8)
	# θόλος: απαλή χρυσή μάζα πίσω από τον πύργο
	draw_texture_rect(Ball.dot_tex(), Rect2(-r, r * 2.0), false, Color(col, 0.10 + 0.10 * beat + flash * 0.2))
	# χείλος: τετράγωνα 6x6/4x4 στο πλέγμα των 2 art pixels, που γυρίζουν αργά
	var n := 96
	for i in n:
		var ang := TAU * float(i) / n + t * 0.5
		var p := Vector2(cos(ang) * r.x, sin(ang) * r.y)
		p = (p / 4.0).floor() * 4.0
		var sz := 6.0 if i % 3 != 0 else 4.0
		draw_rect(Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(col, a))


## Στόχαστρο στο αδύναμο σημείο: τέσσερις γωνίες που πάλλονται. Δείχνει στον
## παίκτη πού αξίζει να σημαδέψει, χωρίς κείμενο.
func _draw_weak_point() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var g := 4.0 + 3.0 * (0.5 + 0.5 * sin(t * 5.0))
	var r := weak_rect.grow(g)
	var L := 12.0
	var col := Color(1.0, 0.35, 0.25, 0.85)
	for cx: int in [0, 1]:
		for cy: int in [0, 1]:
			var c := Vector2(r.position.x + r.size.x * cx, r.position.y + r.size.y * cy)
			var sx := 1.0 if cx == 0 else -1.0
			var sy := 1.0 if cy == 0 else -1.0
			draw_rect(Rect2(c.x + (0.0 if sx > 0 else -L), c.y + (0.0 if sy > 0 else -4.0), L, 4.0), col)
			draw_rect(Rect2(c.x + (0.0 if sx > 0 else -4.0), c.y + (0.0 if sy > 0 else -L), 4.0, L), col)


## Φυτίλι: αριθμός γύρων ως την έκρηξη, που κοκκινίζει και χτυπάει σαν
## καρδιά στον τελευταίο γύρο.
func _draw_fuse() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var last := fuse <= 1
	var col := Color("ff5a3a") if last else Color("ffb347")
	var size := 18 if not last else 18 + int(3.0 * (0.5 + 0.5 * sin(t * 12.0)))
	var pos := Vector2(box.x * 0.5 - 16.0, -box.y * 0.5 + 18.0)
	_draw_outline_text(pos, str(fuse), size, col)


## Οδόφραγμα: κουκκίδες για τους γύρους που του μένουν.
func _draw_life_pips() -> void:
	var n := maxi(life_max, life_turns)
	var w := n * 8.0 - 2.0
	var x0 := -w * 0.5
	var y := box.y * 0.5 - 8.0
	for i in n:
		var on := i < life_turns
		draw_rect(Rect2(x0 + i * 8.0 - 1.0, y - 1.0, 8.0, 8.0), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(x0 + i * 8.0, y, 6.0, 6.0), Color("e8c27a") if on else Color(0.3, 0.25, 0.2, 0.8))


func _pix(ch_: String) -> Color:
	match ch_:
		"G": return Color("6ab04c")
		"S": return Color("9aa3ad")
		"B": return Color("6d5f8c")
		"Y": return Color("f7d060")
		"W": return Color.WHITE
		"K": return Color("15111f")
	return Color.MAGENTA
