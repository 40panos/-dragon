extends Node2D
## Το HUD ζει σε CanvasLayer ώστε να σχεδιάζεται πάντα πάνω από εχθρούς και μπάλες.
## Διαβάζει κατάσταση από το main· δεν κρατάει δική του.
##
## Όλα τα γραφικά του είναι σε art pixels και δείχνονται x2, όπως ο δράκος.
## Οι θέσεις των κουμπιών βγαίνουν από το main (pause_rect, dragon_rect κ.λπ.),
## από τις ίδιες συναρτήσεις που ελέγχουν και τα πατήματα. Το φόντο της κάτω
## μπάρας (τείχος και πάνελ) το ζωγραφίζει το main, πίσω από τον δράκο.

const TOP := preload("res://art/hud_top.png")          # δοκάρι πάνω σε πέτρα, 3-slice
const PLATE := preload("res://art/hud_plate.png")      # κρεμαστή πινακίδα
const BTN := preload("res://art/hud_btn.png")          # μενού / παύση
const SKULL := preload("res://art/hud_skull.png")      # πόσο απέχει ο boss
const MEDAL := preload("res://art/hud_medal.png")      # επιλογή δράκου, τρύπα στη μέση
const MEDAL_HOLE := preload("res://art/hud_medal_hole.png")  # μάσκα της τρύπας
const CLAW := preload("res://art/hud_claw.png")        # το special

const BONE := Color("eadfc4")
const DIM := Color("a89f8a")
const GOLD := Color("ffd98a")
const INK := Color("100c10")

var m
## Πορτρέτο κάθε δράκου κομμένο στο σχήμα της τρύπας του μεταλλίου. Φτιάχνεται
## μία φορά ανά δράκο, στο _process: ένα texture που γεννιέται μέσα στο
## _draw() δεν έχει προλάβει να ανέβει και βγαίνει λευκό.
var _portraits := {}


func _process(_delta: float) -> void:
	if m and m.dragon and not _portraits.has(m.dragon.id):
		_portraits[m.dragon.id] = _make_portrait(m.dragon)
	queue_redraw()


func _make_portrait(d: DragonType) -> Texture2D:
	var src: Texture2D = d.frame_for("aim", false, 0.0)
	if src == null:
		return null
	var por := src.get_image()
	por.convert(Image.FORMAT_RGBA8)
	var hole := MEDAL_HOLE.get_image()
	hole.convert(Image.FORMAT_RGBA8)
	var box := hole.get_used_rect()
	# το κέντρο του κεφαλιού, λίγο ψηλότερα από τη μέση του καρέ, στο κέντρο της τρύπας
	var off := Vector2i(por.get_width() / 2, por.get_height() / 2 - 2) \
		- (box.position + box.size / 2)
	var out := Image.create(hole.get_width(), hole.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if hole.get_pixel(x, y).a < 0.5:
				continue
			var col := Color("140f12")
			var p := Vector2i(x, y) + off
			if p.x >= 0 and p.y >= 0 and p.x < por.get_width() and p.y < por.get_height():
				var pc := por.get_pixelv(p)
				if pc.a > 0.5:
					col = pc
			out.set_pixel(x, y, col)
	return ImageTexture.create_from_image(out)


## Εικόνα σε x2 με την πάνω αριστερή γωνία στο p.
func _put(t: Texture2D, p: Vector2, tint := Color.WHITE) -> Rect2:
	var r := Rect2(p, t.get_size() * 2.0)
	draw_texture_rect(t, r, false, tint)
	return r


## Κείμενο στο κέντρο πλάτους w. Τα μεγάλα παίρνουν σκούρο περίγραμμα, τα μικρά
## (προαιρετικά) σκούρο φόντο — αλλιώς χάνονται πάνω στην πέτρα.
func _text(p: Vector2, w: float, s: String, size: int, col: Color, backing := false) -> void:
	var font: Font = m.font
	if size >= 22:
		draw_string_outline(font, p, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, 4, INK)
	elif backing:
		var tw := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_rect(Rect2(p.x + (w - tw) * 0.5 - 6.0, p.y - size + 2.0, tw + 12.0, size + 6.0),
			Color(0.06, 0.05, 0.07, 0.85))
	draw_string(font, p, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


func _draw() -> void:
	if m == null:
		return
	var font: Font = m.font
	var W: float = m.W
	var H: float = m.H
	_draw_top()
	_draw_bottom()

	if m.phase == "aim" and not m.aiming:
		draw_string(font, Vector2(0, m.floor_y - 190.0), "DRAG TO AIM",
			HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1, 0.30))

	# ---------------- ανακοινώσεις
	if m.banner != "":
		var alpha := clampf(m.banner_time, 0.0, 1.0)
		var plate := Rect2(m.frame_left(), m.PF_TOP + 26.0,
			m.frame_right() - m.frame_left(), 50.0)
		draw_rect(plate, Color(0.06, 0.05, 0.10, 0.88 * alpha))
		draw_string(font, Vector2(0, plate.position.y + 35.0), m.banner,
			HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1.0, 0.72, 0.36, alpha))

	if m.picker_open:
		_draw_picker(font)

	if m.paused:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.72))
		draw_string(font, Vector2(0, H * 0.46), "PAUSED",
			HORIZONTAL_ALIGNMENT_CENTER, W, 56, Color("ffb35c"))

	if m.phase == "over":
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.82))
		draw_string(font, Vector2(0, H * 0.44), "GAME OVER",
			HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color("ff9b3d"))
		draw_string(font, Vector2(0, H * 0.44 + 58.0),
			"SCORE %d  /  ROUND %d  /  BEST %d" % [m.score, m.level, int(m.save.get("best_score", 0))],
			HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color("9b93ad"))
		draw_string(font, Vector2(0, H * 0.44 + 126.0), "TAP TO RESTART",
			HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.5))


