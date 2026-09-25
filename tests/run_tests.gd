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


## Βρίσκει το SummonerAbility, είτε είναι σκέτο είτε μέρος ενός composite.
func _find_summoner(a) -> SummonerAbility:
	if a is SummonerAbility:
		return a
	if a is CompositeAbility:
		for p in (a as CompositeAbility).parts:
			if p is SummonerAbility:
				return p
	return null


func _initialize() -> void:
	# Καθαρή αποθήκευση ΠΡΙΝ φορτώσει η σκηνή: το main διαβάζει το save στο
	# _ready και διαλέγει δράκο από εκεί. Χωρίς αυτό, ένα προηγούμενο τρέξιμο
	# (ή το ίδιο το test του boss, που ξεκλειδώνει τον frost) αφήνει πίσω του
	# άλλον επιλεγμένο δράκο και τα tests του ember αποτυγχάνουν ανάλογα με τη
	# σειρά που έτυχε να τρέξουν τα πράγματα.
	SaveManager.save_data(SaveManager.defaults())

	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame

	# Η σημαία unlock_all_dragons είναι βοήθημα για χειροκίνητες δοκιμές. Τα
	# tests πρέπει να ελέγχουν τους αληθινούς κανόνες ξεκλειδώματος, οπότε τη
	# σβήνουν και ξαναστήνουν τη λίστα.
	m.unlock_all_dragons = false
	m._reset_dragons()
	await process_frame

	print("--- περιεχόμενο ---")
	ok("φορτώθηκαν περιοχές", m.areas.size() >= 2, "(%d)" % m.areas.size())
	ok("φορτώθηκαν δράκοι", m.dragons.size() >= 2, "(%d)" % m.dragons.size())
	ok("επιλέχθηκε δράκος", m.dragon != null, str(m.dragon.id if m.dragon else "-"))
	ok("πλέγμα γεμάτο μετά την 1η σειρά", m.grid.blocks().size() > 0, "(%d)" % m.grid.blocks().size())
	# εύρος αντί για σταθερό νούμερο: το COLS ρυθμίζεται (μέγεθος κελιού), οπότε
	# η ακριβής τιμή αλλάζει μαζί του — το test ελέγχει ότι ο υπολογισμός βγάζει
	# λογικό αποτέλεσμα, όχι μια συγκεκριμένη γεωμετρία.
	ok("death_row υπολογίστηκε", m.death_row >= 8 and m.death_row <= 12, "(%d)" % m.death_row)

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
	var before: Array = m.grid.blocks()
	var wl = m._make_block(7, 0, m.enemy_by_id["warlock"], 8.0, 1, 1, false)
	var sa = wl.ability as SummonerAbility
	sa.every = 1
	ok("καλεί orc bat", sa.minion_id == "bat", "(%s)" % sa.minion_id)
	ok("κρατάει ζώνη ασφαλείας", sa.keep_clear == 2, "(%d)" % sa.keep_clear)
	sa.on_round_end(wl, m)
	await process_frame
	var minion = null
	for b in m.grid.blocks():
		if b != wl and not before.has(b):
			minion = b
	ok("γεννήθηκε minion", minion != null)
	if minion:
		ok("το minion είναι orc bat", minion.kind == "bat", "(%s)" % minion.kind)
		ok("σχεδιάζεται μικρότερο", minion.sprite_scale < 1.0,
			"(%.2f)" % minion.sprite_scale)
		ok("έχει idle animation", minion.frames_idle.size() > 1,
			"(%d καρέ)" % minion.frames_idle.size())

	# απαγορευμένες ζώνες: οι πρώτες σειρές και οι δύο πριν τη γραμμή θανάτου
	print("--- ζώνες που απαγορεύονται στον καλεστή ---")
	var rows_seen: Array = []
	for i in 60:
		for b in m.grid.blocks():
			if b != wl:
				m.grid.erase(b)
				b.queue_free()
		await process_frame
		sa.on_round_end(wl, m)
		await process_frame
		for b in m.grid.blocks():
			if b != wl and not rows_seen.has(b.row):
				rows_seen.append(b.row)
	rows_seen.sort()
	var lowest: int = rows_seen.min() if not rows_seen.is_empty() else -1
	var deepest: int = rows_seen.max() if not rows_seen.is_empty() else 99
	ok("ποτέ πάνω από τη σειρά %d" % sa.min_row, lowest >= sa.min_row,
		"(ελάχιστη %d)" % lowest)
	ok("ποτέ στις 2 σειρές πριν τον δράκο",
		deepest <= m.death_row - 1 - sa.keep_clear,
		"(μέγιστη %d, όριο %d)" % [deepest, m.death_row - 1 - sa.keep_clear])
	ok("ο τύπος bat μένει έξω από την τυχαία δεξαμενή",
		not m.current_area().enemies.any(func(e): return e.id == "bat"))
	for b in m.grid.blocks():
		if b != wl:
			m.grid.erase(b)
			b.queue_free()
	await process_frame

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
	# άλλο όνομα: το `deepest` υπάρχει ήδη πιο πάνω, και στο _initialize()
	# όλες οι μεταβλητές ζουν στο ίδιο scope
	var deepest_both := -1
	for b in m.grid.blocks():
		if b != lord and b != wl:
			deepest_both = maxi(deepest_both, b.row)
	ok("κανένα minion κάτω από τη σειρά 7", deepest_both >= 2 and deepest_both <= 7,
		"(βαθύτερο: %d)" % deepest_both)
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
		# η ωμή ζωή έπεσε όταν μπήκε το χοντρό τομάρι, γιατί το τομάρι κόβει
		# ζημιά· αυτό που πρέπει να μείνει ψηλά είναι πόσες μπάλες χρειάζεται
		var per_ball: float = m.boss.ability.absorb(m.boss, 1.0) if m.boss.ability else 1.0
		ok("ο boss αντέχει πολλές μπάλες", m.boss.max_hp / per_ball >= 250.0,
			"(hp=%.0f, %.2f ανά μπάλα -> %.0f χτυπήματα)"
				% [m.boss.max_hp, per_ball, m.boss.max_hp / per_ball])
		m.save["unlocked_areas"] = 1
		m.save["unlocked_dragons"] = ["ember"]

		# ο boss επιβιώνει μερικές βολές — ο γύρος και η περιοχή πρέπει να μείνουν
		var frost_dragon = null
		for dd in m.dragons:
			if dd.passive == "ball_every5":
				frost_dragon = dd
		var old_dragon = m.dragon
		if frost_dragon:
			m.dragon = frost_dragon
		var balls_before = m.ball_count
		# χωρίς κλήσεις εδώ: ένα minion στη σειρά 10 θα έφερνε game over και θα έκοβε τη σειρά.
		# Ο boss δεν κρατάει σκέτο SummonerAbility: το κάλεσμα είναι ένα από τα
		# μέρη ενός CompositeAbility (μαζί με τομάρι και οργή), οπότε ο έλεγχος
		# ψάχνει και μέσα στα μέρη — σκέτο cast έβγαζε null και έσπαγε το suite.
		var boss_summoner := _find_summoner(m.boss.ability)
		ok("ο boss έχει κάλεσμα", boss_summoner != null)
		if boss_summoner:
			boss_summoner.every = 1000
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

	print("--- κάτω μπάρα ---")
	var hud_btns: Array[Rect2] = [m.dragon_rect(), m.aoe_rect(), m.special_rect()]
	var hud_fits := true
	for hb in hud_btns:
		if hb.position.x < m.frame_left() or hb.end.x > m.frame_right() 				or hb.position.y < m.floor_y or hb.end.y > m.H:
			hud_fits = false
	ok("τα κουμπιά της κάτω μπάρας χωράνε κάτω από το δάπεδο", hud_fits)
	ok("special και διακόπτης δεν πέφτουν το ένα πάνω στο άλλο",
		not m.special_rect().intersects(m.aoe_rect()))
	var ar_: Rect2 = m.aoe_rect()
	ok("ο διακόπτης διαλέγει τη θέση που πατήθηκε",
		not m.aoe_pick(ar_.position + Vector2(4, 4)) and m.aoe_pick(ar_.end - Vector2(4, 4)))
	ok("μενού και παύση στις πάνω γωνίες, χωρίς επικάλυψη",
		not m.menu_rect().intersects(m.pause_rect()) and m.pause_rect().end.y < m.PF_TOP)

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

	print("--- περίγραμμα κελιού ---")
	# ένας εχθρός με ελεύθερο δρόμο μπροστά του πρέπει, μόλις κλείσει ο γύρος,
	# να μετράει ως «σε κίνηση» — τότε κρύβεται το περίγραμμά του
	for b in m.grid.blocks():
		m.grid.erase(b)
		b.queue_free()
	await process_frame
	var mover = m._make_block(3, 2, m.enemy_by_id["goblin"], 5.0, 1, 1, false)
	var mover_row = mover.row
	m._end_turn()
	await process_frame
	ok("όποιος κατέβηκε σειρά μετράει ως σε κίνηση",
		mover.row > mover_row and mover.is_moving(), "(σειρά %d)" % mover.row)
	mover.queue_free()
	var edge_block = m._make_block(0, 1, m.enemy_by_id["goblin"], 5.0, 1, 1, false)
	ok("φρεσκογεννημένος εχθρός είναι ακίνητος", not edge_block.is_moving())
	edge_block.begin_move(m.ADVANCE_TIME)
	ok("όσο κατεβαίνει, μετράει ως σε κίνηση", edge_block.is_moving())
	edge_block._process(m.ADVANCE_TIME * 0.5)
	ok("στη μέση της διαδρομής ακόμα κινείται", edge_block.is_moving())
	edge_block._process(m.ADVANCE_TIME + edge_block.MOVE_GRACE)
	ok("μόλις φτάσει, ξαναγίνεται ακίνητος", not edge_block.is_moving())
	edge_block.queue_free()

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
	print("--- ξυπνημένη μορφή (INFERNO) ---")
	var awake = dg.awakened
	ok("ο δράκος έχει ξυπνημένη μορφή", awake is DragonType, str(awake))
	ok("με καρέ και στις 3 καταστάσεις",
		awake.frames_idle.size() == 3 and awake.frames_ready.size() == 3
			and awake.frames_fire.size() == 3)
	ok("σχεδιάζεται μεγαλύτερη από την κανονική", awake.draw_width > dg.draw_width,
		"(%.0f > %.0f)" % [awake.draw_width, dg.draw_width])
	var awake_sizes := {}
	for tex in awake.frames_idle + awake.frames_ready + awake.frames_fire:
		awake_sizes[tex.get_size()] = true
	ok("όλα τα καρέ της σε ίδιο καμβά", awake_sizes.size() == 1, str(awake_sizes.keys()))
	# Η ΜΟΡΦΗ κρέμεται από το awake_active, όχι από το inferno_active: κάθε
	# δράκος με δεύτερη μορφή τη βγάζει όταν ρίχνει το special του, αλλά μόνο
	# το INFERNO τριπλασιάζει τη ζημιά. Τα δύο ελέγχονται ξεχωριστά.
	m.awake_active = false
	m.inferno_active = false
	ok("χωρίς special παίζει η κανονική μορφή", m.active_dragon() == dg)
	m.awake_active = true
	ok("στο special παίζει η ξυπνημένη", m.active_dragon() == awake)
	var dmg_plain: float = m._ball_damage()
	m.inferno_active = true
	ok("μόνο το INFERNO τριπλασιάζει τη ζημιά", m._ball_damage() == dmg_plain * 3.0,
		"(%.2f -> %.2f)" % [dmg_plain, m._ball_damage()])
	m.awake_active = false
	m.inferno_active = false

	print("--- κλείδωμα χειριστηρίων ---")
	m.phase = "aim"
	ok("στη στόχευση τα κουμπιά δουλεύουν", not m.controls_locked())
	m.phase = "shoot"
	ok("όσο πετάνε μπάλες είναι κλειδωμένα", m.controls_locked())
	m.phase = "aim"

	# η φλόγα ανάβει μόνο όσο φεύγουν μπάλες, όχι όσο τριγυρνάνε στην πίστα
	m.phase = "shoot"
	m.to_fire = 3
	ok("όσο εκτοξεύονται μπάλες, ο δράκος βαράει", m.dragon_phase() == "shoot")
	m.to_fire = 0
	ok("μόλις φύγει η τελευταία, σταματάει να βαράει", m.dragon_phase() == "aim",
		m.dragon_phase())
	ok("και δείχνει καρέ idle, όχι φλόγας",
		m.dragon.frame_for(m.dragon_phase(), false, 0.0) == dg.frames_idle[0])
	m.phase = "aim"

	print("--- animation εχθρού (goblin idle) ---")
	# το fight-stance animation ζει στο goblin (χωρίς ικανότητα)· ο orc έχει
	# το δικό του, ξεχωριστό σετ (έφιππο), βλ. παρακάτω "orc idle+hit"
	var goblin_type: EnemyType = m.enemy_by_id["goblin"]
	ok("φορτώθηκαν 8 καρέ idle", goblin_type.frames_idle.size() == 8,
		"(%d)" % goblin_type.frames_idle.size())
	var goblin_sizes := {}
	for tex in goblin_type.frames_idle:
		goblin_sizes[tex.get_size()] = true
	ok("όλα τα καρέ idle ίδιο μέγεθος", goblin_sizes.size() == 1,
		"(%d διαφορετικά)" % goblin_sizes.size())
	var goblin_block = m._make_block(0, 0, goblin_type, 5.0, 1, 1, false)
	var idle_seq := []
	for step in 8:
		goblin_block.idle_t = float(step) / goblin_block.fps_idle
		idle_seq.append(goblin_block.frames_idle.find(goblin_block.idle_frame()))
	ok("το idle προχωράει καρέ-καρέ χωρίς επανάληψη πριν τον βρόχο",
		idle_seq == [0, 1, 2, 3, 4, 5, 6, 7], str(idle_seq))
	goblin_block.idle_t = 8.0 / goblin_block.fps_idle
	ok("μετά το τέλος ο βρόχος ξαναρχίζει από το 0",
		goblin_block.frames_idle.find(goblin_block.idle_frame()) == 0)

	print("--- animation εχθρού (goblin hit) ---")
	ok("φορτώθηκαν 9 καρέ hit", goblin_type.frames_hit.size() == 9,
		"(%d)" % goblin_type.frames_hit.size())
	var hit_sizes := {}
	for tex in goblin_type.frames_hit:
		hit_sizes[tex.get_size()] = true
	ok("όλα τα καρέ hit ίδιο μέγεθος με το idle", hit_sizes.size() == 1 and goblin_sizes.keys()[0] == hit_sizes.keys()[0],
		"(%s vs %s)" % [str(hit_sizes.keys()), str(goblin_sizes.keys())])
	ok("πριν το χτύπημα δείχνει idle", not goblin_block.hit_playing)
	goblin_block.take_damage(1.0)
	ok("το χτύπημα ξεκινάει την αντίδραση", goblin_block.hit_playing and goblin_block.hit_t == 0.0)
	ok("πρώτο καρέ της αντίδρασης", goblin_block.frames_hit.find(goblin_block.portrait_frame()) == 0)
	goblin_block._process(0.2)      # 0.2s * 12fps = καρέ 2 (μέσα στη διάρκεια)
	ok("προχωράει στα καρέ της αντίδρασης, όχι idle",
		goblin_block.hit_playing and goblin_block.frames_hit.find(goblin_block.portrait_frame()) == 2,
		"(%d)" % goblin_block.frames_hit.find(goblin_block.portrait_frame()))
	goblin_block._process(1.0)      # σίγουρα πέρασε η συνολική διάρκεια (9/12 ≈ 0.75s)
	ok("μετά το τέλος ξαναγυρίζει στο idle", not goblin_block.hit_playing)
	goblin_block.queue_free()

	print("--- animation εχθρού (orc idle+hit, έφιππος) ---")
	var orc_type: EnemyType = m.enemy_by_id["orc"]
	ok("φορτώθηκαν 5 καρέ idle", orc_type.frames_idle.size() == 5,
		"(%d)" % orc_type.frames_idle.size())
	# 4 καρέ, όχι 5 — το πρώτο κόπηκε, έμοιαζε πολύ με το idle
	ok("φορτώθηκαν 4 καρέ hit", orc_type.frames_hit.size() == 4,
		"(%d)" % orc_type.frames_hit.size())
	var orc_block = m._make_block(1, 0, orc_type, 5.0, 1, 1, false)
	orc_block.idle_t = 0.0
	ok("πριν το χτύπημα δείχνει idle", orc_block.portrait_frame() == orc_block.frames_idle[0])
	orc_block.take_damage(1.0)
	orc_block._process(0.3)      # 0.3s * 8fps = καρέ 2, ακόμα μέσα στη διάρκεια (4/8=0.5s)
	ok("μέσα στην αντίδραση δείχνει καρέ hit, όχι idle",
		orc_block.hit_playing and orc_block.frames_hit.find(orc_block.portrait_frame()) == 2,
		"(%d)" % orc_block.frames_hit.find(orc_block.portrait_frame()))
	orc_block._process(2.0)      # σίγουρα πέρασε η διάρκεια (5/8 ≈ 0.625s) — η μπάλα έχει φύγει προ πολλού
	ok("μόλις περάσει η διάρκεια του χτυπήματος, γυρίζει μόνο του στο idle",
		not orc_block.hit_playing)
	orc_block.queue_free()

	print("--- animation εχθρού (brute idle+hit) ---")
	# ο brute είναι ο μόνος εχθρός χωρίς ικανότητα· πήρε το ίδιο ζευγάρι
	# animation με τον goblin (8 idle σε βρόχο, 9 hit μία φορά)
	var brute_type: EnemyType = m.enemy_by_id["brute"]
	ok("ο brute δεν έχει ικανότητα", brute_type.ability == null)
	ok("φορτώθηκαν 8 καρέ idle", brute_type.frames_idle.size() == 8,
		"(%d)" % brute_type.frames_idle.size())
	ok("φορτώθηκαν 9 καρέ hit", brute_type.frames_hit.size() == 9,
		"(%d)" % brute_type.frames_hit.size())
	var brute_sizes := {}
	for tex in brute_type.frames_idle + brute_type.frames_hit:
		brute_sizes[tex.get_size()] = true
	ok("όλα τα καρέ σε ίδιο καμβά, ώστε να μη χοροπηδάει", brute_sizes.size() == 1,
		str(brute_sizes.keys()))
	ok("ίδιος καμβάς με τον goblin, όχι το παλιό 128x128",
		brute_type.frames_idle[0].get_size() == goblin_type.frames_idle[0].get_size()
			and brute_type.sprite.get_size() == Vector2(32, 32),
		str(brute_type.sprite.get_size()))
	var brute_block = m._make_block(4, 0, brute_type, 5.0, 1, 1, false)
	brute_block.idle_t = 0.0
	ok("πριν το χτύπημα δείχνει idle", brute_block.portrait_frame() == brute_block.frames_idle[0])
	brute_block.take_damage(1.0)
	brute_block._process(0.2)      # 0.2s * 12fps = καρέ 2, μέσα στη διάρκεια (9/12=0.75s)
	ok("μέσα στην αντίδραση δείχνει καρέ hit, όχι idle",
		brute_block.hit_playing and brute_block.frames_hit.find(brute_block.portrait_frame()) == 2,
		"(%d)" % brute_block.frames_hit.find(brute_block.portrait_frame()))
	brute_block._process(1.0)      # σίγουρα πέρασε η διάρκεια
	ok("μετά το τέλος ξαναγυρίζει στο idle", not brute_block.hit_playing)
	brute_block.queue_free()

	print("--- animation χτυπήματος στον knight και τον warlock ---")
	var knight_type: EnemyType = m.enemy_by_id["knight"]
	var warlock_type: EnemyType = m.enemy_by_id["warlock"]
	ok("ο knight έχει 4 καρέ hit", knight_type.frames_hit.size() == 4)
	ok("ο warlock έχει 4 καρέ hit", warlock_type.frames_hit.size() == 4)
	ok("ο knight πήρε 8 καρέ idle", knight_type.frames_idle.size() == 8,
		"(%d)" % knight_type.frames_idle.size())
	ok("ο warlock πήρε 8 καρέ idle", warlock_type.frames_idle.size() == 8,
		"(%d)" % warlock_type.frames_idle.size())
	# ο boss είναι ο ίδιος χαρακτήρας με τον warlock, μεγεθυσμένος
	var boss_wl: EnemyType = m.enemy_by_id["warlock_boss"]
	ok("και ο boss κινείται στην ηρεμία", boss_wl.frames_idle.size() == 8,
		"(%d)" % boss_wl.frames_idle.size())
	# κανένας εχθρός δεν πρέπει πια να μένει με στατικό πορτρέτο
	var still := []
	for id in m.enemy_by_id:
		if m.enemy_by_id[id].frames_idle.is_empty():
			still.append(id)
	ok("κανένας εχθρός δεν έμεινε χωρίς idle", still.is_empty(), str(still))
	for id in ["knight", "warlock", "warlock_boss"]:
		var et: EnemyType = m.enemy_by_id[id]
		var sz := {}
		for tex in et.frames_idle + et.frames_hit:
			sz[tex.get_size()] = true
		ok("%s: idle και hit σε ίδιο καμβά" % id, sz.size() == 1, str(sz.keys()))
	var knight_block = m._make_block(2, 0, knight_type, 5.0, 1, 1, false)
	knight_block.take_damage(1.0)
	knight_block._process(2.0)      # σίγουρα πέρασε η διάρκεια της αντίδρασης
	ok("και ο knight γυρίζει μόνος του στο idle μετά το χτύπημα",
		not knight_block.hit_playing)
	knight_block.queue_free()

	print("--- Goblin King: γραφικά ---")
	var king_type: EnemyType = m.enemy_by_id["goblin_king"]
	ok("ο boss της Goblin Land είναι ο βασιλιάς",
		m.areas[0].boss.id == "goblin_king", m.areas[0].boss.id)
	ok("το Frost Marches κράτησε τον δικό του boss",
		m.areas[1].boss.id == "warlock_boss", m.areas[1].boss.id)
	ok("6 καρέ idle", king_type.frames_idle.size() == 6,
		"(%d)" % king_type.frames_idle.size())
	ok("6 καρέ hit", king_type.frames_hit.size() == 6,
		"(%d)" % king_type.frames_hit.size())
	var king_sz := {}
	for tex in king_type.frames_idle + king_type.frames_hit:
		king_sz[tex.get_size()] = true
	ok("όλα τα καρέ σε ίδιο καμβά 96x64",
		king_sz.size() == 1 and king_sz.has(Vector2(96, 64)), str(king_sz.keys()))
	# 96x64 = 3:2, ίδιο με το αποτύπωμα 3x2 — αλλιώς ο βασιλιάς τεντώνεται
	ok("ο λόγος του καρέ ταιριάζει με το αποτύπωμα",
		is_equal_approx(96.0 / 64.0, float(m.areas[0].boss_cols) / float(m.areas[0].boss_rows)))

	print("--- Goblin King: ικανότητες ---")
	var king = m._make_block(2, 0, king_type, 40.0, 3, 2, true)
	var comp = king.ability as CompositeAbility
	ok("δέθηκαν τρεις ικανότητες", comp != null and comp.parts.size() == 3,
		"(%d)" % (comp.parts.size() if comp else -1))
	var hide: ThickHideAbility = null
	var fury: RageAbility = null
	var horn: SummonerAbility = null
	for p in comp.parts:
		if p is ThickHideAbility:
			hide = p
		elif p is RageAbility:
			fury = p
		elif p is SummonerAbility:
			horn = p
	ok("υπάρχουν και τα τρία μέρη", hide != null and fury != null and horn != null)

	# κάθε αντίγραφο πρέπει να έχει δικά του μέρη, αλλιώς δύο boss θα
	# μοιράζονταν την ίδια οργή και τους ίδιους μετρητές
	var king2 = m._make_block(2, 6, king_type, 40.0, 3, 2, false)
	ok("τα μέρη αντιγράφονται ανά εχθρό",
		(king2.ability as CompositeAbility).parts[0] != comp.parts[0])
	m.grid.erase(king2)
	king2.queue_free()

	# χοντρό τομάρι: 1.0 ζημιά -> 0.6, 3.0 (INFERNO) -> 2.6
	ok("το τομάρι κόβει σταθερό ποσό", is_equal_approx(hide.absorb(king, 1.0), 0.6),
		"(%.2f)" % hide.absorb(king, 1.0))
	ok("το INFERNO περνάει σχεδόν ακέραιο", is_equal_approx(hide.absorb(king, 3.0), 2.6),
		"(%.2f)" % hide.absorb(king, 3.0))
	ok("πάντα περνάει κάτι", hide.absorb(king, 0.3) > 0.0, "(%.2f)" % hide.absorb(king, 0.3))
	ok("δεν περνάει παραπάνω απ' όσα ήρθαν", hide.absorb(king, 0.1) <= 0.1)

	# οργή: μπαίνει μόλις πέσει κάτω από το μισό, και μόνο μία φορά
	var idle_before = king.frames_idle
	ok("ξεκινάει ήρεμος", not fury.raged)
	king.take_damage(10.0)
	await process_frame
	ok("στο 75% δεν έχει οργιστεί ακόμα", not fury.raged, "hp=%.1f" % king.hp)
	ok("το idle δεν άλλαξε", king.frames_idle == idle_before)
	king.take_damage(15.0)
	await process_frame
	ok("κάτω από το μισό οργίζεται", fury.raged, "hp=%.1f" % king.hp)
	ok("άλλαξε σετ ηρεμίας", king.frames_idle != idle_before)
	ok("το νέο σετ είναι τα καρέ οργής", king.frames_idle == fury.frames_rage)
	ok("βάφτηκε κόκκινος", king.modulate.g < 1.0, str(king.modulate))
	ok("το badge το δείχνει", "!!" in king.ability.badge(), king.ability.badge())

	# η οργή πιέζει: διπλό βήμα κάθε δεύτερο γύρο, όχι πριν
	var steps := []
	for i in 4:
		steps.append(comp.advance_rows(king, 1))
	ok("οργισμένος κατεβαίνει διπλά κάθε δεύτερο γύρο", steps == [1, 2, 1, 2], str(steps))

	# πολεμικό κάλεσμα: δύο bats τη φορά, και ουρλιαχτό πάνω στον βασιλιά
	king._process(2.0)      # να κλείσει πρώτα η αντίδραση των προηγούμενων χτυπημάτων
	var before_horn: Array = m.grid.blocks()
	horn.every = 1
	comp.on_round_end(king, m)
	await process_frame
	var spawned := 0
	for kb in m.grid.blocks():
		if not before_horn.has(kb) and kb.kind == "bat":
			spawned += 1
	ok("το κάλεσμα βγάζει δύο orc bats", spawned == 2, "(%d)" % spawned)
	ok("παίζει το ουρλιαχτό", king.act_playing)
	ok("το ουρλιαχτό δείχνει καρέ roar, όχι idle",
		horn.act_frames.has(king.portrait_frame()))
	# το χτύπημα κόβει το ουρλιαχτό — αλλιώς δεν φαίνεται ότι τον πέτυχες
	king.take_damage(1.0)
	ok("το χτύπημα υπερισχύει του ουρλιαχτού",
		king.frames_hit.has(king.portrait_frame()))
	king._process(2.0)
	ok("μετά το ουρλιαχτό γυρίζει στο idle",
		not king.act_playing and king.frames_idle.has(king.portrait_frame()))
	# το ταμπλό μπορεί να κρατάει και κόμβους που έχουν ήδη φύγει (π.χ. ο boss
	# που σκοτώθηκε παραπάνω), οπότε το καθάρισμα ελέγχει πρώτα εγκυρότητα
	for left_over in m.grid.blocks():
		if is_instance_valid(left_over):
			m.grid.erase(left_over)
			left_over.queue_free()
	await process_frame

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
