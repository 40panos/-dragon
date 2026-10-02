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
	var boss_type = m.enemy_by_id.get("yeti")
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
	m.fx_anims.clear()
	sa.on_round_end(wl, m)
	ok("το κάλεσμα δεν γεννάει αμέσως: πρώτα ο καλεστής κάνει cast",
		m.lobs.size() > 0 and wl.cast_t < 1.0 and wl.act_playing)
	m._update_lobs(m.SUMMON_CAST + 0.01)
	ok("...μετά πετάει μαγικό βλήμα στο κελί", m.lobs.any(func(l): return not l.get("hidden", false)))
	m._update_lobs(m.SUMMON_BOLT + 0.01)
	var circle_on_floor := false
	for fa in m.fx_anims:
		if fa.floor:
			circle_on_floor = true
	ok("...που ανοίγει μαγικό κύκλο στο πάτωμα", circle_on_floor)
	m.flush_actions()
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
		ok("υψώνεται μέσα από τον κύκλο", minion.appear_mode == "rise")

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
		m.flush_actions()
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
	# ένας warlock σε μέγεθος boss: ο καλεστής σε αποτύπωμα 3x2
	var lord = m._make_block(2, 0, m.enemy_by_id["warlock"], 100.0, 3, 2, true)
	summoners.append(lord)
	for s in summoners:
		(s.ability as SummonerAbility).every = 1
	for i in 60:
		for s in summoners:
			s.ability.on_round_end(s, m)
		m.flush_actions()          # το κάλεσμα βγάζει το minion μετά το cast
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
	m.level = 10
	m._add_row()
	await process_frame
	ok("ο mini-boss εμφανίστηκε στον γύρο 10", m.boss != null and not m.boss.is_final)
	if m.boss:
		ok("ο mini-boss είναι ο Goblin King, 3x2", m.boss.kind == "goblin_king"
			and m.boss.cw == 3 and m.boss.ch == 2)
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
		m.flush_actions()          # η πτώση του mini-boss
		for turn in 3:
			m._end_turn()
			m.flush_actions()
			await process_frame
		ok("με ζωντανό boss ο γύρος δεν προχωράει", m.level == 10, "(%d)" % m.level)
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
		ok("ο mini-boss δεν ξεκλειδώνει δράκο", not m.run_dragons.has("frost") and m.boss == null,
			str(m.run_dragons))

		print("--- μεγάλος boss: Grukk's Siege Tower ---")
		for b in m.grid.blocks():
			m.grid.erase(b)
			b.queue_free()
		await process_frame
		var keep_blk = m._make_block(0, 5, m.enemy_by_id["goblin"], 5.0, 1, 1, false)
		m.level = 20
		m._add_row()
		ok("στον γύρο 20 ξεκινάει η είσοδος του boss", m.phase == "boss_intro")
		ok("...και ο χάρτης καθαρίζει με animation, όχι απότομα",
			m.grid.blocks().is_empty() and is_instance_valid(keep_blk) and keep_blk.is_vanishing())
		m._update_boss_intro(m.INTRO_CLEAR + 0.01)
		ok("ο boss πέφτει από ψηλά", m.boss != null and m.boss.position.y
			< m.block_center(m.boss.col, m.boss.row, 3, 3).y - 100.0)
		m.finish_boss_intro()
		var fb = m.boss
		ok("ο μεγάλος boss πιάνει 3x3", fb != null and fb.is_final and fb.cw == 3 and fb.ch == 3
			and fb.kind == "siege_tower")
		ok("...έχει αδύναμο σημείο πάνω, στον Grukk", fb.weak_rect.has_area()
			and fb.weak_rect.position.y < -fb.box.y * 0.3)
		ok("...και ξαναπαίζεις μετά την είσοδο", m.phase == "aim")
		var fb_ab = fb.ability
		fb_ab.siege_every = 1000
		fb_ab.doom = 1000
		var fb_hp0: float = fb.hp
		m._end_turn()
		await process_frame
		ok("ο πύργος δεν κουνιέται", fb.row == 0, "(σειρά %d)" % fb.row)
		ok("όσο ζει ο μεγάλος boss δεν πέφτουν κανονικές σειρές", m.grid.free_cols_in_row(0).size()
			== m.COLS - 3)
		ok("ρίχνει ό,τι βγάζει — βλήματα στον αέρα, και περιμένεις", not m.lobs.is_empty()
			and m.phase == "boss_act", "(%d, %s)" % [m.lobs.size(), m.phase])
		m.flush_actions()
		ok("...που προσγειώνονται: goblin και οδοφράγματα", m.count_kind("goblin") >= 1
			and m.count_kind("barricade") >= 1 and m.phase == "aim",
			"(goblin %d, barricade %d)" % [m.count_kind("goblin"), m.count_kind("barricade")])
		var landed = null
		for b in m.grid.blocks():
			if b.kind == "goblin":
				landed = b
		ok("...και πετάγονται από το βαρέλι με animation", landed != null and landed.appear_t < 1.0
			and landed.appear_mode == "pop")
		var bar = null
		for b in m.grid.blocks():
			if b.kind == "barricade":
				bar = b
		var bar_hp: float = bar.hp if bar else 0.0
		var score0: int = m.score
		if bar:
			bar.take_damage(50.0)
		ok("το οδόφραγμα δεν σπάει και δεν δίνει πόντους", bar != null and bar.hp == bar_hp
			and m.score == score0)
		ok("το οδόφραγμα στήνεται υψώνοντας από το έδαφος", bar != null and bar.appear_mode == "rise")
		# φάση 2: τύμπανα
		fb.take_damage(fb.max_hp * 0.45)
		ok("στο 60% η φάση 2", fb_ab.stage == 2)
		m.flush_actions()
		m._end_turn()
		m.flush_actions()
		await process_frame
		ok("φάση 2: δύο τυμπανιστές δίπλα στον πύργο", m.count_kind("war_drummer") == 2,
			"(%d)" % m.count_kind("war_drummer"))
		ok("...και όσο ζουν ο πύργος έχει ασπίδα", fb.shield_on)
		var hp_before: float = fb.hp
		fb.take_damage(10.0)
		ok("...που τρώει κάθε ζημιά", fb.hp == hp_before)
		for b in m.grid.blocks():
			if b.kind == "war_drummer":
				b.take_damage(b.hp + 1.0)
		await process_frame
		ok("χωρίς τυμπανιστές η ασπίδα πέφτει", not fb.shield_on)
		# φάση 3: μπαρούτι
		fb.take_damage(fb.hp - fb.max_hp * 0.25)
		ok("στο 30% η φάση 3", fb_ab.stage == 3)
		m.flush_actions()
		for b in m.grid.blocks():
			if b.kind == "barricade" or b.kind == "goblin":
				m.grid.erase(b)
				b.queue_free()
		await process_frame
		m._end_turn()
		m.flush_actions()
		await process_frame
		var kegs := []
		for b in m.grid.blocks():
			if b.kind == "powder_keg":
				kegs.append(b)
		ok("φάση 3: βαρέλια μπαρούτι στο ταμπλό, με φυτίλι", kegs.size() >= 1
			and kegs[0].fuse > 0 and not kegs[0].show_hp, "(%d)" % kegs.size())
		if not kegs.is_empty():
			var kg = kegs[0]
			var victim = null
			for dc in [-1, 1]:
				if victim == null and m.grid.is_free(kg.col + dc, kg.row):
					victim = m._make_block(kg.col + dc, kg.row, m.enemy_by_id["goblin"], 50.0, 1, 1, false)
			kg.take_damage(1.0)
			await process_frame
			await process_frame
			ok("χτυπημένο βαρέλι σκάει και παίρνει μαζί του τους γύρω",
				not is_instance_valid(kg) and (victim == null or not is_instance_valid(victim)
					or victim.is_queued_for_deletion()))
		# πολιορκία
		fb_ab.doom = 1
		var siege_row := -1
		var sg = m._make_block(1, 4, m.enemy_by_id["goblin"], 50.0, 1, 1, false)
		siege_row = sg.row
		m._end_turn()
		m.flush_actions()
		await process_frame
		ok("η πολιορκία ρίχνει βράχο και κατεβάζει το ταμπλό", is_instance_valid(sg)
			and sg.row >= siege_row + 2 and fb.row == 0, "(%d -> %d)" % [siege_row, sg.row])
		ok("...και ο μετρητής ξαναγεμίζει", fb_ab.doom > 1)
		for b in m.grid.blocks():
			if b != fb:
				m.grid.erase(b)
				b.queue_free()
		await process_frame
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

	print("--- book ---")
	var bk = m.bestiary
	ok("ο goblin ανήκει στην πρώτη περιοχή, ο Yeti στη δεύτερη",
		bk.area_of("goblin") == 0 and bk.area_of("yeti") == 1)
	var bk_ids0: Array = bk.entries(0).map(func(e): return e.id)
	var bk_ids1: Array = bk.entries(1).map(func(e): return e.id)
	ok("κάθε εχθρός μπαίνει σε μία μόνο σελίδα",
		"goblin" in bk_ids0 and "goblin_king" in bk_ids0 and not "goblin" in bk_ids1
		and "frost_imp" in bk_ids1 and "yeti" in bk_ids1, "(%s | %s)" % [bk_ids0, bk_ids1])
	var bk_all_described := true
	for bk_i in m.areas.size():
		for bk_e in bk.entries(bk_i):
			if bk_e.description == "":
				bk_all_described = false
			for bk_c in bk_e.description:
				if bk_c.unicode_at(0) > 126:
					bk_all_described = false
	ok("κάθε εχθρός έχει περιγραφή σε ASCII", bk_all_described)
	var bk_dummy := EnemyType.new()
	bk_dummy.id = "test_dummy"
	var bk_saved: Array = m.save.get("seen_enemies", []).duplicate()
	# οι πρώτοι εχθροί του test έχουν ήδη βγάλει ειδοποιήσεις· άδειασμα για καθαρή αρχή
	bk.notices.clear()
	bk._born.clear()
	bk._turns.clear()
	bk.saw(bk_dummy)
	bk.saw(bk_dummy)
	ok("νέος εχθρός: μία ειδοποίηση και καταγραφή, όχι δεύτερη φορά",
		bk.notices.size() == 1 and bk.is_seen("test_dummy"))
	bk.press(bk.notice_rect(0).get_center())
	ok("πάτημα στην ειδοποίηση ανοίγει την κάρτα και παγώνει",
		bk.view == "card" and bk.card == bk_dummy and m.frozen() and m.get_tree().paused)
	ok("η ειδοποίηση φεύγει μόλις διαβαστεί", bk.notices.is_empty())
	bk.press(bk.card_button_rect(1).get_center())
	ok("OK κλείνει την κάρτα και ξεπαγώνει", not bk.is_open() and not m.get_tree().paused)
	bk.press(bk.book_button_rect().get_center())
	ok("το κουμπί ανοίγει το Book", bk.view == "book")
	bk.press(bk.tab_rect(1).get_center())
	ok("η καρτέλα αλλάζει σελίδα", bk.book_area == 1)
	bk.press(bk.close_rect(bk.book_rect()).get_center())
	ok("το X κλείνει το Book", not bk.is_open() and not m.get_tree().paused)
	# αυτόματο σβήσιμο: 4 νέοι εχθροί, οι 3 φαίνονται και ο 4ος περιμένει σειρά
	bk._leaving.clear()     # τα tests δεν καλούν _draw(), που τα καθαρίζει
	var bk_auto: Array[EnemyType] = []
	for bk_k in 4:
		var bk_t := EnemyType.new()
		bk_t.id = "test_auto_%d" % bk_k
		bk_auto.append(bk_t)
		bk.saw(bk_t)
	bk.turn_ended()
	ok("ειδοποίηση μένει μετά από 1 γύρο", bk.notices.size() == 4)
	bk.turn_ended()
	ok("...και φεύγει μόνη της μετά από 2 γύρους· η ουρά ανεβαίνει",
		bk.notices.size() == 1 and bk.notices[0] == bk_auto[3] and bk._leaving.size() == 3,
		"(%d, %d)" % [bk.notices.size(), bk._leaving.size()])
	ok("ο εχθρός μένει καταγεγραμμένος στο Book", bk.is_seen("test_auto_0"))
	bk.turn_ended()
	ok("ο 4ος μετράει από τη στιγμή που φάνηκε", bk.notices.size() == 1)
	bk.turn_ended()
	ok("...και φεύγει κι αυτός μετά από 2 δικούς του γύρους", bk.notices.is_empty())
	bk._leaving.clear()
	ok("το κουμπί του Book δεν πέφτει πάνω σε μενού ή παύση",
		not bk.book_button_rect().intersects(m.menu_rect())
		and not bk.book_button_rect().intersects(m.pause_rect()))
	m.save["seen_enemies"] = bk_saved
	SaveManager.save_data(m.save)

	print("--- ροή γύρου ---")
	var before_level = m.level
	m._end_turn()
	await process_frame
	ok("ο γύρος προχώρησε", m.level == before_level + 1, "(%d)" % m.level)
	ok("μετά τον boss πάμε στην επόμενη περιοχή", m.area_index == 1, "(%d)" % m.area_index)
	ok("η αλλαγή περιοχής ξεκινάει cinematic", m.in_transition() and m.phase == "transition")
	ok("...και ως το μαύρο φαίνεται ακόμα η παλιά περιοχή", m.visual_area_index == 0)
	m._update_transition(m.TRANS_OUT)
	ok("...στο μαύρο η οθόνη είναι σκεπασμένη", is_equal_approx(m.transition_alpha(), 1.0))
	var tr_ids := []
	for e in m.areas[1].enemies:
		tr_ids.append(e.id)
	var tr_old := 0
	for b in m.grid.blocks():
		if not tr_ids.has(b.kind):
			tr_old += 1
	ok("...εκεί καθαρίζει το ταμπλό και μπαίνει σειρά της νέας περιοχής",
		m.visual_area_index == 1 and m.grid.blocks().size() > 0 and tr_old == 0,
		"(%d παλιοί)" % tr_old)
	m.finish_transition()
	ok("...και στο τέλος ξαναπαίζεις", not m.in_transition() and m.phase == "aim"
		and m.transition_alpha() == 0.0)
	await process_frame
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
	# κανένας εχθρός, σε καμία περιοχή, δεν μένει με στατικό πορτρέτο
	# τα αντικείμενα του ταμπλό (οδόφραγμα, βαρέλι) δεν είναι πλάσματα: το
	# οδόφραγμα δεν σπάει, το βαρέλι σκάει — δεν «αντιδρούν» σε χτύπημα
	var still := []
	for id in m.enemy_by_id:
		if m.enemy_by_id[id].frames_idle.is_empty() and not m.enemy_by_id[id].hidden_in_book:
			still.append(id)
	ok("κανένας εχθρός χωρίς idle", still.is_empty(), str(still))
	var no_hit := []
	for id in m.enemy_by_id:
		if m.enemy_by_id[id].frames_hit.is_empty() and not m.enemy_by_id[id].hidden_in_book:
			no_hit.append(id)
	ok("κανένας εχθρός χωρίς αντίδραση στο χτύπημα", no_hit.is_empty(), str(no_hit))
	for id in ["knight", "warlock"]:
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
	ok("ο boss του Frost Marches είναι ο Yeti",
		m.areas[1].boss.id == "yeti", m.areas[1].boss.id)
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
	ok("ο boss καλεί με βρυχηθμό, όχι με τη μαγεία του warlock",
		king.cast_style == "roar" and king.cast_t < 1.0)
	m._update_lobs(m.WARCRY_TIME * 0.45 + 0.2)
	var flyers := 0
	var circles := 0
	for fl in m.lobs:
		if fl.has("frames"):
			flyers += 1
	for fa in m.fx_anims:
		if fa.floor and fa.frames == m.summon_frames:
			circles += 1
	ok("...και τα bats έρχονται πετώντας, χωρίς μαγικό κύκλο", flyers == 2 and circles == 0,
		"(%d πετάνε, %d κύκλοι)" % [flyers, circles])
	m.flush_actions()
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

	print("--- freeze ---")
	m.phase = "aim"
	m.aiming = false
	m.freeze_rounds = 0
	# καθαρό ταμπλό: το προηγούμενο καθάρισμα αφήνει μέσα όσους έχουν ήδη
	# ελευθερωθεί, και το _end_turn θα σκόνταφτε πάνω τους
	m.grid = BattleGrid.new(m.COLS)
	m.boss = null
	m._add_row()
	var fz_dg: DragonType = m.dragon
	var fz_special: String = fz_dg.special
	fz_dg.special = "freeze"
	m.special_charge = fz_dg.special_cost
	m._use_special()
	ok("το FREEZE παγώνει για 2 γύρους και ξυπνάει τη μορφή",
		m.freeze_rounds == m.FREEZE_ROUNDS and (m.awake_active or fz_dg.awakened == null))
	var fz_rows := {}
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		fz_rows[fz_b] = fz_b.row
	var fz_count: int = m.grid.blocks().filter(func(x): return is_instance_valid(x)).size()
	var fz_level: int = m.level
	var fz_tinted := true
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		if fz_b.self_modulate == Color.WHITE:
			fz_tinted = false
	ok("οι παγωμένοι εχθροί βάφονται", fz_count > 0 and fz_tinted, "(%d)" % fz_count)
	m._end_turn()
	var fz_still: bool = m.grid.blocks().filter(func(x): return is_instance_valid(x)).size() == fz_count
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		if fz_rows.get(fz_b, -1) != fz_b.row:
			fz_still = false
	ok("1ος παγωμένος γύρος: κανείς δεν κουνιέται, καμία νέα σειρά", fz_still)
	ok("...ο γύρος μετράει κανονικά", m.level == fz_level + 1)
	ok("...και η μορφή κρατάει", m.freeze_rounds == 1
		and (m.awake_active or fz_dg.awakened == null))
	m._end_turn()
	fz_still = m.grid.blocks().filter(func(x): return is_instance_valid(x)).size() == fz_count
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		if fz_rows.get(fz_b, -1) != fz_b.row:
			fz_still = false
	var fz_thawed := true
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		if fz_b.self_modulate != Color.WHITE:
			fz_thawed = false
	ok("2ος παγωμένος γύρος: πάλι ακίνητοι", fz_still)
	ok("στο τέλος του λιώνει και η μορφή τελειώνει",
		m.freeze_rounds == 0 and not m.awake_active and fz_thawed)
	m._end_turn()
	var fz_moved: bool = m.grid.blocks().filter(func(x): return is_instance_valid(x)).size() != fz_count
	for fz_b in m.grid.blocks().filter(func(x): return is_instance_valid(x)):
		if fz_rows.has(fz_b) and fz_rows[fz_b] != fz_b.row:
			fz_moved = true
	ok("μετά το ξεπάγωμα οι εχθροί ξανακατεβαίνουν", fz_moved)
	fz_dg.special = fz_special
	for left_over in m.grid.blocks():
		if is_instance_valid(left_over):
			m.grid.erase(left_over)
			left_over.queue_free()
	await process_frame

	print("--- frost marches ---")
	m.grid = BattleGrid.new(m.COLS)
	m.boss = null
	m.freeze_rounds = 0
	var fm: AreaDef = m.areas[1]
	var fm_ids: Array = fm.enemies.map(func(e): return e.id)
	ok("οι εχθροί του Frost Marches", fm_ids == ["frost_imp", "snow_wolf", "viking", "crystal_golem"],
		str(fm_ids))
	ok("το shardling μένει έξω από τη νέα σειρά",
		fm.minions.size() == 1 and fm.minions[0].id == "shardling")
	# αγέλη: δύο λύκοι δίπλα-δίπλα κατεβαίνουν 2, ο μοναχικός 1
	var wolf_t: EnemyType = m.enemy_by_id["snow_wolf"]
	var w1 = m._make_block(2, 3, wolf_t, 5.0, 1, 1, false)
	var w2 = m._make_block(3, 3, wolf_t, 5.0, 1, 1, false)
	var w3 = m._make_block(6, 3, wolf_t, 5.0, 1, 1, false)
	for wb in [w1, w2, w3]:
		wb.ability.before_advance(wb, m)
	ok("λύκος με λύκο δίπλα: 2 σειρές",
		w1.ability.advance_rows(w1, 1) == 2 and w2.ability.advance_rows(w2, 1) == 2)
	ok("μοναχικός λύκος: 1 σειρά", w3.ability.advance_rows(w3, 1) == 1)
	for wb in [w1, w2, w3]:
		m.grid.erase(wb)
		wb.queue_free()
	await process_frame
	# θρυμματισμός: ο golem σπάει σε δύο θραύσματα, στο κελί του και δίπλα
	var golem = m._make_block(3, 4, m.enemy_by_id["crystal_golem"], 3.0, 1, 1, false)
	golem.take_damage(99.0)
	await process_frame
	await process_frame
	var shards: Array = m.grid.blocks().filter(func(x): return is_instance_valid(x) and x.kind == "shardling")
	ok("ο golem έσπασε σε 2 θραύσματα", shards.size() == 2, "(%d)" % shards.size())
	ok("...γύρω από το κελί του", shards.all(func(x): return absi(x.col - 3) + absi(x.row - 4) <= 1))
	for sb in shards:
		m.grid.erase(sb)
		sb.queue_free()
	await process_frame
	# αναγέννηση: ο Yeti γιατρεύεται μόνο αν πέρασε γύρος χωρίς χτύπημα
	var yeti = m._make_block(2, 0, m.enemy_by_id["yeti"], 100.0, 3, 2, true)
	yeti.hp = 50.0
	yeti.ability.on_round_end(yeti, m)
	ok("ο Yeti γιατρεύτηκε μετά από ήσυχο γύρο", yeti.hp > 50.0, "(%.1f)" % yeti.hp)
	var yeti_hp: float = yeti.hp
	yeti.take_damage(1.0)
	yeti.ability.on_round_end(yeti, m)
	ok("...αλλά όχι αν χτυπήθηκε", yeti.hp == yeti_hp - 1.0, "(%.1f)" % yeti.hp)
	ok("η γιατρειά δεν περνάει τη μέγιστη ζωή", (func():
		yeti.heal(9999.0)
		return yeti.hp == yeti.max_hp).call())
	for left_over in m.grid.blocks():
		if is_instance_valid(left_over):
			m.grid.erase(left_over)
			left_over.queue_free()
	m.grid = BattleGrid.new(m.COLS)
	m.boss = null
	await process_frame
	# ο νέος frost
	var fr: DragonType
	for x in m.dragons:
		if x.id == "frost":
			fr = x
	ok("ο frost ρίχνει FREEZE", fr.special == "freeze")
	ok("ο frost ρίχνει παγοκρυστάλλους", fr.ball_sprite != null and fr.ball_aoe_sprite != null)
	ok("ο frost δεν βάφεται πια γαλάζιος", fr.tint == Color.WHITE)
	var fr_aw: DragonType = fr.awakened
	ok("έχει εξελιγμένη μορφή, διπλάσια", fr_aw != null and fr_aw.draw_width == fr.draw_width * 2.0)
	var fr_sz := {}
	for tex in fr_aw.frames_idle + fr_aw.frames_ready + fr_aw.frames_fire:
		fr_sz[tex.get_size()] = true
	ok("η εξελιγμένη σε ίδιο καμβά σε όλες τις καταστάσεις", fr_sz.size() == 1, str(fr_sz.keys()))
	ok("η εξελιγμένη κινείται: 3 καρέ σε κάθε κατάσταση",
		fr_aw.frames_idle.size() == 3 and fr_aw.frames_ready.size() == 3 and fr_aw.frames_fire.size() == 3)
	ok("...και έχει αύρα από ρούνες, η βασική όχι", fr_aw.glyph_aura and not fr.glyph_aura)
	# ο κρύσταλλος γυρνάει με την πορεία: η μύτη του (heading) κοιτάει εκεί που πάει
	ok("ο παγοκρύσταλλος έχει μύτη πάνω-δεξιά", is_equal_approx(fr.ball_heading, -PI / 4.0))
	var fb_ball = m.BallScene.instantiate()
	fb_ball.heading = fr.ball_heading
	fb_ball.velocity = Vector2(1, -1)           # προς τα πάνω-δεξιά
	ok("...οπότε προς τα πάνω-δεξιά δεν γυρνάει καθόλου",
		is_zero_approx(wrapf(fb_ball.velocity.angle() - fb_ball.heading, -PI, PI)))
	fb_ball.free()

	print("--- σκηνικό και καιρός ---")
	m.area_index = 1
	m._apply_theme()
	ok("στο Frost Marches το πλαίσιο είναι χιονισμένο",
		m.tex_frame_left.resource_path.ends_with("frame_left_frost.png"), m.tex_frame_left.resource_path)
	ok("...και οι δάδες με μπλε φλόγα",
		m.torch_frames.size() == 5 and m.torch_frames[0].resource_path.ends_with("_frost.png"))
	m.weather._process(0.1)
	ok("στο Frost Marches χιονίζει", m.weather._active == "snow" and m.weather._flakes.size() > 0)
	m.area_index = 0
	m._apply_theme()
	m.weather._process(0.1)
	ok("στο Goblin Land ξαναγυρνάει το κανονικό σκηνικό",
		m.tex_frame_left.resource_path.ends_with("frame_left.png"))
	ok("...και δεν χιονίζει", m.weather._active == "" and m.weather._flakes.is_empty())

	print("--- graveyard ---")
	ok("υπάρχει 3η περιοχή, το Graveyard", m.areas.size() >= 3 and m.areas[2].id == "graveyard")
	var gy = m.areas[2]
	var gy_ids := []
	for e in gy.enemies:
		gy_ids.append(e.id)
	ok("...με σκελετούς, ghoul, ghost", gy_ids.has("skeleton") and gy_ids.has("ghoul")
		and gy_ids.has("ghost") and gy_ids.has("skeleton_warrior"), str(gy_ids))
	ok("...boss ο Grim Reaper που καλεί νυχτερίδες", gy.boss.id == "reaper"
		and _find_summoner(gy.boss.ability) != null
		and _find_summoner(gy.boss.ability).minion_id == "grave_bat"
		and m.enemy_by_id.has("grave_bat"))
	var gy_no_anim := []
	for e in gy.enemies + gy.minions + [gy.boss]:
		if e.frames_idle.is_empty():
			gy_no_anim.append(e.id)
	ok("...κάθε εχθρός του έχει idle animation", gy_no_anim.is_empty(), str(gy_no_anim))
	m.area_index = 2
	m._apply_theme()
	m.weather._process(0.1)
	ok("στο Graveyard έχει ομίχλη αντί για χιόνι", m.weather._active == "fog"
		and m.weather._fog.size() > 0 and m.weather._flakes.is_empty())
	ok("...και σκοτεινό σκηνικό", m.tex_frame_left.resource_path.ends_with("frame_left_grave.png"))
	m.area_index = 0
	m._apply_theme()
	m.weather._process(0.1)
	ok("γυρνώντας πίσω η ομίχλη φεύγει", m.weather._active == "" and m.weather._fog.is_empty())

	print("--- drowned coast ---")
	ok("υπάρχει 4η περιοχή, το Drowned Coast", m.areas.size() >= 4 and m.areas[3].id == "drowned_coast")
	var dc = m.areas[3]
	var dc_ids := []
	for e in dc.enemies:
		dc_ids.append(e.id)
	ok("...με ψαροειδή τέρατα", dc_ids.has("murkfin") and dc_ids.has("razorjaw")
		and dc_ids.has("shellback") and dc_ids.has("drift_jelly"), str(dc_ids))
	ok("...ο Razorjaw κυνηγάει σε αγέλη, ο Shellback έχει ασπίδα",
		dc.enemies[dc_ids.find("razorjaw")].ability is PackHunterAbility
		and dc.enemies[dc_ids.find("shellback")].ability is ShieldAbility)
	ok("...boss ο Abyssal Angler που καλεί Bitefins", dc.boss.id == "angler"
		and _find_summoner(dc.boss.ability) != null
		and _find_summoner(dc.boss.ability).minion_id == "bitefin"
		and m.enemy_by_id.has("bitefin"))
	var dc_no_anim := []
	for e in dc.enemies + dc.minions + [dc.boss]:
		if e.frames_idle.is_empty() or e.frames_hit.is_empty():
			dc_no_anim.append(e.id)
	ok("...κάθε εχθρός του έχει idle και hit animation", dc_no_anim.is_empty(), str(dc_no_anim))
	var dc_sizes_ok: bool = dc.background_frames.size() >= 2
	for bf in dc.background_frames:
		if bf.get_size() != dc.background.get_size():
			dc_sizes_ok = false
	ok("το δάπεδο κυματίζει: καρέ ίδιου μεγέθους με το φόντο", dc_sizes_ok,
		"(%d καρέ)" % dc.background_frames.size())
	m.area_index = 3
	m._apply_theme()
	m.weather._process(0.1)
	ok("στο Drowned Coast βρεγμένο σκηνικό με δικούς του τοίχους",
		m.tex_frame_left.resource_path.ends_with("frame_left_sea.png")
		and m.tex_frame_top.resource_path.ends_with("frame_top_sea.png"))
	ok("...χωρίς χιόνι ή ομίχλη", m.weather._active == "")
	m.area_index = 0
	m._apply_theme()

	print("--- fisher και HARPOON ---")
	var fi: DragonType = m.dragon_by_id("fisher")
	ok("υπάρχει ο δράκος ψαράς", fi != null and fi.special == "harpoon"
		and fi.special_name() == "HARPOON")
	ok("...με 3 καρέ ανά κατάσταση, ίδιου καμβά", fi != null and fi.frames_idle.size() == 3
		and fi.frames_ready.size() == 3 and fi.frames_fire.size() == 3
		and fi.frames_fire[0].get_size() == fi.frames_idle[0].get_size())
	ok("...καμάκι και αγκίστρια για βλήματα", fi != null and fi.ball_sprite != null
		and fi.ball_aoe_sprite != null and fi.ball_sprite != fi.ball_aoe_sprite)
	ok("...ξεκλειδώνει μετά το Graveyard", fi != null and fi.unlock_after_area == 3)
	var hp_dg: DragonType = m.dragon
	var hp_special: String = hp_dg.special
	hp_dg.special = "harpoon"
	m.phase = "aim"
	m.special_charge = hp_dg.special_cost
	m._use_special()
	ok("το HARPOON οπλίζει τη βολή", m.harpoon_active and m.special_charge == 0.0)
	for hp_old in m.grid.blocks():
		if is_instance_valid(hp_old):
			hp_old.queue_free()
	m.grid = BattleGrid.new(m.COLS)
	m.boss = null
	await process_frame
	var hp_near = m._make_block(3, 6, m.enemy_by_id["goblin"], 20.0, 1, 1, false)
	var hp_far = m._make_block(3, 3, m.enemy_by_id["goblin"], 20.0, 1, 1, false)
	m._make_ball(Vector2.UP)
	var hp_ball = null
	for hb_n in m.get_children():
		if hb_n is Ball:
			hp_ball = hb_n
	ok("...και η μπάλα της βολής διαπερνάει", hp_ball != null and hp_ball.pierce)
	if hp_ball:
		hp_ball.position = m.block_center(3, 8, 1, 1)
		# χωρίς αυτό, όταν πέσει στο δάπεδο θα έκλεινε μόνη της τον γύρο
		hp_ball.died.disconnect(m._on_ball_died)
	for hp_i in 50:
		await physics_frame
	ok("το καμάκι περνάει μέσα από τον πρώτο και βρίσκει και τον πίσω",
		hp_near.hp < 20.0 and hp_far.hp < 20.0, "(%.1f / %.1f)" % [hp_near.hp, hp_far.hp])
	ok("...χτυπάει τον καθένα μία φορά", hp_near.hp == 19.0, "(%.1f)" % hp_near.hp)
	if is_instance_valid(hp_ball):
		hp_ball.queue_free()
	m.live_balls = 0
	m.to_fire = 0
	m._end_turn()
	ok("η επόμενη βολή είναι πάλι κανονική", not m.harpoon_active)
	hp_dg.special = hp_special
	for hp_b in m.grid.blocks():
		if is_instance_valid(hp_b):
			hp_b.queue_free()
	m.grid = BattleGrid.new(m.COLS)
	m.boss = null
	m.phase = "aim"
	await process_frame

	print("--- νιφάδα του freeze ---")
	var fz = m._make_block(1, 6, m.enemy_by_id["goblin"], 9.0, 1, 1, false)
	ok("χωρίς πάγωμα δεν έχει νιφάδα", not fz.frozen)
	m.freeze_rounds = 2
	m._paint_frozen()
	ok("το FREEZE βάζει νιφάδα σε κάθε εχθρό", fz.frozen)
	var fz2 = m._make_block(2, 6, m.enemy_by_id["goblin"], 9.0, 1, 1, false)
	ok("...και σε όποιον γεννιέται μέσα στο πάγωμα", fz2.frozen)
	fz._process(fz.FLAKE_LIFE + 0.1)
	ok("η νιφάδα σβήνει μετά από λίγο, ο εχθρός μένει παγωμένος",
		fz.frozen and fz.frozen_t >= fz.FLAKE_LIFE and fz.FLAKE_LIFE >= 1.5 and fz.FLAKE_LIFE <= 2.0)
	m.freeze_rounds = 0
	m._paint_frozen()
	ok("όταν λιώσει, η νιφάδα φεύγει", not fz.frozen and not fz2.frozen)
	ok("η νιφάδα είναι pixel art 13x13", fz.flake_tex().get_size() == Vector2(13, 13))
	for fzb in [fz, fz2]:
		m.grid.erase(fzb)
		fzb.queue_free()
	await process_frame

	print("--- λάμψη χτυπήματος ---")
	var hb_gob = m._make_block(0, 5, m.enemy_by_id["goblin"], 9.0, 1, 1, false)
	var hb_bat = m._make_block(2, 5, m.enemy_by_id["bat"], 9.0, 1, 1, false)
	var hb_boss = m._make_block(2, 0, m.enemy_by_id["goblin_king"], 90.0, 3, 2, true)
	ok("boss και minions σκάνε έκρηξη, οι απλοί κρατάνε το δαχτυλίδι",
		hb_boss.uses_burst() and hb_bat.uses_burst() and not hb_gob.uses_burst())
	hb_bat.take_damage(1.0)
	ok("το χτύπημα ξεκινάει την έκρηξη", hb_bat.burst_t == 0.0)
	hb_bat._process(1.0)
	ok("...και τελειώνει μόνη της", hb_bat.burst_t == 1.0)
	ok("η έκρηξη παίρνει το χρώμα του δράκου", hb_bat.burst_color == m._accent(1.0))
	for hb in [hb_gob, hb_bat, hb_boss]:
		m.grid.erase(hb)
		hb.queue_free()
	m.boss = null
	await process_frame

	print("--- ακύρωση στόχευσης ---")
	m.phase = "aim"
	m.aiming = true
	m._set_aim(Vector2(m.W * 0.5, m.floor_y - 300.0))
	ok("σημάδι προς τα πάνω δεν ακυρώνει", not m.aim_cancel)
	m._set_aim(Vector2(m.W * 0.5, m.floor_y + 80.0))
	ok("τέρμα κάτω, πάνω στον δράκο, οπλίζει την ακύρωση", m.aim_cancel)
	var ac_up := InputEventMouseButton.new()
	ac_up.button_index = MOUSE_BUTTON_LEFT
	ac_up.pressed = false
	m._unhandled_input(ac_up)
	ok("...και το άφημα εκεί δεν ρίχνει", m.phase == "aim" and not m.aiming and not m.aim_cancel)

	print("--- μουσική ---")
	m.area_index = 0
	m._apply_theme()
	var goblin_song = m.areas[0].music
	ok("το Goblin Land έχει soundtrack", goblin_song != null and m.music.stream == goblin_song)
	var song_len: float = goblin_song.get_length()
	m.music.tick(0.0, song_len - 10.0, true)
	ok("...που δεν μπαίνει σε crossfade πριν την ώρα του", not m.music.is_crossfading())
	m.music.tick(0.0, song_len - MusicPlayer.XFADE + 0.1, true)
	ok("...και λίγο πριν το τέλος ξεκινάει crossfade με την αρχή", m.music.is_crossfading())
	m.music.tick(MusicPlayer.XFADE * 0.5, 0.0, true)
	ok("...που στη μέση δεν βουλιάζει", m.music.current_volume() > m.music.volume * 0.6)
	m.music.tick(MusicPlayer.XFADE, 0.0, true)
	ok("...και τελειώνει ομαλά", not m.music.is_crossfading()
		and absf(m.music.current_volume() - m.music.volume) < 0.01)
	m.area_index = 1
	m._apply_theme()
	ok("περιοχή χωρίς μουσική = σιωπή", m.music.stream == null)
	m.area_index = 2
	m._apply_theme()
	var grave_song = m.areas[2].music
	ok("το Graveyard έχει δικό του soundtrack", grave_song != null and grave_song != goblin_song
		and m.music.stream == grave_song)
	ok("...που κι αυτό κλείνει τη λούπα με crossfade, όχι στο import",
		grave_song != null and not grave_song.loop)
	m.area_index = 0
	m._apply_theme()
	var vbar: Rect2 = m.volume_bar_rect()
	m.volume_open = true
	m._volume_press(Vector2(vbar.position.x + vbar.size.x * 0.25, vbar.get_center().y))
	ok("πάτημα στη μπάρα αλλάζει την ένταση", absf(m.music_volume() - 0.25) < 0.01,
		"(%.2f)" % m.music_volume())
	ok("...και ο player την ακολουθεί", absf(m.music.current_volume() - 0.25) < 0.01)
	m.volume_drag = false
	m._volume_press(m.volume_mute_rect().get_center())
	ok("το mute του πάνελ σωπαίνει τη μουσική", m.music_muted() and m.music.paused)
	m._set_volume_at(vbar.end.x)
	ok("σύρσιμο της έντασης βγάζει από το mute", not m.music_muted() and not m.music.paused)
	m._set_volume_at(vbar.position.x - 50.0)
	ok("ένταση στο μηδέν = σιωπή", m.music_silent() and m.music.paused)
	m._volume_press(Vector2(5.0, m.H - 5.0))
	ok("πάτημα έξω από το πάνελ το κλείνει", not m.volume_open)
	m.save["music_volume"] = 0.8
	m.save["music_muted"] = false
	m._apply_music_volume()

	print("--- animations ικανοτήτων ---")
	for ab_b in m.grid.blocks():
		m.grid.erase(ab_b)
		ab_b.queue_free()
	await process_frame
	m.fx_anims.clear()
	m.area_index = 0
	m.level = 3
	m.boss = null
	m.freeze_rounds = 0
	var ch_r = m._make_block(3, 1, m.enemy_by_id["orc"], 50.0, 1, 1, false)
	ch_r.ability._rounds = 1                  # ο επόμενος γύρος είναι διπλό βήμα
	m.phase = "aim"
	var sum_wl = m._make_block(6, 1, m.enemy_by_id["warlock"], 50.0, 1, 1, false)
	sum_wl.ability.every = 1
	m.fx_anims.clear()
	m._end_turn()
	ok("πρώτα κατεβαίνουν όλοι μία σειρά, ο καβαλάρης μαζί τους",
		ch_r.row == 2 and m.phase == "boss_act", "(σειρά %d)" % ch_r.row)
	ok("...και κανείς δεν καλεί όσο κινούνται", sum_wl.cast_t >= 1.0)
	m._update_lobs(m.ADVANCE_TIME + m.ABILITY_GAP + 0.01)
	ok("μετά, χωριστά, το dash του καβαλάρη", ch_r.row == 3 and sum_wl.cast_t >= 1.0,
		"(σειρά %d)" % ch_r.row)
	m._update_lobs(m.CHARGE_TIME + m.ABILITY_GAP + 0.01)
	ok("και τελευταίο το κάλεσμα", sum_wl.cast_t < 1.0)
	m.flush_actions()
	await process_frame
	ok("ο καβαλάρης κάνει διπλό βήμα", ch_r.row == 3, "(σειρά %d)" % ch_r.row)
	var arrows_on_skip := false
	for fa in m.fx_anims:
		if fa.frames == m.charge_frames and absf(fa.pos.y - m.block_center(3, 2, 1, 1).y) < 1.0:
			arrows_on_skip = true
	ok("...και στο κελί που πήδηξε φαίνονται βελάκια ταχύτητας", arrows_on_skip)
	var kn2 = m._make_block(5, 4, m.enemy_by_id["knight"], 20.0, 1, 1, false)
	var fake_ball := Node2D.new()
	fake_ball.set("position", kn2.position + Vector2(-60, 0))
	var fb_script := GDScript.new()
	fb_script.source_code = "extends Node2D\nvar damage := 1.0\nvar splashed := {}\n"
	fb_script.reload()
	fake_ball.set_script(fb_script)
	fake_ball.position = kn2.position + Vector2(-60, 0)
	var sparks0: int = m.sparks.size()
	m._on_ball_struck(kn2, fake_ball)
	ok("ο knight με ασπίδα: ανάβει το περίγραμμά του αντί για σπίθες",
		kn2.guard_t < 1.0 and kn2.guard_dir == Vector2.LEFT and m.sparks.size() == sparks0
		and kn2.flash == 0.0)
	kn2.ability.shield = 0.0
	kn2.guard_t = 1.0
	m._on_ball_struck(kn2, fake_ball)
	ok("...χωρίς ασπίδα ξανά οι κανονικές σπίθες", kn2.guard_t >= 1.0 and m.sparks.size() > sparks0)
	fake_ball.free()
	for ab_b in m.grid.blocks():
		m.grid.erase(ab_b)
		ab_b.queue_free()
	await process_frame
	m.area_index = 0
	m.level = m.MINIBOSS_ROUND
	m.boss = null
	m.phase = "shoot"
	m._add_row()
	var mb = m.boss
	ok("ο mini-boss πέφτει από τον ουρανό", mb != null and mb.position.y
		< m.block_center(mb.col, mb.row, mb.cw, mb.ch).y - 100.0)
	m.fx_anims.clear()
	m._mini_landed(mb)
	var crack_cells := 0
	var cracks_inside := true
	var foot := Rect2(m.pf_left + mb.col * m.cell, m.PF_TOP + mb.row * m.cell, mb.cw * m.cell, mb.ch * m.cell)
	for fa in m.fx_anims:
		if fa.floor and fa.frames[0] == m.tex_cracks:
			crack_cells += 1
			if not fa.has("clip") or not foot.grow(0.5).encloses(fa.clip):
				cracks_inside = false
	ok("...στην προσγείωση ρωγμές μόνο στα κελιά του, πίσω του",
		crack_cells == mb.cw * mb.ch and cracks_inside, "(%d κελιά)" % crack_cells)
	var emote_now := false
	for fa in m.fx_anims:
		if fa.pop:
			emote_now = true
	ok("...το emote δεν σκάει αμέσως", not emote_now)
	m._update_soft(m.EMOTE_DELAY + 0.01)
	var has_emote := false
	for fa in m.fx_anims:
		if fa.pop:
			has_emote = true
	ok("...αλλά ένα δευτερόλεπτο μετά, με βρυχηθμό", has_emote and mb.act_playing)
	mb.queue_free()
	m.grid.erase(mb)
	m.boss = null
	m.lobs.clear()
	m.phase = "aim"
	await process_frame

	print("--- test menu ---")
	var tb: Array[Rect2] = [m.debug_rect(), m.mute_rect(), m.pause_rect(), m.menu_rect(),
		m.bestiary.book_button_rect()]
	var tb_overlap := false
	for i in tb.size():
		for j in range(i + 1, tb.size()):
			if tb[i].intersects(tb[j]):
				tb_overlap = true
	ok("το κουμπί TEST δεν πέφτει πάνω σε άλλο κουμπί", not tb_overlap and m.debug_rect().end.y < m.PF_TOP)
	m.phase = "aim"
	ok("το test menu είναι ενεργό για δοκιμές", m.debug_menu)
	m.debug_open = true
	var tm_btns: Array = m.debug_buttons()
	var tm_last: Rect2 = m.debug_button_rect(tm_btns.size() - 1)
	ok("όλα τα κουμπιά χωράνε στο πάνελ", m.debug_panel_rect().encloses(tm_last)
		and m.debug_panel_rect().end.y < m.ui_top)
	var balls0: int = m.ball_count
	m._debug_do("balls", 10)
	ok("+10 BALLS", m.ball_count == balls0 + 10)
	m._debug_press(m.debug_button_rect(2).get_center())      # GRAVEYARD - START
	ok("άλμα στην αρχή του Graveyard", m.area_index == 2 and m.area_round() == 1
		and m.visual_area_index == 2 and not m.debug_open and m.phase == "aim",
		"(περιοχή %d, γύρος %d)" % [m.area_index, m.area_round()])
	m._debug_do("jump", [0, "mini"])
	ok("άλμα στον mini-boss του Goblin Land", m.area_index == 0 and m.boss != null
		and m.boss.kind == "goblin_king")
	m._debug_do("jump", [0, "boss"])
	ok("άλμα στον μεγάλο boss: ξεκινάει η είσοδός του", m.phase == "boss_intro")
	m.finish_boss_intro()
	ok("...και ο πύργος είναι στο ταμπλό", m.boss != null and m.boss.is_final)
	var bhp: float = m.boss.hp
	m._debug_do("hurt_boss", 0.5)
	ok("BOSS -50%", absf(m.boss.hp - bhp * 0.5) < 1.0)
	m.debug_open = true
	m._debug_press(Vector2(4, m.H - 4))
	ok("πάτημα έξω κλείνει το μενού", not m.debug_open)

	print("--- μεγάλος boss: Ice Wendigo ---")
	m._debug_do("jump", [1, "boss"])
	m.finish_boss_intro()
	var wd = m.boss
	ok("ο Ice Wendigo είναι ο μεγάλος boss του Frost Marches", wd != null and wd.is_final
		and wd.kind == "ice_wendigo" and wd.cw == 3 and wd.ch == 3)
	var wd_ab = wd.ability
	ok("...το HUD λέει πότε έρχονται παγόβουνα", m.boss_label().begins_with("ICEBERGS"), m.boss_label())
	ok("...δεν κουνιέται", wd_ab.advance_rows(wd, 1) == 0)
	wd_ab.berg_wait = 1
	m._end_turn()
	ok("χτυπάει το έδαφος και ο παίκτης περιμένει τα παγόβουνα", m.phase == "boss_act"
		and wd.act_playing)
	m.flush_actions()
	await process_frame
	var bergs := []
	for wb in m.grid.blocks():
		if wb.kind == "iceberg":
			bergs.append(wb)
	ok("τα παγόβουνα βγαίνουν από το πάτωμα", bergs.size() == wd_ab.icebergs
		and bergs[0].appear_mode == "rise" and m.phase == "aim", "(%d, %s)" % [bergs.size(), m.phase])
	wd_ab.berg_wait = 99
	if bergs.size() >= 2:
		var bg = bergs[0]
		var bg_row: int = bg.row
		bg.take_damage(bg.max_hp * 0.5)
		ok("παγόβουνο που τρώει ζημιά ραγίζει", bg.ability.crack == 1
			and bg.portrait_frame() == bg.ability.crack_frames[1])
		var mobs0: int = m.count_kind("frost_imp") + m.count_kind("snow_wolf")
		bg.take_damage(bg.hp + 1.0)
		await process_frame
		await process_frame
		var mobs1: int = m.count_kind("frost_imp") + m.count_kind("snow_wolf")
		ok("σπασμένο παγόβουνο βγάζει τέρατα από μέσα", mobs1 > mobs0, "(%d -> %d)" % [mobs0, mobs1])
		var bg2 = bergs[1]
		var bg2_row: int = bg2.row
		m._end_turn()
		m.flush_actions()
		await process_frame
		ok("τα παγόβουνα δεν κατεβαίνουν", is_instance_valid(bg2) and bg2.row == bg2_row,
			"(%d)" % bg_row)
		bg2.life_turns = 1
		m._end_turn()
		m.flush_actions()
		ok("αχτύπητο παγόβουνο λιώνει μόνο του", bg2.is_vanishing())
	# βλέμμα: η βολή παγώνει και χάνεται
	for wb in m.grid.blocks():
		if wb != wd:
			m.grid.erase(wb)
			wb.queue_free()
	await process_frame
	m.phase = "shoot"
	m.live_balls = 0
	for gb_i in 3:
		m._make_ball(Vector2.UP)
	m.to_fire = 5
	wd_ab._glare_at = 1
	wd_ab._hits = 0
	wd.take_damage(1.0)
	var glare_balls: Array = m.get_tree().get_nodes_in_group("ball")
	var all_freezing: bool = not glare_balls.is_empty()
	for gb in glare_balls:
		if gb.freeze_in < 0.0:
			all_freezing = false
	ok("βλέμμα: λάμψη, οι μπάλες παγώνουν και τα υπόλοιπα δεν φεύγουν", m.glare_t >= 0.0
		and m.to_fire == 0 and all_freezing)
	m._shatter_balls()
	await process_frame
	ok("...οι μπάλες σπάνε και η βολή τελειώνει", m.get_tree().get_nodes_in_group("ball").is_empty()
		and m.live_balls == 0 and m.phase != "shoot", "(%d, %s)" % [m.live_balls, m.phase])
	m.flush_actions()
	ok("...όχι δεύτερο βλέμμα στον επόμενο γύρο", wd_ab._glare_at == -1)
	# μισή ζωή: πάγωμα, θύελλα, κύμα, γιατρειά
	for wb in m.grid.blocks():
		if wb != wd:
			m.grid.erase(wb)
			wb.queue_free()
	await process_frame
	wd.take_damage(wd.hp - wd.max_hp * 0.45)
	ok("στη μισή ζωή παγώνει μέσα σε πάγο", wd_ab.stage == 2 and wd.shield_on
		and wd.frames_idle == wd_ab.frozen_idle)
	ok("...και πιάνει χιονοθύελλα", m.weather._storm_want == 1.0)
	var wd_h0: float = wd.hp
	wd.take_damage(50.0)
	ok("...όσο είναι παγωμένος δεν τρώει ζημιά", wd.hp == wd_h0)
	m._end_turn()
	m.flush_actions()
	await process_frame
	var mist_n := 0
	for wb in m.grid.blocks():
		if wb.has_meta("wave") and wb.appear_mode == "mist":
			mist_n += 1
	ok("το κύμα βγαίνει μέσα από την ομίχλη", m.wave_left() >= 6 and mist_n == m.wave_left(),
		"(%d)" % m.wave_left())
	ok("...και το HUD μετράει πόσοι μένουν", m.boss_label() == "BLIZZARD - %d LEFT" % m.wave_left())
	var wd_h1: float = wd.hp
	m._end_turn()
	m.flush_actions()
	await process_frame
	ok("όσο ζει το κύμα γιατρεύεται", wd.hp > wd_h1 and not m.heal_pops.is_empty(),
		"(%.0f -> %.0f)" % [wd_h1, wd.hp])
	# έξω απευθείας: οι vikings του κύματος έχουν ασπίδα που θα κρατούσε ένα χτύπημα
	for wb in m.grid.blocks():
		if wb.has_meta("wave"):
			m.grid.erase(wb)
			wb.queue_free()
	await process_frame
	m._end_turn()
	m.flush_actions()
	await process_frame
	ok("χωρίς κύμα ο πάγος σπάει και η θύελλα περνάει", wd_ab.stage == 3 and not wd.shield_on
		and m.weather._storm_want == 0.0)
	ok("...και ξαναπαίρνει την κανονική του στάση",
		wd.frames_idle == m.enemy_by_id["ice_wendigo"].frames_idle)
	var wd_book_ids := []
	for wd_e in bk.entries(1):
		wd_book_ids.append(wd_e.id)
	ok("ο Wendigo μπαίνει στο Book του Frost Marches, τα παγόβουνα όχι",
		wd_book_ids.has("ice_wendigo") and not wd_book_ids.has("iceberg"), str(wd_book_ids))
	m._debug_do("jump", [0, "start"])
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
