extends Node2D
## Το HUD ζει σε CanvasLayer ώστε να σχεδιάζεται πάντα πάνω από εχθρούς και μπάλες.
## Διαβάζει κατάσταση από το main· δεν κρατάει δική του.

var m: Game


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if m == null:
		return
	var font: Font = m.font
	var W: float = m.W
	var H: float = m.H

	# ---------------- πάνω μπάρα
	draw_rect(Rect2(0, 0, W, m.HUD_BAND), Color("15162b"))
	draw_string(font, Vector2(m.frame_left() + 24.0, 50.0), "SCORE: %d" % m.score,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("fff2cf"))
	draw_string(font, Vector2(m.frame_right() - 400.0, 50.0), "ROUND: %d" % m.level,
		HORIZONTAL_ALIGNMENT_RIGHT, 300.0, 32, Color("fff2cf"))
	var area = m.current_area()
	if area:
		draw_string(font, Vector2(m.frame_left() + 24.0, 76.0), area.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("8d85a3"))

	var pr: Rect2 = m.pause_rect()
	draw_rect(pr, Color("2a2740"))
	draw_rect(Rect2(pr.position + Vector2(3, 3), pr.size - Vector2(6, 6)), Color("3b3757"))
	draw_rect(Rect2(pr.position.x + 18.0, pr.position.y + 15.0, 6.0, 26.0), Color("e8e2f2"))
	draw_rect(Rect2(pr.position.x + 32.0, pr.position.y + 15.0, 6.0, 26.0), Color("e8e2f2"))

	# ---------------- ζωή boss ή ένδειξη power-up
	if m.boss != null and is_instance_valid(m.boss):
		var bw := m.frame_right() - m.frame_left() - 48.0
		var br := Rect2(m.frame_left() + 24.0, 96.0, bw, 20.0)
		draw_rect(br, Color("2a1420"))
		var bf := clampf(m.boss.hp / maxf(m.boss.max_hp, 1.0), 0.0, 1.0)
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
	draw_rect(Rect2(0, m.ui_top, W, H - m.ui_top), Color("15162b"))

	var shown := (m.live_balls + m.to_fire) if m.phase == "shoot" else m.ball_count
	var bc := Vector2(m.frame_left() + 78.0, m.ui_top + 56.0)
	draw_circle(bc, 38.0, Color("2a2740"))
	draw_circle(bc, 34.0, Color("1d1b2e"))
	draw_string(font, Vector2(bc.x - 40.0, bc.y + 11.0), "x%d" % shown,
		HORIZONTAL_ALIGNMENT_CENTER, 80.0, 30, Color("ffd98a"))

	# διακόπτης single / AoE
	var ar: Rect2 = m.aoe_rect()
	draw_rect(ar, Color("2a2740"))
	draw_rect(Rect2(ar.position + Vector2(3, 3), ar.size - Vector2(6, 6)),
		Color("3b3757") if m.aoe_mode else Color("1d1b2e"))
	var ac := ar.position + ar.size * 0.5
	if m.aoe_mode:
		draw_circle(ac, 22.0, Color(1.0, 0.55, 0.15, 0.30))
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			draw_circle(ac + d * 20.0, 6.0, Color("ff9e2c"))
	draw_circle(ac, 11.0, Color("ff8a1f"))
	draw_string(font, Vector2(ar.position.x - 22.0, ar.end.y + 24.0),
		"AOE" if m.aoe_mode else "SINGLE",
		HORIZONTAL_ALIGNMENT_CENTER, ar.size.x + 44.0, 20, Color("c9c2d6"))

	# special με μπάρα φόρτισης
	var sr: Rect2 = m.special_rect()
	draw_rect(sr, Color("2a2740"))
	draw_rect(Rect2(sr.position + Vector2(3, 3), sr.size - Vector2(6, 6)), Color("1d1b2e"))
	var charge := 0.0
	if m.dragon:
		charge = clampf(m.special_charge / maxf(m.dragon.special_cost, 1.0), 0.0, 1.0)
	draw_rect(Rect2(sr.position.x + 3.0, sr.end.y - 3.0 - (sr.size.y - 6.0) * charge,
		sr.size.x - 6.0, (sr.size.y - 6.0) * charge), Color(0.42, 0.76, 1.0, 0.30))
	var sc := sr.position + sr.size * 0.5
	var ready := m.special_ready()
	draw_circle(sc, 24.0, Color("6fc3ff") if ready else Color("3b3757"))
	if ready:
		draw_circle(sc, 30.0 + sin(m.t * 6.0) * 2.0, Color(0.42, 0.76, 1.0, 0.18))
	draw_string(font, Vector2(sr.position.x - 30.0, sr.end.y + 24.0),
		m.dragon.special_name() if m.dragon else "SPECIAL",
		HORIZONTAL_ALIGNMENT_CENTER, sr.size.x + 60.0, 20,
		Color("ffe1ad") if ready else Color("77708a"))

	if m.phase == "aim" and not m.aiming:
		draw_string(font, Vector2(0, m.ui_top + 66.0), "σύρε για στόχευση",
			HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1, 0.30))

	# ---------------- ανακοινώσεις
	if m.banner != "":
		var alpha := clampf(m.banner_time, 0.0, 1.0)
		var plate := Rect2(m.frame_left(), m.PF_TOP + 26.0,
			m.frame_right() - m.frame_left(), 50.0)
		draw_rect(plate, Color(0.06, 0.05, 0.10, 0.88 * alpha))
		draw_string(font, Vector2(0, plate.position.y + 35.0), m.banner,
			HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1.0, 0.72, 0.36, alpha))

	if m.paused:
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.72))
		draw_string(font, Vector2(0, H * 0.46), "ΠΑΥΣΗ",
			HORIZONTAL_ALIGNMENT_CENTER, W, 56, Color("ffb35c"))

	if m.phase == "over":
		draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color(0.04, 0.03, 0.06, 0.82))
		draw_string(font, Vector2(0, H * 0.44), "GAME OVER",
			HORIZONTAL_ALIGNMENT_CENTER, W, 64, Color("ff9b3d"))
		draw_string(font, Vector2(0, H * 0.44 + 58.0),
			"SCORE %d  •  ROUND %d  •  ρεκόρ %d" % [m.score, m.level, int(m.save.get("best_score", 0))],
			HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color("9b93ad"))
		draw_string(font, Vector2(0, H * 0.44 + 126.0), "tap για νέο παιχνίδι",
			HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.5))
