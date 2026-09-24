extends SceneTree
## Bot που παίζει το πραγματικό παιχνίδι γρήγορα, για ρύθμιση ισορροπίας.
##
## Τρέξε το από τον φάκελο του project:
##   godot --headless --fixed-fps 60 --script tests/balance_sim.gd -- runs=20 dragon=ember cost=20
##
## Προσοχή: γράφει στο save.json (ρεκόρ, ξεκλειδώματα). Κράτα αντίγραφο πριν.
## Ο bot στοχεύει κυρίως τον πιο επικίνδυνο εχθρό και καμιά φορά ρίχνει
## τυχαία γωνία — παίζει χειρότερα από άνθρωπο, άρα οι αριθμοί είναι «κάτω όριο».

const MAX_LEVEL := 45

var m
var cfg := {"runs": 20, "dragon": "ember", "cost": -1.0, "seed": 1}
var runs_done := 0
var results: Array = []

var turns := 0
var first_ready := -1
var specials := 0
var boss_turns := 0
var boss_killed := false
var kills_by_round := {}     # γύρος -> σκοτωμοί μέχρι τότε


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			cfg[kv[0]] = kv[1] if kv[0] == "dragon" else float(kv[1])
	seed(int(cfg["seed"]))
	m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	await process_frame
	_new_run()


func _new_run() -> void:
	m.save = SaveManager.defaults()
	m._start()
	for d in m.dragons:
		if d.id == cfg["dragon"]:
			m.dragon = d
	if cfg.has("flat"):          # παλιοί κανόνες: όλοι από τον γύρο 1, ίδια πιθανότητα
		for a in m.areas:
			for e in a.enemies:
				e.min_round = 1
				e.weight = 1.0
	if float(cfg["cost"]) > 0.0:
		m.dragon.special_cost = float(cfg["cost"])
	turns = 0
	first_ready = -1
	specials = 0
	boss_turns = 0
	boss_killed = false
	kills_by_round = {}


func _process(_delta: float) -> bool:
	if m == null or m.grid == null:
		return false
	match m.phase:
		"aim":
			kills_by_round[m.level] = m.kills
			if m.level > MAX_LEVEL:
				_finish_run()
				return false
			if m.special_ready():
				if first_ready < 0:
					first_ready = m.level
				specials += 1
				m._use_special()
			if m.phase == "aim":
				_aim()
				m._fire()
			turns += 1
			if m.boss_alive():
				boss_turns += 1
		"shoot":
			Engine.time_scale = 3.0
			if m.level > 20 and not boss_killed:
				boss_killed = true
		"over":
			_finish_run()
	return false


func _aim() -> void:
	var origin := Vector2(m.launch_x, m.floor_y - 18.0)
	var blocks: Array = m.grid.blocks()
	if blocks.is_empty() or randf() < 0.35:
		var ang := randf_range(-1.25, 1.25)
		m._set_aim(origin + Vector2.UP.rotated(ang) * 200.0)
		return
	# ο πιο χαμηλός εχθρός είναι ο πιο επικίνδυνος
	var lowest = blocks[0]
	for b in blocks:
		if b.row + b.ch > lowest.row + lowest.ch or (b.row + b.ch == lowest.row + lowest.ch and randf() < 0.5):
			lowest = b
	var dir: Vector2 = (lowest.position - origin).normalized().rotated(randf_range(-0.12, 0.12))
	m._set_aim(origin + dir * 200.0)


func _finish_run() -> void:
	results.append({
		"round": m.level,
		"kills": m.kills,
		"turns": turns,
		"first_ready": first_ready,
		"specials": specials,
		"boss_turns": boss_turns,
		"boss_killed": m.level > 20,
		"k5": kills_by_round.get(5, -1),
		"k10": kills_by_round.get(10, -1),
		"k15": kills_by_round.get(15, -1),
		"k20": kills_by_round.get(20, -1),
	})
	var r: Dictionary = results[-1]
	print("run %2d: γύρος %2d, σκοτωμοί %3d, special πρώτη φορά γύρο %2d, χρήσεις %2d, boss %s" % [
		results.size(), r["round"], r["kills"], r["first_ready"], r["specials"],
		("νίκη σε %d βολές" % r["boss_turns"]) if r["boss_killed"] else ("έχασε" if r["round"] >= 20 else "-")])
	runs_done += 1
	if runs_done >= int(cfg["runs"]):
		_summary()
		quit()
		return
	_new_run()


func _summary() -> void:
	var rounds := []
	var reached20 := 0
	var won := 0
	var kpt := 0.0
	var fr := []
	for r in results:
		rounds.append(r["round"])
		if r["round"] >= 20:
			reached20 += 1
		if r["boss_killed"]:
			won += 1
		kpt += float(r["kills"]) / maxf(1.0, r["turns"])
		if r["first_ready"] > 0:
			fr.append(r["first_ready"])
	rounds.sort()
	fr.sort()
	var n := results.size()
	print("")
	print("=== %s, κόστος %s, %d runs ===" % [cfg["dragon"], str(cfg["cost"]), n])
	print("γύρος τέλους: διάμεσος %d, min %d, max %d" % [rounds[n / 2], rounds[0], rounds[-1]])
	print("έφτασαν στον boss: %d/%d, τον νίκησαν: %d/%d" % [reached20, n, won, n])
	print("σκοτωμοί ανά βολή (μέσος): %.2f" % (kpt / n))
	for k in ["k5", "k10", "k15", "k20"]:
		var vals := []
		for r in results:
			if r[k] >= 0:
				vals.append(r[k])
		vals.sort()
		if not vals.is_empty():
			print("σκοτωμοί μέχρι γύρο %s: διάμεσος %d (%d runs)" % [k.substr(1), vals[vals.size() / 2], vals.size()])
	if not fr.is_empty():
		print("πρώτο γέμισμα special: διάμεσος γύρος %d" % fr[fr.size() / 2])
