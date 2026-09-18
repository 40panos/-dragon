extends SceneTree
## Λειτουργικά tests για τα συστήματα του παιχνιδιού.
##
## Τρέξε το από τον φάκελο του project:
##   godot --headless --script tests/run_tests.gd
##
## Τρέξε το πριν ανοίξεις PR. Αν κάτι κοκκινίσει, κάτι έσπασε.

var pass_n := 0
var fail_n := 0


func ok(label: String, cond: bool, extra := "") -> void:
	if cond:
		pass_n += 1
		print("  OK   %s %s" % [label, extra])
	else:
		fail_n += 1
		print("  FAIL %s %s" % [label, extra])


func _initialize() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame

	print("--- περιεχόμενο ---")
	ok("φορτώθηκαν περιοχές", m.areas.size() >= 2, "(%d)" % m.areas.size())
	ok("φορτώθηκαν δράκοι", m.dragons.size() >= 2, "(%d)" % m.dragons.size())
	ok("επιλέχθηκε δράκος", m.dragon != null, str(m.dragon.id if m.dragon else "-"))
	ok("πλέγμα γεμάτο μετά την 1η σειρά", m.grid.blocks().size() > 0, "(%d)" % m.grid.blocks().size())
	ok("death_row υπολογίστηκε", m.death_row == 11, "(%d)" % m.death_row)

	print("--- πλέγμα με αποτύπωμα ---")
	for b in m.grid.blocks():
		m.grid.erase(b)
		b.queue_free()
	await process_frame
	var boss_type = m.enemy_by_id.get("warlock_boss")
	var big = m._make_block(2, 0, boss_type, 50.0, 3, 2, true)
	ok("boss πιάνει 6 κελιά", m.grid.at(2, 0) == big and m.grid.at(4, 1) == big)
	ok("δεν χωράει άλλος μέσα του", not m.grid.fits(3, 1, 1, 1))
	ok("χωράει δίπλα του", m.grid.fits(5, 0, 1, 1))
	var side = m._make_block(5, 0, m.enemy_by_id["goblin"], 5.0, 1, 1, false)
	ok("γείτονας εντοπίζεται", m.grid.neighbors(big).has(side))

	print("--- ασπίδα ---")
	var kn = m._make_block(0, 4, m.enemy_by_id["knight"], 10.0, 1, 1, false)
	var sh = kn.ability as ShieldAbility
	ok("ασπίδα αρχικοποιήθηκε", sh != null and sh.shield > 0.0, "(%.0f)" % (sh.shield if sh else 0.0))
	var before_hp = kn.hp
	kn.take_damage(4.0)
	ok("η ζωή δεν πειράχτηκε όσο αντέχει η ασπίδα", kn.hp == before_hp,
		"hp=%.1f shield=%.1f" % [kn.hp, sh.shield])
	kn.take_damage(20.0)
	ok("μετά το σπάσιμο περνάει ζημιά", kn.hp < before_hp, "hp=%.1f" % kn.hp)

	print("--- καβαλάρης ---")
	var rider = m._make_block(1, 1, m.enemy_by_id["orc"], 5.0, 1, 1, false)
	var ra = rider.ability as RiderAbility
	ok("έχει ability καβαλάρη", ra != null)
	var r1 = ra.advance_rows(rider, 1)
	var r2 = ra.advance_rows(rider, 1)
	ok("1ος γύρος απλό βήμα", r1 == 1, "(%d)" % r1)
	ok("2ος γύρος διπλό βήμα", r2 == 2, "(%d)" % r2)

	print("--- καλεστής ---")
	var before_count = m.grid.blocks().size()
	var wl = m._make_block(7, 0, m.enemy_by_id["warlock"], 8.0, 1, 1, false)
	var sa = wl.ability as SummonerAbility
	sa.every = 1
	sa.on_round_end(wl, m)
	await process_frame
	ok("γεννήθηκε minion", m.grid.blocks().size() > before_count + 1,
		"(%d -> %d)" % [before_count, m.grid.blocks().size()])

	print("--- AoE splash ---")
	for b in m.grid.blocks():
		m.grid.erase(b)
		b.queue_free()
	await process_frame
	var center = m._make_block(3, 3, m.enemy_by_id["goblin"], 20.0, 1, 1, false)
	var left = m._make_block(2, 3, m.enemy_by_id["goblin"], 20.0, 1, 1, false)
	var right = m._make_block(4, 3, m.enemy_by_id["goblin"], 20.0, 1, 1, false)
	m.aoe_mode = true
	m.special_charge = 0.0
	var ball = load("res://scenes/ball.tscn").instantiate()
	m.add_child(ball)
	ball.damage = 1.0
	m._on_ball_struck(center, ball)
	ok("ο στόχος έφαγε ζημιά", center.hp == 19.0, "hp=%.2f" % center.hp)
	ok("οι γείτονες έφαγαν splash", left.hp == 19.0 and right.hp == 19.0,
		"L=%.2f R=%.2f" % [left.hp, right.hp])
	m._on_ball_struck(center, ball)
	ok("2ο χτύπημα ίδιας μπάλας: στόχος ξανά", center.hp == 18.0, "hp=%.2f" % center.hp)
	ok("2ο χτύπημα ίδιας μπάλας: γείτονες ΟΧΙ ξανά", left.hp == 19.0, "L=%.2f" % left.hp)
	ok("το special φόρτισε από τη ζημιά", m.special_charge > 0.0, "(%.2f)" % m.special_charge)
	ball.queue_free()
	m.aoe_mode = false

	print("--- ζημιά μπάλας ---")
	m.balls_fired = 0
	m.inferno_active = false
	ok("κανονική μπάλα = 1.0", is_equal_approx(m._ball_damage(), 1.0))
	m.balls_fired = 4
	ok("passive: 5η μπάλα = 2.0", is_equal_approx(m._ball_damage(), 2.0))
	m.balls_fired = 0
	m.inferno_active = true
	ok("inferno = 3.0", is_equal_approx(m._ball_damage(), 3.0))
	m.aoe_mode = true
	ok("inferno + AoE = 0.99", absf(m._ball_damage() - 0.99) < 0.001, "(%.2f)" % m._ball_damage())
	m.aoe_mode = false
	m.inferno_active = false

	print("--- boss και περιοχές ---")
	for b in m.grid.blocks():
		m.grid.erase(b)
		b.queue_free()
	await process_frame
	m.boss = null
	m.level = 20
	m._add_row()
	await process_frame
	ok("ο boss εμφανίστηκε στον γύρο 20", m.boss != null)
	if m.boss:
		ok("ο boss πιάνει 3x2", m.boss.cw == 3 and m.boss.ch == 2)
		ok("ο boss έχει πολλή ζωή", m.boss.max_hp >= 200.0, "(%.0f)" % m.boss.max_hp)
		m.save["unlocked_areas"] = 1
		m.save["unlocked_dragons"] = ["ember"]
		m.boss.take_damage(m.boss.max_hp + 10.0)
		await process_frame
		ok("η περιοχή ξεκλείδωσε", int(m.save["unlocked_areas"]) == 2,
			"(%s)" % m.save["unlocked_areas"])
		ok("ξεκλείδωσε νέος δράκος", m.save["unlocked_dragons"].has("frost"),
			str(m.save["unlocked_dragons"]))

	print("--- ροή γύρου ---")
	var before_level = m.level
	m._end_turn()
	await process_frame
	ok("ο γύρος προχώρησε", m.level == before_level + 1, "(%d)" % m.level)
	var misplaced := 0
	for b in m.grid.blocks():
		var want = m.block_center(b.col, b.row, b.cw, b.ch)
		if absf(b.position.x - want.x) > 1.0:
			misplaced += 1
	ok("κόμβοι συγχρονισμένοι με το πλέγμα", misplaced == 0, "(%d εκτός)" % misplaced)

	print("--- όριο DragonView ---")
	ok("ο κόμβος εμφάνισης υπάρχει", m.dragon_view != null)
	ok("το main δεν κρατάει πια tilt/recoil",
		not ("tilt" in m) and not ("recoil" in m))
	ok("το main δεν ζωγραφίζει πια τον δράκο", not m.has_method("_draw_dragon"))
	ok("η εμφάνιση κρατάει tilt/recoil",
		("tilt" in m.dragon_view) and ("recoil" in m.dragon_view))
	m.dragon_view.recoil = 0.0
	m.dragon_view.kick()
	ok("το kick() φορτίζει την κλωτσιά", m.dragon_view.recoil > 0.9,
		"(%.2f)" % m.dragon_view.recoil)
	var mp: Vector2 = m.mouth_pos()
	ok("το στόμα είναι πάνω από το δάπεδο", mp.y < m.floor_y and mp.y > m.PF_TOP,
		"(y=%.0f, floor=%.0f)" % [mp.y, m.floor_y])
	ok("το main δίνει το ίδιο στόμα με την εμφάνιση",
		m.mouth_pos().distance_to(m.dragon_view.mouth_pos()) < 0.01)
	ok("η εμφάνιση σχεδιάζεται κάτω από τα εφέ",
		m.dragon_view.z_index < m.fx.z_index,
		"(%d < %d)" % [m.dragon_view.z_index, m.fx.z_index])
	var probe = m._make_block(0, 0, m.enemy_by_id["goblin"], 3.0, 1, 1, false)
	ok("η εμφάνιση μπαίνει πριν από τους εχθρούς, άρα σχεδιάζεται πίσω τους",
		m.dragon_view.get_index() < probe.get_index(),
		"(%d < %d)" % [m.dragon_view.get_index(), probe.get_index()])
	m.grid.erase(probe)
	probe.queue_free()

	print("--- animation δράκου ---")
	var dg = m.dragon
	ok("φορτώθηκαν καρέ και στις 3 καταστάσεις",
		dg.frames_idle.size() > 0 and dg.frames_ready.size() > 0 and dg.frames_fire.size() > 0,
		"(%d/%d/%d)" % [dg.frames_idle.size(), dg.frames_ready.size(), dg.frames_fire.size()])
	var seq := []
	for step in 8:
		var time: float = step / dg.fps_idle
		seq.append(dg.frames_idle.find(dg.frame_for("aim", false, time)))
	ok("ping-pong χωρίς άλμα στο γύρισμα", seq == [0, 1, 2, 1, 0, 1, 2, 1], str(seq))
	var a = dg.frame_for("aim", false, 0.0)
	var b = dg.frame_for("aim", true, 0.0)
	var c = dg.frame_for("shoot", false, 0.0)
	ok("οι τρεις καταστάσεις δείχνουν διαφορετικό καρέ", a != b and b != c and a != c)
	var sizes := {}
	for tex in dg.frames_idle + dg.frames_ready + dg.frames_fire:
		sizes[tex.get_size()] = true
	ok("όλα τα καρέ ίδιο μέγεθος, ώστε να μην πηδάει", sizes.size() == 1,
		"(%d διαφορετικά)" % sizes.size())

	print("--- αποθήκευση ---")
	var d = SaveManager.defaults()
	d["best_score"] = 4242
	SaveManager.save_data(d)
	var back = SaveManager.load_data()
	ok("το σκορ επιβίωσε", int(back["best_score"]) == 4242, "(%s)" % back["best_score"])
	ok("υπάρχει πεδίο έκδοσης", int(back["version"]) == SaveManager.VERSION)

	print("")
	print("=== %d πέρασαν, %d απέτυχαν ===" % [pass_n, fail_n])
	quit(1 if fail_n > 0 else 0)
