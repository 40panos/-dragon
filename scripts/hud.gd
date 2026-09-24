extends Node2D
## Το HUD ζει σε CanvasLayer ώστε να σχεδιάζεται πάντα πάνω από εχθρούς και μπάλες.
## Διαβάζει κατάσταση από το main· δεν κρατάει δική του.

## Πλακίδια κουμπιών από το ui_buttons. Σχεδιάζονται σε ακέραιο πολλαπλάσιο
## του φυσικού τους μεγέθους (βλ. main.pause_rect / aoe_rect / special_rect),
## ώστε να μη χρειάζεται αναδειγματοληψία.
const PLATE_SQ := preload("res://art/ui_plate_sq.png")          # 45x45, μπαίνει 2x
const PLATE_PAUSE := preload("res://art/ui_plate_pause.png")    # 57x57, μπαίνει 1x
const PLATE_ROUND := preload("res://art/ui_plate_round.png")    # 73x73, μπαίνει 1x
const PLATE_LABEL := preload("res://art/ui_plate_label.png")    # 192x64, πινακίδα κειμένου
const BAND := preload("res://art/ui_band.png")                  # 64x64, υφή για τις μπάρες
const BTN_INFERNO := preload("res://art/ui_btn_inferno.png")    # 84x91, το κουμπί του special
const BALL_SINGLE := preload("res://art/fireball.png")
const BALL_AOE := preload("res://art/fireball_aoe.png")

const BAND_TILE := 64.0
const BAND_TINT := Color(0.52, 0.50, 0.58)   # σκουραίνει την υφή, να μην τραβάει το μάτι

var m


func _process(_delta: float) -> void:
	queue_redraw()


## Στρώνει την υφή σε μια ζώνη του HUD, πλακίδιο-πλακίδιο. Το τελευταίο
## πλακίδιο κόβεται στο πλάτος της οθόνης αντί να τεντωθεί.
func _draw_band(rect: Rect2) -> void:
	var rows := int(ceil(rect.size.y / BAND_TILE))
	var cols := int(ceil(rect.size.x / BAND_TILE))
	for r in rows:
		for c in cols:
			var x := rect.position.x + c * BAND_TILE
			var y := rect.position.y + r * BAND_TILE
			var w := minf(BAND_TILE, rect.end.x - x)
			var h := minf(BAND_TILE, rect.end.y - y)
			draw_texture_rect_region(BAND, Rect2(x, y, w, h),
				Rect2(0, 0, w, h), BAND_TINT)


## Πινακίδα με κείμενο στο κέντρο της.
func _draw_label(pos: Vector2, text: String, size: int, col: Color) -> void:
	var font: Font = m.font
	draw_texture_rect(PLATE_LABEL, Rect2(pos, Vector2(192, 64)), false)
	var th := font.get_height(size)
	draw_string(font, Vector2(pos.x + 18.0, pos.y + 32.0 + th * 0.32), text,
		HORIZONTAL_ALIGNMENT_CENTER, 156.0, size, col)