## Εικόνα δράκου μέσα σε κουτί, με σωστή αναλογία.
func _draw_portrait(d: DragonType, box: Rect2, alpha: float) -> void:
	var tex: Texture2D = d.frame_for("aim", false, m.t)
	if tex == null:
		draw_circle(box.get_center(), minf(box.size.x, box.size.y) * 0.3, Color(0.83, 0.27, 0.23, alpha))
		return
	var ts := tex.get_size()
	var s := minf(box.size.x / ts.x, box.size.y / ts.y)
	var size := ts * s
	var tint: Color = d.tint
	tint.a *= alpha
	draw_texture_rect(tex, Rect2(box.get_center() - size * 0.5, size), false, tint)


func _draw_picker(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(m.W, m.H)), Color(0.04, 0.03, 0.06, 0.70))
	var panel: Rect2 = m.picker_panel_rect()
	draw_rect(panel, Color("2a2740"))
	draw_rect(panel.grow(-3.0), Color("15162b"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), "CHOOSE DRAGON",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 32, Color("ffe1ad"))

	for i in m.dragons.size():
		var d: DragonType = m.dragons[i]
		var card: Rect2 = m.picker_card_rect(i)
		var unlocked: bool = m.is_dragon_unlocked(d)
		var current: bool = d == m.dragon
		draw_rect(card, Color("ff9e2c") if current else Color("2a2740"))
		draw_rect(card.grow(-3.0), Color("262440") if unlocked else Color("1a1929"))

		var a := 1.0 if unlocked else 0.25
		_draw_portrait(d, Rect2(card.position + Vector2(12, 12), Vector2(card.size.x - 24.0, 110.0)), a)

		var x := card.position.x + 6.0
		var w := card.size.x - 12.0
		var y := card.position.y + 150.0
		draw_string(font, Vector2(x, y), d.display_name, HORIZONTAL_ALIGNMENT_CENTER, w, 24,
			Color(1.0, 0.95, 0.81, 1.0 if unlocked else 0.5))

		if unlocked:
			draw_string(font, Vector2(x, y + 28.0), "%s - %d kills" % [d.special_name(), int(d.special_cost)],
				HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color("6fc3ff"))
			draw_string(font, Vector2(x, y + 50.0), d.special_desc(),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("c9c2d6"))
			draw_string(font, Vector2(x, y + 72.0), d.passive_desc(),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("9b93ad"))
		else:
			draw_string(font, Vector2(x, y + 32.0), "LOCKED",
				HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color("ff9b3d"))
			draw_string(font, Vector2(x, y + 56.0), "beat the boss of:",
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("9b93ad"))
			draw_string(font, Vector2(x, y + 76.0), _unlock_area_name(d),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("c9c2d6"))

	draw_string(font, Vector2(panel.position.x, panel.end.y - 18.0), "tap outside to close",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Color(1, 1, 1, 0.4))


