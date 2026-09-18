extends Node2D
## BBdragon — κάστρο / πεδίο μάχης
## Όλα τα γραφικά είναι placeholders ζωγραφισμένα με κώδικα.
## Βάλε PNG στο res://art/ με αυτά τα ονόματα και μπαίνουν αυτόματα:
##   dragon.png  goblin.png  knight.png  brute.png  fireball.png

const COLS := 8
const BALL_SPEED := 950.0
const FIRE_GAP := 0.08
const PF_W := 600.0           # σταθερό πλάτος πεδίου (8 × 75) ώστε τα κελιά να μένουν τετράγωνα
const BORDER := 60.0          # πάχος πέτρινου πλαισίου αριστερά/δεξιά
const PF_TOP := 190.0         # πάνω όριο πεδίου παιχνιδιού
const DEATH_GAP := 218.0      # απόσταση γραμμής θανάτου από την κάτω άκρη
const UI_BAND := 142.0        # ύψος κάτω μπάρας χειριστηρίων
const HUD_BAND := 154.0       # ύψος πάνω μπάρας (score / round / power-up)
const TRIPLE_TURNS := 3       # διάρκεια Triple Shot σε γύρους
const HP_TIERS := [0.5, 0.75, 1.0, 1.0, 1.25, 1.75]
const TIER_KIND := ["goblin", "goblin", "orc", "knight", "brute", "warlock"]
const PTS_HIT := 5
const PTS_KILL := 25
const SAVE_PATH := "user://best.dat"

const BlockScene := preload("res://block.tscn")
const BallScene := preload("res://ball.tscn")
const OrbScene := preload("res://orb.tscn")

var W := 0.0
var H := 0.0
var cell := 0.0
var pf_left := 0.0
var pf_right := 0.0
var floor_y := 0.0
var ui_top := 0.0

var phase := "aim"
var paused := false
var score := 0
var level := 1
var ball_count := 1
var gained := 0
var launch_x := 0.0
var next_x := -1.0
var aim_dir := Vector2.UP
var aiming := false
var to_fire := 0
var fire_timer := 0.0
var shot_time := 0.0
var live_balls := 0
var triple_turns := 0
var best := 0
var t := 0.0

var art := {}
var font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # για να δουλεύει το κουμπί παύσης
	font = ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	W = vs.x
	H = vs.y
	cell = PF_W / float(COLS)
	pf_left = (W - PF_W) * 0.5
	pf_right = pf_left + PF_W
	floor_y = H - DEATH_GAP
	ui_top = H - UI_BAND
	launch_x = W * 0.5
	_load_art()
	_build_walls()
	_load_best()
	_start()


func _load_art() -> void:
	for key in ["dragon", "goblin", "orc", "knight", "brute", "warlock", "fireball", "background"]:
		var p := "res://art/%s.png" % key
		if ResourceLoader.exists(p):
			art[key] = load(p)


func tex(key: String) -> Texture2D:
	if art.has(key):
		var r: Texture2D = art[key]
		return r
	return null


# ---------------------------------------------------------------- setup

func _build_walls() -> void:
	_wall(Vector2(pf_left - 100.0, H * 0.5), Vector2(200.0, H * 3.0))
	_wall(Vector2(pf_right + 100.0, H * 0.5), Vector2(200.0, H * 3.0))
	_wall(Vector2(W * 0.5, PF_TOP - 106.0), Vector2(W * 3.0, 200.0))


func _wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	add_child(body)


