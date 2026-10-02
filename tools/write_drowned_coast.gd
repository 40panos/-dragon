extends SceneTree
## Γράφει την 4η περιοχή, το Drowned Coast, στο data/areas/04_drowned_coast.tres
## με ResourceSaver — ποτέ ως κείμενο. Τα γραφικά περνάνε πρώτα από το
## tools/build_sea.gd (εχθροί, πλακίδια με κύματα), το tools/build_floor.gd
## (δάπεδο ανά καρέ) και το tools/build_sea_theme.gd (σκηνικό).
##
##   godot --headless --path . --script tools/write_drowned_coast.gd
##
## Ψαροειδή τέρατα, με τις υπάρχουσες ικανότητες σε νέους ρόλους:
##   Murkfin        ο βασικός, ψαράνθρωπος με τρίαινα — στη θέση του goblin
##   Razorjaw       πιράνχας, αγέλη (Pack): δίπλα σε άλλον τρέχει πιο γρήγορα
##   Shellback      καβούρι, η δαγκάνα είναι ασπίδα — όπως Knight / Viking
##   Drift Jelly    μέδουσα, μισοδιάφανη (ThickHide): τα αδύναμα χτυπήματα χάνονται
##   Bitefin        minion, μόνο από τον Angler
##   Abyssal Angler boss 3x2: κλείνει τις πληγές του και καλεί Bitefins
## Τα κείμενα είναι ΜΟΝΟ ASCII: η pixel γραμματοσειρά δεν έχει ελληνικά.

const PATH := "res://data/areas/04_drowned_coast.tres"
const WAVE_FRAMES := 4


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
	var murkfin := _enemy("murkfin", "Murkfin", 0.7, 0, 1, 40.0,
		"Crawled up from the shallows with a rusty trident. Weak alone, but the tide brings more.")

	var pack := PackHunterAbility.new()
	pack.extra = 1
	var razorjaw := _enemy("razorjaw", "Razorjaw", 0.8, 1, 3, 22.0,
		"Smells blood from a mile away. Next to another of its kind it swims faster, so split the school.", pack)

	var shield := ShieldAbility.new()
	shield.ratio = 1.0
	var shellback := _enemy("shellback", "Shellback", 1.1, 2, 6, 14.0,
		"Hides behind one giant claw. The claw takes every blow until it cracks.", shield)

	var jelly_hide := ThickHideAbility.new()
	jelly_hide.reduce = 0.4
	jelly_hide.min_through = 0.2
	var jelly := _enemy("drift_jelly", "Drift Jelly", 0.9, 1, 9, 12.0,
		"More water than flesh. Weak hits sink right through it; strike hard.", jelly_hide)

	var bitefin := _enemy("bitefin", "Bitefin", 1.0, 0, 1, 1.0,
		"Hatches by the hundred in the angler's shadow. All teeth, no fear.")
	bitefin.sprite_scale = 0.78

	# Boss: κλείνει τις πληγές του αν τον αφήσεις, και κάθε 2 γύρους βγάζει
	# δύο Bitefins από το σκοτάδι γύρω από το φανάρι του
	var regen := RegenerateAbility.new()
	regen.ratio = 0.1
	var brood := SummonerAbility.new()
	brood.every = 2
	brood.hp_ratio = 0.3
	brood.min_row = 2
	brood.max_row = 7
	brood.keep_clear = 2
	brood.count = 2
	brood.minion_id = "bitefin"
	var angler_ab := CompositeAbility.new()
	angler_ab.parts = [regen, brood] as Array[EnemyAbility]
	var angler := _enemy("angler", "Abyssal Angler", 1.0, 5, 1, 1.0,
		"Lord of the drowned deep. Its wounds close if you let it breathe, and its lure calls the brood.", angler_ab)

	var area := AreaDef.new()
	area.id = "drowned_coast"
	area.display_name = "Drowned Coast"
	area.background = _tex("background_sea")
	var waves: Array[Texture2D] = []
	for k in range(1, WAVE_FRAMES + 1):
		waves.append(_tex("background_sea_%d" % k))
	area.background_frames = waves
	area.background_fps = 3.0
	area.tint = Color(1, 1, 1, 1)
	area.theme = "sea"         # βρεγμένο σκηνικό (tools/build_sea_theme.gd)
	area.weather = ""          # η κίνηση είναι τα κύματα του δαπέδου
	area.enemies = [murkfin, razorjaw, shellback, jelly] as Array[EnemyType]
	area.minions = [bitefin] as Array[EnemyType]
	area.boss = angler
	area.boss_cols = 3
	area.boss_rows = 2
	area.boss_hp_mult = 18.0

	var err := ResourceSaver.save(area, PATH)
	print("%s: %d εχθροί, %d minions, boss %s, %d καρέ κυμάτων — %s"
		% [PATH, area.enemies.size(), area.minions.size(), area.boss.id, waves.size(), error_string(err)])
	quit(0 if err == OK else 1)