func _draw() -> void:
	if m == null:
		return
	var font: Font = m.font
	var W: float = m.W
	var H: float = m.H

	# ---------------- πάνω μπάρα
	_draw_band(Rect2(0, 0, W, m.HUD_BAND))
	# χωρίς σκορ πια: μένουν ο γύρος και η περιοχή, ο καθένας στην πινακίδα του
	_draw_label(Vector2(m.frame_left() + 10.0, 14.0), "ROUND %d" % m.level, 24,
		Color("ffe9bd"))
	var area = m.current_area()
	if area:
		_draw_label(Vector2(m.frame_left() + 210.0, 14.0), area.display_name, 20,
			Color("cbbf9e"))

	var pr: Rect2 = m.pause_rect()
	draw_texture_rect(PLATE_PAUSE, pr, false)
	draw_rect(Rect2(pr.position.x + 19.0, pr.position.y + 16.0, 6.0, 26.0), Color("e8e2f2"))
	draw_rect(Rect2(pr.position.x + 33.0, pr.position.y + 16.0, 6.0, 26.0), Color("e8e2f2"))

	# μενού: τρεις γραμμές, στην ίδια πλάκα με την παύση
	var mr: Rect2 = m.menu_rect()
	draw_texture_rect(PLATE_PAUSE, mr, false)
	for i in 3:
		draw_rect(Rect2(mr.position.x + 16.0, mr.position.y + 18.0 + i * 8.0, 25.0, 4.0),
			Color("e8e2f2"))

	# ---------------- ζωή boss ή ένδειξη power-up
	if m.boss != null and is_instance_valid(m.boss):
		var bw: float = m.frame_right() - m.frame_left() - 48.0
		var br := Rect2(m.frame_left() + 24.0, 96.0, bw, 20.0)
		draw_rect(br, Color("2a1420"))
		var bf: float = clampf(m.boss.hp / maxf(m.boss.max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(br.position + Vector2(2, 2), Vector2((bw - 4.0) * bf, 16.0)), Color("d4453a"))
		draw_string(font, Vector2(br.position.x, br.position.y + 16.0), "BOSS",
			HORIZONTAL_ALIGNMENT_CENTER, bw, 15, Color("ffd7c2"))
	elif m.triple_turns > 0:
		var pw := 288.0
		var r := Rect2(W * 0.5 - pw * 0.5, 88.0, pw, 62.0)
		draw_rect(r, Color("1d1b2e"))
		draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color("2a2740"))
		var f := float(m.triple_turns) / float(m.TRIPLE_TURNS)
		var bar := Rect2(r.position.x + 14.0, r.position.y + 12.0, 9.0, r.size.y - 24.0)
		draw_rect(bar, Color("15162b"))
		draw_rect(Rect2(bar.position.x, bar.position.y + bar.size.y * (1.0 - f),
			bar.size.x, bar.size.y * f), Color("6fc3ff"))
		draw_circle(Vector2(r.position.x + 50.0, r.position.y + 31.0), 14.0, Color("ff9e2c"))
		draw_string(font, Vector2(r.position.x + 74.0, r.position.y + 40.0), "Triple Shot",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ffe1ad"))

	# ---------------- κάτω μπάρα
	_draw_band(Rect2(0, m.ui_top, W, H - m.ui_top))

	var shown: int = (m.live_balls + m.to_fire) if m.phase == "shoot" else m.ball_count
	var bc := Vector2(m.frame_left() + 78.0, m.ui_top + 56.0)
	draw_texture_rect(PLATE_ROUND, Rect2(bc - Vector2(36.5, 36.5), Vector2(73, 73)), false)
	draw_string(font, Vector2(bc.x - 40.0, bc.y + 11.0), "x%d" % shown,
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 30, Color("ffd98a"))

	_draw_dragon_button(font)

	# όσο υπάρχουν μπάλες στο ταμπλό τα δύο κουμπιά δεν δέχονται πάτημα, οπότε
	# ξεθωριάζουν κιόλας — αλλιώς φαίνονται ενεργά και δεν απαντάνε
	var locked: bool = m.controls_locked()
	var lock_tint := Color(0.45, 0.45, 0.48) if locked else Color.WHITE
	var lock_text := Color("6b6878") if locked else Color("c9c2d6")

	# διακόπτης single / AoE
	var ar: Rect2 = m.aoe_rect()
	draw_texture_rect(PLATE_SQ, ar, false, lock_tint)
	if m.aoe_mode:
		# αναμμένο: ζεστή λάμψη μέσα στην πλάκα, αντί για δεύτερο χρώμα φόντου
		draw_rect(Rect2(ar.position + Vector2(8, 8), ar.size - Vector2(16, 16)),
			Color(1.0, 0.55, 0.15, 0.16))
	# μέσα στο κουμπί μπαίνει το βλήμα που θα φύγει πραγματικά
	var ac := ar.position + ar.size * 0.5
	var shot: Texture2D = BALL_AOE if m.aoe_mode else BALL_SINGLE
	draw_texture_rect(shot, Rect2(ac - Vector2(32, 32), Vector2(64, 64)), false, lock_tint)
	draw_string(font, Vector2(ar.position.x - 22.0, ar.end.y + 22.0),
		"AOE" if m.aoe_mode else "SINGLE",
		HORIZONTAL_ALIGNMENT_CENTER, ar.size.x + 44.0, 18, lock_text)

	# special με μπάρα φόρτισης
	var sr: Rect2 = m.special_rect()
	var ready: bool = m.special_ready()
	var sc := sr.position + sr.size * 0.5
	# το εικονίδιο έχει τη λάμψη ζωγραφισμένη μέσα του· όσο δεν είναι έτοιμο
	# σβήνει με σκούρο modulate, και ανάβει μόλις γεμίσει
	var inferno_tint := Color.WHITE if ready else Color(0.44, 0.40, 0.46)
	if locked:
		inferno_tint *= lock_tint
	draw_texture_rect(BTN_INFERNO, Rect2(sc - Vector2(42, 45.5), Vector2(84, 91)), false,
		inferno_tint)
	var charge := 0.0
	if m.dragon:
		charge = clampf(m.special_charge / maxf(m.dragon.special_cost, 1.0), 0.0, 1.0)
	# η φόρτιση γεμίζει από κάτω προς τα πάνω, μέσα στο περιθώριο του κουμπιού
	if not ready:
		draw_rect(Rect2(sr.position.x + 10.0, sr.end.y - 10.0 - (sr.size.y - 20.0) * charge,
			sr.size.x - 20.0, (sr.size.y - 20.0) * charge), Color(1.0, 0.62, 0.20, 0.20))
	elif not locked:
		draw_circle(sc, 46.0 + sin(m.t * 6.0) * 2.0, Color(1.0, 0.62, 0.20, 0.13))
	draw_string(font, Vector2(sr.position.x - 30.0, sr.end.y + 22.0),
		m.dragon.special_name() if m.dragon else "SPECIAL",
		HORIZONTAL_ALIGNMENT_CENTER, sr.size.x + 60.0, 18,
		lock_text if locked else (Color("ffe1ad") if ready else Color("77708a")))

	if m.phase == "aim" and not m.aiming:
		draw_string(font, Vector2(0, m.ui_top + 66.0), "DRAG TO AIM",
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
			"SCORE %d  •  ROUND %d  •  BEST %d" % [m.score, m.level, int(m.save.get("best_score", 0))],
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


func _draw_dragon_button(font: Font) -> void:
	var r: Rect2 = m.dragon_rect()
	var usable: bool = m.can_switch_dragon()
	var alpha := 1.0 if usable else 0.45
	draw_rect(r, Color("2a2740"))
	draw_rect(Rect2(r.position + Vector2(3, 3), r.size - Vector2(6, 6)), Color("1d1b2e"))
	if m.new_dragon:
		# παλμός ώστε να φαίνεται ότι κάτι καινούριο περιμένει
		var glow := 0.5 + 0.5 * sin(m.t * 6.0)
		draw_rect(r.grow(3.0 + glow * 2.0), Color(1.0, 0.62, 0.18, 0.35 + glow * 0.3), false, 3.0)
	if m.dragon:
		_draw_portrait(m.dragon, r.grow(-8.0), alpha)
	draw_string(font, Vector2(r.position.x - 22.0, r.end.y + 24.0),
		"NEW!" if m.new_dragon else (m.dragon.display_name if m.dragon else "DRAGON"),
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x + 44.0, 20,
		Color("ffb35c") if m.new_dragon else Color(0.79, 0.76, 0.84, alpha))


func _draw_picker(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(m.W, m.H)), Color(0.04, 0.03, 0.06, 0.70))
	var panel: Rect2 = m.picker_panel_rect()
	draw_rect(panel, Color("2a2740"))
	draw_rect(panel.grow(-3.0), Color("15162b"))
	draw_string(font, Vector2(panel.position.x, panel.position.y + 48.0), "ΔΙΑΛΕΞΕ ΔΡΑΚΟ",
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
			draw_string(font, Vector2(x, y + 28.0), "%s · %d kills" % [d.special_name(), int(d.special_cost)],
				HORIZONTAL_ALIGNMENT_CENTER, w, 16, Color("6fc3ff"))
			draw_string(font, Vector2(x, y + 50.0), d.special_desc(),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("c9c2d6"))
			draw_string(font, Vector2(x, y + 72.0), d.passive_desc(),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("9b93ad"))
		else:
			draw_string(font, Vector2(x, y + 32.0), "ΚΛΕΙΔΩΜΕΝΟΣ",
				HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color("ff9b3d"))
			draw_string(font, Vector2(x, y + 56.0), "νίκησε τον boss:",
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("9b93ad"))
			draw_string(font, Vector2(x, y + 76.0), _unlock_area_name(d),
				HORIZONTAL_ALIGNMENT_CENTER, w, 15, Color("c9c2d6"))

	draw_string(font, Vector2(panel.position.x, panel.end.y - 18.0), "πάτα έξω για κλείσιμο",
		HORIZONTAL_ALIGNMENT_CENTER, panel.size.x, 18, Color(1, 1, 1, 0.4))


func _unlock_area_name(d: DragonType) -> String:
	var idx := d.unlock_after_area - 1
	if idx >= 0 and idx < m.areas.size():
		return m.areas[idx].display_name
	return "περιοχή %d" % d.unlock_after_area
