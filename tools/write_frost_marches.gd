extends SceneTree
## Γράφει τους εχθρούς του Frost Marches μέσα στο data/areas/02_frost_marches.tres,
## με ResourceSaver — ποτέ ως κείμενο. Κρατάει ό,τι άλλο έχει η περιοχή (id,
## όνομα, φόντο, τόνο, μέγεθος και ζωή του boss) και αντικαθιστά μόνο τους
## εχθρούς, τα minions και τον boss.
##
##   godot --headless --path . --script tools/write_frost_marches.gd
##   godot --headless --path . --script tools/write_enemy_lore.gd   (οι περιγραφές)
##
## Ως τώρα η περιοχή είχε τους ίδιους εχθρούς με τους goblins· αποκτά δικούς
## της, με ικανότητες κίνησης και αναγέννησης αντί για άμυνα. Οι εχθροί ζουν
## ως sub-resources της περιοχής — τα data/enemies/*.tres δεν φορτώνονται.
##
## Προς το παρόν χωρίς καρέ: ένα στατικό sprite ο καθένας, ως τα animations.

const PATH := "res://data/areas/02_frost_marches.tres"


func _tex(name_: String) -> Texture2D:
	var p := "res://art/%s.png" % name_
	if not ResourceLoader.exists(p):
		push_error("λείπει: " + p)
		quit(1)
	return load(p)


func _enemy(id: String, name_: String, sprite: String, hp_mult: float, tier: int,
		min_round: int, weight: float, ability: EnemyAbility = null) -> EnemyType:
	var e := EnemyType.new()
	e.id = id
	e.display_name = name_
	e.sprite = _tex(sprite)
	e.hp_mult = hp_mult
	e.tier = tier
	e.min_round = min_round
	e.weight = weight
	e.ability = ability
	return e


func _initialize() -> void:
	var area: AreaDef = load(PATH)

	# ο βασικός, στη θέση του goblin
	var imp := _enemy("frost_imp", "Frost Imp", "frost_imp", 0.7, 0, 1, 40.0)

	# αγέλη: +1 σειρά όταν έχει άλλον λύκο δίπλα του
	var pack := PackHunterAbility.new()
	pack.extra = 1
	var wolf := _enemy("snow_wolf", "Snow Wolf", "snow_wolf", 0.6, 1, 4, 22.0, pack)

	# ο αντίστοιχος του Shield Knight: ίδια ασπίδα, ίδια ζωή
	var shield := ShieldAbility.new()
	shield.ratio = 1.0
	var viking := _enemy("viking", "Viking", "viking", 1.1, 2, 7, 14.0, shield)

	# σπάει σε δύο θραύσματα όταν σκοτωθεί
	var shatter := ShatterAbility.new()
	shatter.minion_id = "shardling"
	shatter.count = 2
	shatter.hp_ratio = 0.3
	var golem := _enemy("crystal_golem", "Crystal Golem", "crystal_golem", 1.5, 3, 9, 12.0, shatter)

	# το θραύσμα: μόνο από τον golem, ποτέ μόνο του στη νέα σειρά
	var shard := _enemy("shardling", "Shardling", "shardling", 1.0, 0, 1, 1.0)
	shard.sprite_scale = 0.8

	# Boss: αναγέννηση (μικρή, γιατί η ζωή του boss είναι τεράστια) και
	# κάλεσμα λύκων. Η Rage θέλει καρέ οργής — έρχεται με τα animations.
	var regen := RegenerateAbility.new()
	regen.ratio = 0.05
	var howl := SummonerAbility.new()
	howl.every = 2
	howl.hp_ratio = 0.25
	howl.min_row = 2
	howl.max_row = 7
	howl.keep_clear = 2
	howl.count = 2
	howl.minion_id = "snow_wolf"
	var yeti_ab := CompositeAbility.new()
	yeti_ab.parts = [regen, howl] as Array[EnemyAbility]
	var yeti := _enemy("yeti", "Yeti", "yeti", 1.0, 5, 1, 1.0, yeti_ab)

	# δικό της πάτωμα από χιόνι και πάγο (tools/build_floor.gd). Ο τόνος της
	# περιοχής γίνεται λευκός: ο γαλάζιος ήταν η προσωρινή «παγωνιά» όσο
	# έπαιρνε το πράσινο πάτωμα των goblins, και τώρα θα έβαφε και τους
	# εχθρούς, που είναι ήδη παγωμένοι στα χρώματά τους.
	area.background = _tex("background_frost")
	area.tint = Color(1, 1, 1, 1)

	area.enemies = [imp, wolf, viking, golem] as Array[EnemyType]
	area.minions = [shard] as Array[EnemyType]
	area.boss = yeti

	var err := ResourceSaver.save(area, PATH)
	print("%s: %d εχθροί, %d minions, boss %s — %s"
		% [PATH, area.enemies.size(), area.minions.size(), area.boss.id, error_string(err)])
	quit(0 if err == OK else 1)
