extends SceneTree
## Γράφει την 3η περιοχή, το Graveyard, στο data/areas/03_graveyard.tres με
## ResourceSaver — ποτέ ως κείμενο. Τα γραφικά περνάνε πρώτα από το
## tools/build_graveyard.gd (εχθροί, πλακίδια), το tools/build_floor.gd
## (δάπεδο) και το tools/build_grave_theme.gd (σκηνικό).
##
##   godot --headless --path . --script tools/write_graveyard.gd
##
## Οι εχθροί ζουν ως sub-resources της περιοχής — τα data/enemies/*.tres δεν
## φορτώνονται. Οι ικανότητες είναι οι υπάρχουσες, σε νέους ρόλους:
##   Skeleton          ο βασικός, στη θέση του goblin
##   Ghoul             αναγέννηση: τρώει και κλείνουν οι πληγές του
##   Skeleton Warrior  ασπίδα, όπως ο Shield Knight και ο Viking
##   Ghost             αιθέριο σώμα (ThickHide): κάθε χτύπημα χάνει κάτι
##   Grave Bat         minion, μόνο από τον Reaper
##   Grim Reaper       boss: αιθέριος και καλεί νυχτερίδες
## Τα κείμενα είναι ΜΟΝΟ ASCII: η pixel γραμματοσειρά δεν έχει ελληνικά.

const PATH := "res://data/areas/03_graveyard.tres"


func _tex(name_: String) -> Texture2D:
	var p := "res://art/%s.png" % name_
	if not ResourceLoader.exists(p):
		push_error("λείπει: " + p)
		quit(1)
		return null
	return load(p)


## Όλα τα καρέ <όνομα>_<κατάσταση>_1..N, σε ίδιο καμβά με το στατικό sprite.
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


func _enemy(id: String, name_: String, hp_mult: float, tier: int, min_round: int,
		weight: float, lore: String, ability: EnemyAbility = null) -> EnemyType:
	var e := EnemyType.new()
	e.id = id
	e.display_name = name_
	e.frames_idle = _frames(id, "idle")
	e.frames_hit = _frames(id, "hit")
	e.sprite = e.frames_idle[0] if not e.frames_idle.is_empty() else _tex(id)
	e.fps_idle = 7.0
	e.fps_hit = 12.0
	e.hp_mult = hp_mult
	e.tier = tier
	e.min_round = min_round
	e.weight = weight
	e.ability = ability
	e.description = lore
	return e


func _initialize() -> void:
	var skeleton := _enemy("skeleton", "Skeleton", 0.7, 0, 1, 40.0,
		"Old bones that forgot how to stay buried. Weak alone, but the graves never run out.")

	var regen := RegenerateAbility.new()
	regen.ratio = 0.2
	var ghoul := _enemy("ghoul", "Ghoul", 1.4, 3, 4, 20.0,
		"Feeds on the dead, and on its own wounds. Leave it alone for one turn and it heals.", regen)

	var shield := ShieldAbility.new()
	shield.ratio = 1.0
	var warrior := _enemy("skeleton_warrior", "Skeleton Warrior", 1.1, 2, 7, 14.0,
		"Still guarding a king long gone. Break the shield first, the bones come after.", shield)

	var ether := ThickHideAbility.new()
	ether.reduce = 0.4
	ether.min_through = 0.2
	var ghost := _enemy("ghost", "Ghost", 0.9, 1, 9, 12.0,
		"Half here, half not. Weak hits pass right through it; strike hard.", ether)

	var bat := _enemy("grave_bat", "Grave Bat", 1.0, 0, 1, 1.0,
		"Nests in the reaper's robe. Weak alone, but they fill the gaps fast.")
	bat.sprite_scale = 0.78

	# Boss: αιθέριος σαν το Ghost, και κάθε 2 γύρους βγάζει δύο νυχτερίδες
	var reaper_hide := ThickHideAbility.new()
	reaper_hide.reduce = 0.4
	reaper_hide.min_through = 0.2
	var swarm := SummonerAbility.new()
	swarm.every = 2
	swarm.hp_ratio = 0.3
	swarm.min_row = 2
	swarm.max_row = 7
	swarm.keep_clear = 2
	swarm.count = 2
	swarm.minion_id = "grave_bat"
	var reaper_ab := CompositeAbility.new()
	reaper_ab.parts = [reaper_hide, swarm] as Array[EnemyAbility]
	var reaper := _enemy("reaper", "Grim Reaper", 1.0, 5, 1, 1.0,
		"Keeper of the Graveyard. Blows slide off its shroud, and bats pour from its robe.", reaper_ab)
	reaper.face_center = Vector2(43, 15)     # το κρανίο, αριστερά από το δρεπάνι

	var area := AreaDef.new()
	area.id = "graveyard"
	area.display_name = "Graveyard"
	area.background = _tex("background_grave")
	area.tint = Color(1, 1, 1, 1)
	area.theme = "grave"       # σκοτεινό σκηνικό (tools/build_grave_theme.gd)
	area.weather = "fog"       # σποραδική ομίχλη (scripts/weather.gd)
	area.enemies = [skeleton, ghoul, warrior, ghost] as Array[EnemyType]
	area.minions = [bat] as Array[EnemyType]
	area.boss = reaper
	area.boss_cols = 3
	area.boss_rows = 2
	area.boss_hp_mult = 18.0

	var err := ResourceSaver.save(area, PATH)
	print("%s: %d εχθροί, %d minions, boss %s — %s"
		% [PATH, area.enemies.size(), area.minions.size(), area.boss.id, error_string(err)])
	quit(0 if err == OK else 1)