func _unlock_area_name(d: DragonType) -> String:
	var idx := d.unlock_after_area - 1
	if idx >= 0 and idx < m.areas.size():
		return m.areas[idx].display_name
	return "area %d" % d.unlock_after_area


# ---------------------------------------------------------------- πάνω μπάρα

func _draw_top() -> void:
	var fl: float = m.frame_left()
	var fr: float = m.frame_right()
	var cx := (fl + fr) * 0.5
	var top: float = m.PF_TOP - 36.0

	# δοκάρι πάνω σε πέτρα, από άκρη σε άκρη· από πάνω του σκοτάδι
	var ty := top - TOP.get_height() * 2.0
	draw_rect(Rect2(0, 0, m.W, ty + 4.0), Color("141216"))
	m.strip2(self, TOP, Rect2(Vector2.ZERO, TOP.get_size()), 0.0, m.W, ty)

	# μενού και παύση στις πάνω γωνίες
	var mr: Rect2 = m.menu_rect()
	draw_texture_rect(BTN, mr, false)
	var mc := mr.get_center()
	for i in 3:
		draw_rect(Rect2(mc.x - 12.0, mc.y - 9.0 + i * 8.0, 24.0, 4.0), BONE)
	var pr: Rect2 = m.pause_rect()
	draw_texture_rect(BTN, pr, false)
	var pc := pr.get_center()
	draw_rect(Rect2(pc.x - 10.0, pc.y - 11.0, 7.0, 22.0), BONE)
	draw_rect(Rect2(pc.x + 3.0, pc.y - 11.0, 7.0, 22.0), BONE)

	# δύο κρεμαστές πινακίδες: περιοχή και γύρος
	var pw := PLATE.get_width() * 2.0
	var py := top - PLATE.get_height() * 2.0 - 10.0
	var area = m.current_area()
	var labels := [
		area.display_name.to_upper() if area else "",
		"ROUND %d / %d" % [m.area_round(), m.ROUNDS_PER_AREA],
	]
	for side in 2:
		var r := _put(PLATE, Vector2(fl + 24.0 if side == 0 else fr - 24.0 - pw, py))
		_text(Vector2(r.position.x, r.get_center().y + 12.0), r.size.x, labels[side], 20, BONE)

	# στη μέση: ζωή του boss όσο ζει, αλλιώς πόσο απέχει
	var gap_l := fl + 24.0 + pw + 12.0
	var gap_r := fr - 24.0 - pw - 12.0
	if m.boss != null and is_instance_valid(m.boss):
		var br := Rect2(gap_l, py + 14.0, gap_r - gap_l, 22.0)
		draw_rect(br.grow(2.0), INK)
		draw_rect(br, Color("2a1420"))
		var bf: float = clampf(m.boss.hp / maxf(m.boss.max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(br.position, Vector2(br.size.x * bf, br.size.y)), Color("d4453a"))
		draw_rect(Rect2(br.position, Vector2(br.size.x * bf, 5.0)), Color("f07a5a"))
		_text(Vector2(br.position.x, br.end.y + 30.0), br.size.x, "BOSS", 20, Color("ffd7c2"), true)
		return
	_put(SKULL, Vector2(cx - SKULL.get_width(), py - 4.0))
	var left: int = m.ROUNDS_PER_AREA - m.area_round()
	var msg := "BOSS NEXT" if left <= 0 else "BOSS IN %d" % left
	var col := DIM
	if m.triple_turns > 0:
		# το power-up καλύπτει προσωρινά την ένδειξη του boss
		msg = "TRIPLE SHOT %d" % m.triple_turns
		col = Color("6fc3ff")
	_text(Vector2(cx - 100.0, py + 70.0), 200.0, msg, 20, col, true)


# ---------------------------------------------------------------- κάτω μπάρα

func _draw_bottom() -> void:
	var locked: bool = m.controls_locked()
	var lock_tint := Color(0.45, 0.45, 0.48) if locked else Color.WHITE
	var lr: Rect2 = m.hud_panel_rect(false)
	var rr: Rect2 = m.hud_panel_rect(true)

	# ---- αριστερά: ο δράκος
	var dr: Rect2 = m.dragon_rect()
	var usable: bool = m.can_switch_dragon()
	var dtint := Color.WHITE if usable else Color(0.55, 0.55, 0.6)
	if m.new_dragon:
		# παλμός ώστε να φαίνεται ότι κάτι καινούριο περιμένει
		var glow := 0.5 + 0.5 * sin(m.t * 6.0)
		draw_circle(dr.get_center() + Vector2(0, -6), 50.0 + glow * 4.0,
			Color(1.0, 0.62, 0.18, 0.20 + glow * 0.2))
	if m.dragon and _portraits.get(m.dragon.id):
		draw_texture_rect(_portraits[m.dragon.id], dr, false, dtint)
	draw_texture_rect(MEDAL, dr, false, dtint)
	if m.new_dragon:
		_text(Vector2(dr.position.x, dr.end.y - 16.0), dr.size.x, "NEW!", 20, Color("ffb35c"))

	# όνομα και το passive: πόσο κοντά είναι στο επόμενο «χτύπημά» του
	var ix: float = m.hud_socket(false).x + 70.0
	var iw := lr.end.x - ix - 26.0
	if m.dragon:
		_text(Vector2(ix, lr.position.y + lr.size.y * 0.50), iw,
			m.dragon.display_name.to_upper(), 22, BONE)
		var xr := Rect2(ix + 6.0, lr.position.y + lr.size.y * 0.60, iw - 12.0, 10.0)
		var f: float = clampf(m.passive_progress(), 0.0, 1.0)
		draw_rect(xr.grow(2.0), Color("0e0c10"))
		draw_rect(xr, Color("262030"))
		draw_rect(Rect2(xr.position, Vector2(xr.size.x * f, xr.size.y)), m.dragon.accent.darkened(0.15))
		draw_rect(Rect2(xr.position, Vector2(xr.size.x * f, 3.0)), m.dragon.accent.lightened(0.3))
		_text(Vector2(ix - 10.0, lr.position.y + lr.size.y * 0.80), iw + 20.0,
			m.dragon.passive_desc(), 18, DIM)

	# ---- δεξιά: βολή
	var ar: Rect2 = m.aoe_rect()
	var shown: int = (m.live_balls + m.to_fire) if m.phase == "shoot" else m.ball_count
	_text(Vector2(ar.position.x, rr.position.y + rr.size.y * 0.50), ar.size.x,
		"x%d" % shown, 26, GOLD)
	var hw := ar.size.x * 0.5
	for k in 2:
		var on: bool = m.aoe_mode == (k == 1)
		var tr := Rect2(ar.position.x + k * hw + 4.0, ar.position.y, hw - 8.0, ar.size.y)
		draw_rect(tr.grow(2.0), Color("0e0c10"))
		draw_rect(tr, (Color("5a3a1c") if on else Color("221d28")) * lock_tint)
		draw_string(m.font, Vector2(tr.position.x, tr.end.y - 11.0), "AOE" if k == 1 else "SINGLE",
			HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 20, (GOLD if on else DIM) * lock_tint)

	# special: δαχτυλίδι φόρτισης μέσα στα νύχια, το βλήμα στη μέση
	var sr: Rect2 = m.special_rect()
	var ready: bool = m.special_ready()
	draw_texture_rect(CLAW, sr, false, lock_tint)
	var sc := sr.get_center()
	var rad := sr.size.x * 0.27
	var charge := 0.0
	if m.dragon:
		charge = clampf(m.special_charge / maxf(m.dragon.special_cost, 1.0), 0.0, 1.0)
	var accent: Color = m.dragon.accent if m.dragon else Color("f08a2a")
	draw_arc(sc, rad, 0.0, TAU, 48, Color("2b2230"), 8.0)
	if charge > 0.0:
		draw_arc(sc, rad, -PI * 0.5, -PI * 0.5 + TAU * charge, 48, accent * lock_tint, 8.0)
	if ready and not locked:
		draw_circle(sc, rad + 10.0 + sin(m.t * 6.0) * 2.0, Color(accent, 0.13))
	var shot: Texture2D = m.ball_tex(false)
	if shot:
		var itint := Color.WHITE if ready else Color(0.44, 0.40, 0.46)
		draw_texture_rect(shot, Rect2(sc - Vector2(26, 26), Vector2(52, 52)), false, itint * lock_tint)
	_text(Vector2(sr.position.x - 20.0, rr.position.y + rr.size.y * 0.94), sr.size.x + 40.0,
		m.dragon.special_name() if m.dragon else "SPECIAL", 20,
		(GOLD if ready else BONE) * lock_tint, true)
