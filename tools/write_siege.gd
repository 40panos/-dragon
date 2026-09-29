extends SceneTree
## Προσθέτει στο Goblin Land τον μεγάλο boss (Grukk's Siege Tower, 3x3) και ό,τι
## ρίχνει, με ResourceSaver — ποτέ ως κείμενο. Κρατάει ό,τι άλλο έχει η
## περιοχή· ο Goblin King μένει ως `boss` και γίνεται mini-boss στον γύρο 10.
##
##   godot --headless --path . --script tools/build_siege.gd
##   godot --headless --path . --script tools/write_siege.gd
##
## Τα κείμενα είναι ΜΟΝΟ ASCII: η pixel γραμματοσειρά δεν έχει ελληνικά.

const PATH := "res://data/areas/01_goblin_land.tres"


func _tex(name_: String) -> Texture2D:
	var p := "res://art/%s.png" % name_
	if not ResourceLoader.exists(p):
		push_error("λείπει: " + p)
		quit(1)
		return null
	return load(p)


func _frames(name_: String, state: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var size := _tex(name_).get_size()
	var i := 1
	while ResourceLoader.exists("res://art/%s_%s_%d.png" % [name_, state, i]):
		var t: Texture2D = load("res://art/%s_%s_%d.png" % [name_, state, i])
		if t.get_size() != size:
			push_error("%s_%s_%d: %s, περίμενα %s" % [name_, state, i, t.get_size(), size])
			quit(1)
		out.append(t)
		i += 1
	return out


func _type(id: String, name_: String, sprite: String, hp_mult: float, lore: String,
		ability: EnemyAbility = null) -> EnemyType:
	var e := EnemyType.new()
	e.id = id
	e.display_name = name_
	e.frames_idle = _frames(sprite, "idle")
	e.frames_hit = _frames(sprite, "hit")
	e.sprite = e.frames_idle[0] if not e.frames_idle.is_empty() else _tex(sprite)
	e.fps_idle = 7.0
	e.fps_hit = 12.0
	e.hp_mult = hp_mult
	e.tier = 0
	e.min_round = 1
	e.weight = 1.0
	e.ability = ability
	e.description = lore
	return e


func _initialize() -> void:
	var area: AreaDef = load(PATH)

	var siege := SiegeTowerAbility.new()
	siege.throw_frames = _frames("siege_tower", "throw")
	siege.throw_fps = 10.0
	var tower := _type("siege_tower", "Grukk's Siege Tower", "siege_tower", 1.0,
		"Grukk rides his siege tower into battle. It never moves: it hurls goblins, barricades and powder kegs, and every few turns its catapult shakes the whole field. Hit Grukk himself for double damage.",
		siege)
	tower.tier = 5
	tower.face_center = Vector2(45, 14)       # ο Grukk στην κορυφή

	var drummer := _type("war_drummer", "War Drummer", "war_drummer", 0.8,
		"Beats the war drums from the tower's side. While any drummer plays, the tower is shielded and every goblin marches faster.",
		WarDrumAbility.new())
	drummer.tier = 1

	var barricade := _type("barricade", "Barricade", "barricade", 1.0, "", BarricadeAbility.new())
	barricade.invulnerable = true
	barricade.show_hp = false
	barricade.hidden_in_book = true

	var keg := _type("powder_keg", "Powder Keg", "powder_keg", 0.1, "", PowderKegAbility.new())
	keg.show_hp = false
	keg.hidden_in_book = true
	keg.fps_idle = 9.0

	area.final_boss = tower
	area.final_cols = 3
	area.final_rows = 3
	area.final_hp_mult = 30.0
	area.specials = [drummer, barricade, keg] as Array[EnemyType]
	# ο Goblin King, πλέον mini-boss στον γύρο 10: η ζωή του υπολογίζεται από
	# τον γύρο, οπότε ο πολλαπλασιαστής ανεβαίνει για να μείνει αντίπαλος
	area.boss_hp_mult = 16.0

	var err := ResourceSaver.save(area, PATH)
	print("%s: μεγάλος boss %s, %d specials — %s"
		% [PATH, tower.id, area.specials.size(), error_string(err)])
	quit(0 if err == OK else 1)
