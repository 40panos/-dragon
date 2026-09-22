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

	# πολλές κλήσεις, από warlock και από boss: καμία κάτω από τη σειρά 7
	var summoners := [wl]
	var lord = m._make_block(2, 0, m.enemy_by_id["warlock_boss"], 100.0, 3, 2, true)
	summoners.append(lord)
	for s in summoners:
		(s.ability as SummonerAbility).every = 1
	for i in 60:
		for s in summoners:
			s.ability.on_round_end(s, m)
	await process_frame
	var deepest := -1
	for b in m.grid.blocks():
		if b != lord and b != wl:
			deepest = maxi(deepest, b.row)
	ok("κανένα minion κάτω από τη σειρά 7", deepest >= 2 and deepest <= 7, "(βαθύτερο: %d)" % deepest)
	ok("η σειρά 8 έμεινε άδεια", m.grid.free_cols_in_row(8).size() == m.COLS)
	m.boss = null

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
	ok("η ζημιά ΔΕΝ φορτίζει το special", m.special_charge == 0.0, "(%.2f)" % m.special_charge)
	var weak = m._make_block(6, 6, m.enemy_by_id["goblin"], 1.0, 1, 1, false)
	m.aoe_mode = false
	var ball2 = load("res://scenes/ball.tscn").instantiate()
	m.add_child(ball2)
	ball2.damage = 1.0
	m._on_ball_struck(weak, ball2)
	await process_frame
	ok("κάθε σκοτωμός φορτίζει το special κατά 1", m.special_charge == 1.0, "(%.2f)" % m.special_charge)
	ball.queue_free()
	ball2.queue_free()
	m.special_charge = 0.0

	print("--- εμφάνιση εχθρών ανά γύρο ---")
	var area0: AreaDef = m.areas[0]
	var seen := {}
	for r in [1, 2, 3, 4, 6, 9]:
		var ids := []
		for e in area0.allowed(r):
			ids.append(e.id)
		ids.sort()
		seen[r] = ids
	ok("γύροι 1-3: μόνο goblins", seen[1] == ["goblin"] and seen[3] == ["goblin"], str(seen[3]))
	ok("γύρος 4: + brute", seen[4] == ["brute", "goblin"], str(seen[4]))
	ok("γύρος 6: + orc", seen[6] == ["brute", "goblin", "orc"], str(seen[6]))
	ok("γύρος 9: + knight, warlock", seen[9] == ["brute", "goblin", "knight", "orc", "warlock"], str(seen[9]))
	var counts := {}
	for i in 10000:
		var e: EnemyType = area0.pick(float(i) / 10000.0, 9)
		counts[e.id] = counts.get(e.id, 0) + 1
	ok("οι πιθανότητες ακολουθούν το weight", counts["goblin"] > counts["brute"]
		and counts["brute"] > counts["orc"] and counts["orc"] > counts["knight"]
		and counts["knight"] > counts["warlock"], str(counts))
	m.level = 1
	m.area_index = 0
	var early_ok := true
	for i in 200:
		if m._roll_enemy().id != "goblin":
			early_ok = false
	ok("στον γύρο 1 το παιχνίδι βγάζει μόνο goblins", early_ok)

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

		# ο boss επιβιώνει μερικές βολές — ο γύρος και η περιοχή πρέπει να μείνουν
		var frost_dragon = null
		for dd in m.dragons:
			if dd.passive == "ball_every5":
				frost_dragon = dd
		var old_dragon = m.dragon
		if frost_dragon:
			m.dragon = frost_dragon
		var balls_before = m.ball_count
		# χωρίς κλήσεις εδώ: ένα minion στη σειρά 10 θα έφερνε game over και θα έκοβε τη σειρά
		(m.boss.ability as SummonerAbility).every = 1000
		for turn in 3:
			m._end_turn()
			await process_frame
		ok("με ζωντανό boss ο γύρος δεν προχωράει", m.level == 20, "(%d)" % m.level)
		ok("με ζωντανό boss η περιοχή δεν αλλάζει", m.area_index == 0, "(%d)" % m.area_index)
		ok("με ζωντανό boss συνεχίζουν οι σειρές", m.phase == "aim" and m.grid.free_cols_in_row(0).size() < m.COLS,
			"(phase=%s, ελεύθερα στη σειρά 0: %d)" % [m.phase, m.grid.free_cols_in_row(0).size()])
		ok("ο boss κατέβηκε μαζί με τους άλλους", m.boss.row >= 1, "(σειρά %d)" % m.boss.row)
		ok("το passive +1 μπάλα δεν μετράει τις βολές του boss", m.ball_count == balls_before,
			"(%d -> %d)" % [balls_before, m.ball_count])
		m.dragon = old_dragon

		ok("ο frost είναι κλειδωμένος πριν τον boss", not m.run_dragons.has("frost"), str(m.run_dragons))
		m.phase = "aim"
		ok("δεν διαλέγεις κλειδωμένο δράκο", not m.select_dragon("frost") and m.dragon.id == "ember")
		m.boss.take_damage(m.boss.max_hp + 10.0)
		await process_frame
		ok("ξεκλείδωσε νέος δράκος για αυτό το run", m.run_dragons.has("frost"), str(m.run_dragons))
		ok("ο παίκτης ειδοποιείται για τον νέο δράκο", m.new_dragon)

		print("--- επιλογή δράκου ---")
		m.phase = "shoot"
		ok("όχι αλλαγή δράκου κατά τη βολή", not m.select_dragon("frost") and m.dragon.id == "ember")
		m.phase = "aim"
		m.aiming = true
		ok("όχι αλλαγή δράκου την ώρα της στόχευσης", not m.select_dragon("frost"))
		m.aiming = false
		m.picker_open = true
		var frost_i := -1
		for i in m.dragons.size():
			if m.dragons[i].id == "frost":
				frost_i = i
		m.picker_press(m.picker_card_rect(frost_i).get_center())
		ok("πάτημα σε κάρτα αλλάζει δράκο και κλείνει", m.dragon.id == "frost" and not m.picker_open,
			"(%s)" % m.dragon.id)
		m.picker_open = true
		m.picker_press(Vector2(5, 5))
		ok("πάτημα έξω κλείνει χωρίς αλλαγή", not m.picker_open and m.dragon.id == "frost")
		var last: Rect2 = m.picker_card_rect(m.dragons.size() - 1)
		ok("οι κάρτες χωράνε πάνω από την κάτω μπάρα", m.picker_panel_rect().end.y < m.ui_top
			and last.end.y < m.picker_panel_rect().end.y)
		ok("το κουμπί δράκου δεν πέφτει πάνω σε άλλο κουμπί",
			not m.dragon_rect().intersects(m.aoe_rect()) and not m.dragon_rect().intersects(m.special_rect()))
		m.select_dragon("ember")

	print("--- ροή γύρου ---")
	var before_level = m.level
	m._end_turn()
	await process_frame
	ok("ο γύρος προχώρησε", m.level == before_level + 1, "(%d)" % m.level)
	ok("μετά τον boss πάμε στην επόμενη περιοχή", m.area_index == 1, "(%d)" % m.area_index)
	var misplaced := 0
	for b in m.grid.blocks():
		var want = m.block_center(b.col, b.row, b.cw, b.ch)
		if absf(b.position.x - want.x) > 1.0:
			misplaced += 1
	ok("κόμβοι συγχρονισμένοι με το πλέγμα", misplaced == 0, "(%d εκτός)" % misplaced)

	print("--- νέο run μετά από game over ---")
	m.level = 40
	m.area_index = 1
	m._game_over()
	m._start()
	await process_frame
	ok("νέο run ξεκινάει από τον γύρο 1", m.level == 1 and m.area_index == 0,
		"(γύρος %d, περιοχή %d)" % [m.level, m.area_index])
	ok("νέο run: ο frost ξανακλειδώνει", m.run_dragons == ["ember"] and m.dragon.id == "ember",
		str(m.run_dragons))

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