func _start() -> void:
	Engine.time_scale = 1.0
	paused = false
	get_tree().paused = false
	for g in ["block", "orb", "ball"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()
	score = 0
	level = 1
	ball_count = 1
	gained = 0
	live_balls = 0
	to_fire = 0
	next_x = -1.0
	triple_turns = 0
	launch_x = W * 0.5
	phase = "aim"
	_add_row()


# ---------------------------------------------------------------- grid

func cell_pos(c: int, row: int) -> Vector2:
	return Vector2(pf_left + c * cell + cell * 0.5, PF_TOP + row * cell + cell * 0.5)


func _add_row() -> void:
	var free_cols: Array[int] = []
	var placed := 0
	for c in COLS:
		if randf() < 0.62:
			_spawn_block(c)
			placed += 1
		else:
			free_cols.append(c)
	if placed == 0:
		var idx := randi() % free_cols.size()
		_spawn_block(free_cols[idx])
		free_cols.remove_at(idx)
	if free_cols.size() > 0 and randf() < 0.85:
		var k := "ball"
		if randf() < 0.12:
			k = "triple"
		_spawn_orb(free_cols[randi() % free_cols.size()], k)


func _spawn_block(c: int) -> void:
	var i := randi() % HP_TIERS.size()
	var f: float = HP_TIERS[i]
	var hp := maxi(1, int(roundf(level * f)))
	var kind: String = TIER_KIND[i]
	var b := BlockScene.instantiate()
	add_child(b)
	b.add_to_group("block")
	b.setup(hp, cell - 6.0, kind, tex(kind))
	b.row = 0
	b.position = cell_pos(c, 0)
	b.damaged.connect(_on_block_damaged)


func _spawn_orb(c: int, kind: String) -> void:
	var o := OrbScene.instantiate()
	add_child(o)
	o.add_to_group("orb")
	o.kind = kind
	o.row = 0
	o.position = cell_pos(c, 0)
	o.body_entered.connect(_on_orb_taken.bind(o))


func _on_orb_taken(_body: Node, orb: Node) -> void:
	if not is_instance_valid(orb):
		return
	if orb.kind == "triple":
		triple_turns = TRIPLE_TURNS
	else:
		gained += 1
	orb.queue_free()


func _on_block_damaged(destroyed: bool) -> void:
	score += PTS_KILL if destroyed else PTS_HIT


# ---------------------------------------------------------------- input


func frame_left() -> float:
	return pf_left - BORDER


func frame_right() -> float:
	return pf_right + BORDER


func pause_rect() -> Rect2:
	return Rect2(frame_right() - 84.0, 16.0, 56.0, 56.0)


func fireball_rect() -> Rect2:
	return Rect2(frame_right() - 120.0, ui_top + 10.0, 86.0, 86.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if phase == "aim" and aiming:
			_set_aim(get_global_mouse_position())
		return

	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var p := get_global_mouse_position()
	if mb.pressed and pause_rect().has_point(p):
		_toggle_pause()
		return
	if paused:
		return
	# πατήματα στην κάτω μπάρα χειριστηρίων δεν ξεκινούν στόχευση
	if mb.pressed and p.y >= ui_top:
		return

	match phase:
		"aim":
			if mb.pressed:
				aiming = true
				_set_aim(get_global_mouse_position())
			elif aiming:
				aiming = false
				_fire()
		"shoot":
			if mb.pressed:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.0 else 3.0
		"over":
			if mb.pressed:
				_start()


func _toggle_pause() -> void:
	if phase == "over":
		return
	paused = not paused
	get_tree().paused = paused


func _set_aim(p: Vector2) -> void:
	var d := p - Vector2(launch_x, floor_y - 18.0)
	if d.y > -20.0:
		d.y = -20.0
	d = d.normalized()
	var min_y := 0.2
	if -d.y < min_y:
		var sx := 1.0 if d.x >= 0.0 else -1.0
		d = Vector2(sx * sqrt(1.0 - min_y * min_y), -min_y)
	aim_dir = d


func _fire() -> void:
	phase = "shoot"
	to_fire = ball_count
	fire_timer = 0.0
	shot_time = 0.0
	next_x = -1.0
	gained = 0
	live_balls = 0
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if paused or phase != "shoot":
		return
	shot_time += delta
	if shot_time > 9.0:
		Engine.time_scale = 3.0
	if to_fire > 0:
		fire_timer -= delta
		while to_fire > 0 and fire_timer <= 0.0:
			_shoot_once()
			to_fire -= 1
			fire_timer += FIRE_GAP


func _shoot_once() -> void:
	if triple_turns > 0:
		for a in PackedFloat32Array([-0.13, 0.0, 0.13]):
			_make_ball(aim_dir.rotated(a))
	else:
		_make_ball(aim_dir)


func _make_ball(dir: Vector2) -> void:
	var b := BallScene.instantiate()
	add_child(b)
	b.add_to_group("ball")
	b.position = Vector2(launch_x, floor_y - 18.0)
	b.velocity = dir * BALL_SPEED
	b.speed = BALL_SPEED
	b.floor_y = floor_y
	b.sprite = tex("fireball")
	b.died.connect(_on_ball_died)
	live_balls += 1


func _on_ball_died(x: float) -> void:
	if next_x < 0.0:
		next_x = clampf(x, pf_left + 20.0, pf_right - 20.0)
	live_balls -= 1
	if live_balls <= 0 and to_fire == 0:
		_end_turn()


func _end_turn() -> void:
	Engine.time_scale = 1.0
	ball_count += gained
	if next_x >= 0.0:
		launch_x = next_x
	level += 1
	if triple_turns > 0:
		triple_turns -= 1

	var tween := create_tween()
	tween.set_parallel(true)
	for b in get_tree().get_nodes_in_group("block"):
		b.row += 1
		tween.tween_property(b, "position:y", cell_pos(0, b.row).y, 0.18)
	for o in get_tree().get_nodes_in_group("orb"):
		o.row += 1
		if cell_pos(0, o.row).y > floor_y - 10.0:
			o.queue_free()
		else:
			tween.tween_property(o, "position:y", cell_pos(0, o.row).y, 0.18)

	for b in get_tree().get_nodes_in_group("block"):
		if cell_pos(0, b.row).y + cell * 0.5 >= floor_y:
			_game_over()
			return

	_add_row()
	phase = "aim"


func _game_over() -> void:
	phase = "over"
	paused = false
	get_tree().paused = false
	if score > best:
		best = score
		_save_best()


# ---------------------------------------------------------------- save

func _load_best() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			best = f.get_32()


func _save_best() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_32(best)


# ---------------------------------------------------------------- draw

func _draw() -> void:
	_draw_sky()
	_draw_frame()
	_draw_torches()
	_draw_ground()
	_draw_dragon()
	_draw_aim()
	_draw_hud()
	if phase == "over":
		_draw_over()


func _draw_sky() -> void:
	# αν υπάρχει εικόνα φόντου, γεμίζει το πεδίο παιχνιδιού και παραλείπει τα placeholder
	var bg := tex("background")
	if bg:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("141024"))
		draw_texture_rect(bg, Rect2(pf_left, PF_TOP, pf_right - pf_left, floor_y - PF_TOP), false)
		for c in range(1, COLS):
			var gx := pf_left + c * cell
			draw_line(Vector2(gx, PF_TOP), Vector2(gx, floor_y), Color(1, 1, 1, 0.045), 1.0)
		return

	# ουρανός
	var steps := 14
	for i in steps:
		var f := float(i) / float(steps)
		var col := Color("1a1b3a").lerp(Color("3d2a4f"), f)
		draw_rect(Rect2(0, H * f * 0.75, W, H * 0.75 / steps + 1.0), col)
	# βουνά
	var m1 := PackedVector2Array([
		Vector2(-20, floor_y - 160), Vector2(W * 0.28, floor_y - 460),
		Vector2(W * 0.62, floor_y - 160)])
	draw_polygon(m1, PackedColorArray([Color("2b2f55"), Color("2b2f55"), Color("2b2f55")]))
	var m2 := PackedVector2Array([
		Vector2(W * 0.40, floor_y - 160), Vector2(W * 0.78, floor_y - 380),
		Vector2(W + 20, floor_y - 160)])
	draw_polygon(m2, PackedColorArray([Color("343a63"), Color("343a63"), Color("343a63")]))
	# γρασίδι
	draw_rect(Rect2(0, floor_y - 170, W, 170), Color("23402f"))
	# πλέγμα πεδίου
	for c in range(1, COLS):
		var x := pf_left + c * cell
		draw_line(Vector2(x, PF_TOP), Vector2(x, floor_y), Color(1, 1, 1, 0.045), 1.0)


func _draw_frame() -> void:
	var stone := Color("58596e")
	var dark := Color("3a3b4e")
	var bh := 30.0
	var top := PF_TOP - 36.0
	# κολόνες αριστερά/δεξιά — μόνο γύρω από το πεδίο, όχι πάνω από το HUD
	for side in 2:
		var x0 := frame_left() if side == 0 else pf_right
		draw_rect(Rect2(x0, top, BORDER, H - top), dark)
		var row := 0
		var y := top
		while y < H:
			var off := 0.0 if row % 2 == 0 else 8.0
			draw_rect(Rect2(x0 + 4.0 + off * 0.3, y + 3.0, BORDER - 10.0, bh - 6.0), stone)
			y += bh
			row += 1
	# στέψη πάνω από το πεδίο
	draw_rect(Rect2(frame_left(), top, frame_right() - frame_left(), 36.0), dark)
	var x2 := frame_left()
	while x2 < frame_right():
		draw_rect(Rect2(x2 + 5.0, top + 4.0, 44.0, 28.0), stone)
		x2 += 58.0


func _draw_torches() -> void:
	var flick := 1.0 + sin(t * 9.0) * 0.12
	for side in 2:
		var x := BORDER * 0.5 if side == 0 else W - BORDER * 0.5
		var y := floor_y - 430.0
		draw_rect(Rect2(x - 4.0, y, 8.0, 34.0), Color("4a3524"))
		draw_circle(Vector2(x, y - 4.0), 26.0 * flick, Color(1.0, 0.55, 0.15, 0.20))
		draw_circle(Vector2(x, y - 6.0), 11.0 * flick, Color("ff9e2c"))
		draw_circle(Vector2(x, y - 10.0), 6.0 * flick, Color("ffe9a8"))


func _draw_ground() -> void:
	# έδαφος κάτω από το πεδίο
	draw_rect(Rect2(0, floor_y, W, H - floor_y), Color("2c2d3f"))
	# επάλξεις
	var i := 0
	var x := 0.0
	while x < W:
		if i % 2 == 0:
			draw_rect(Rect2(x, floor_y + 6.0, 54.0, 46.0), Color("4e4f63"))
		x += 62.0
		i += 1
	draw_rect(Rect2(0, floor_y + 52.0, W, H - floor_y - 52.0), Color("42435a"))
	# γραμμή θανάτου
	draw_line(Vector2(pf_left, floor_y), Vector2(pf_right, floor_y), Color(1, 0.4, 0.3, 0.25), 2.0)


func _draw_dragon() -> void:
	# ο δράκος πατάει πάνω στη γραμμή θανάτου (κάτω άκρη του πεδίου)
	var base := Vector2(launch_x, floor_y)

	var dt := tex("dragon")
	if dt:
		var w := 120.0
		var h := w * float(dt.get_height()) / float(dt.get_width())
		draw_texture_rect(dt, Rect2(base.x - w * 0.5, base.y - h, w, h), false)
		return

	# placeholder: μικρός δράκος με pixel
	var px := 7.0
	var map := [
		"......RR....",
		".WW..RRRR...",
		".WWW.RRERR..",
		".WWWWRRRRRR.",
		"..WWRRRRRR..",
		"...RRRRRR...",
		"..T.RR.RR...",
		"....RR.RR..."
	]
	var o := base + Vector2(-map[0].length() * px * 0.5, -map.size() * px)
	for r in map.size():
		var line: String = map[r]
		for c in line.length():
			var ch := line[c]
			if ch == ".":
				continue
			var col := Color("d4453a")
			if ch == "W":
				col = Color("a33028")      # φτερό
			elif ch == "E":
				col = Color.WHITE          # μάτι
			elif ch == "T":
				col = Color("8e2a22")      # ουρά
			draw_rect(Rect2(o + Vector2(c * px, r * px), Vector2(px, px)), col)


func _draw_aim() -> void:
	if phase != "aim" or not aiming:
		return
	var p := Vector2(launch_x, floor_y - 18.0)
	var v := aim_dir
	for i in 64:
		p += v * 16.0
		if p.x < pf_left + 8.0 or p.x > pf_right - 8.0:
			v.x = -v.x
			p.x = clampf(p.x, pf_left + 8.0, pf_right - 8.0)
		if p.y < PF_TOP:
			break
		if i % 2 == 0:
			draw_circle(p, 3.0, Color(1.0, 0.75, 0.35, 0.7))


func _draw_hud() -> void:
	# ---------------- πάνω μπάρα: SCORE αριστερά, ROUND δεξιά, παύση στη γωνία
	draw_rect(Rect2(0, 0, W, HUD_BAND), Color("15162b"))
	draw_string(font, Vector2(frame_left() + 24.0, 58.0), "SCORE: %d" % score,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("fff2cf"))
	draw_string(font, Vector2(frame_right() - 400.0, 58.0), "ROUND: %d" % level,
		HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 34, Color("fff2cf"))

	var pr := pause_rect()
	draw_rect(pr, Color("2a2740"))
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size - Vector2(6, 6)), Color("3b3757"))
	draw_rect(Rect2(pr.position.x + 18.0, pr.position.y + 15.0, 6.0, 26.0), Color("e8e2f2"))
	draw_rect(Rect2(pr.position.x + 32.0, pr.position.y + 15.0, 6.0, 26.0), Color("e8e2f2"))

	# ---------------- μπάνερ power-up με μπάρα διάρκειας
	if triple_turns > 0:
		var bw := 288.0
		var r := Rect2(W * 0.5 - bw * 0.5, 86.0, bw, 78.0)
		draw_rect(r, Color("1d1b2e"))
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color("2a2740"))
		var f := float(triple_turns) / float(TRIPLE_TURNS)
		var bar := Rect2(r.position.x + 16.0, r.position.y + 16.0, 10.0, r.size.y - 32.0)
		draw_rect(bar, Color("15162b"))
		draw_rect(Rect2(bar.position.x, bar.position.y + bar.size.y * (1.0 - f),
			bar.size.x, bar.size.y * f), Color("6fc3ff"))
		draw_circle(Vector2(r.position.x + 56.0, r.position.y + 39.0), 16.0, Color("ff9e2c"))
		draw_string(font, Vector2(r.position.x + 82.0, r.position.y + 50.0), "Triple Shot",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffe1ad"))
		draw_string(font, Vector2(r.position.x, r.position.y - 12.0), "POWER-UP",
			HORIZONTAL_ALIGNMENT_CENTER, bw, 22, Color("ffb35c"))

	# ---------------- κάτω μπάρα χειριστηρίων
	draw_rect(Rect2(0, ui_top, W, H - ui_top), Color("15162b"))

	# μετρητής μπαλών (κάτω αριστερά)
	var shown := (live_balls + to_fire) if phase == "shoot" else ball_count
	var bc := Vector2(frame_left() + 78.0, ui_top + 56.0)
	draw_circle(bc, 38.0, Color("2a2740"))
	draw_circle(bc, 34.0, Color("1d1b2e"))
	draw_string(font, Vector2(bc.x - 40.0, bc.y + 11.0), "x%d" % shown,
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 30, Color("ffd98a"))

	# κουμπί FIREBALL — placeholder, δεν κάνει τίποτα ακόμα
	var fr := fireball_rect()
	draw_rect(fr, Color("2a2740"))
	draw_rect(Rect2(fr.position + Vector2(3, 3), fr.size - Vector2(6, 6)), Color("1d1b2e"))
	draw_circle(fr.position + fr.size * 0.5, 24.0, Color("6fc3ff"))
	draw_string(font, Vector2(fr.position.x - 22.0, fr.end.y + 24.0), "FIREBALL",
		HORIZONTAL_ALIGNMENT_CENTER, fr.size.x + 44.0, 20, Color("c9c2d6"))

	if phase == "aim" and not aiming:
		draw_string(font, Vector2(0, ui_top + 66.0), "σύρε για στόχευση",
			HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(1, 1, 1, 0.35))

	if paused:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.72))
		draw_string(font, Vector2(0, H * 0.46), "ΠΑΥΣΗ",
			HORIZONTAL_ALIGNMENT_CENTER, W, 56, Color("ffb35c"))


func _draw_over() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.82))
	draw_string(font, Vector2(0, H * 0.44), "GAME OVER",
		HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color("ff9b3d"))
	draw_string(font, Vector2(0, H * 0.44 + 58.0),
		"SCORE %d  •  ROUND %d  •  ρεκόρ %d" % [score, level, best],
		HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color("9b93ad"))
	draw_string(font, Vector2(0, H * 0.44 + 126.0), "tap για νέο παιχνίδι",
		HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.5))
