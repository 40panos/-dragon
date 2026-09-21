extends SceneTree
## Περνάει τον orc bat στα αρχεία περιοχής με ResourceSaver, ποτέ ως κείμενο.
##
## Ο τύπος μπαίνει στο area.minions (ΟΧΙ στο area.enemies), ώστε να τον ξέρει
## το enemy_by_id χωρίς να μπει στη δεξαμενή τυχαίας εμφάνισης. Παράλληλα κάθε
## SummonerAbility της περιοχής γυρίζει να καλεί "bat" και να κρατάει ζώνη
## ασφαλείας πριν τον δράκο.
##
##   godot --headless --path . --script tools/write_bat.gd

const AREAS := [
	"res://data/areas/01_goblin_land.tres",
	"res://data/areas/02_frost_marches.tres",
]
const FRAME_W := 32          # ίδιος καμβάς με τους υπόλοιπους εχθρούς
const IDLE_N := 8
const HIT_N := 6
const SPRITE_SCALE := 0.78   # minion: δείχνει μικρότερο, το κελί μένει ίδιο
const KEEP_CLEAR := 2        # σειρές πριν τη γραμμή θανάτου που απαγορεύονται


func _load_frames(state: String, count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, count + 1):
		var path := "res://art/bat_%s_%d.png" % [state, i]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει το καρέ: " + path)
			quit(1)
		# ίδιος καμβάς σε όλα, αλλιώς το πλάσμα πηδάει από καρέ σε καρέ
		if tex.get_width() != FRAME_W or tex.get_height() != FRAME_W:
			push_error("%s: %dx%d, περίμενα %dx%d"
				% [path, tex.get_width(), tex.get_height(), FRAME_W, FRAME_W])
			quit(1)
		out.append(tex)
	return out


func _make_bat() -> EnemyType:
	var e := EnemyType.new()
	var idle := _load_frames("idle", IDLE_N)
	var hit := _load_frames("hit", HIT_N)
	e.id = "bat"
	e.display_name = "Orc Bat"
	e.sprite = idle[0]
	e.frames_idle = idle
	e.fps_idle = 8.0          # φτερούγισμα, πιο γρήγορο από τους πεζούς
	e.frames_hit = hit
	e.fps_hit = 12.0
	e.hp_mult = 1.0
	e.tier = 0
	e.sprite_scale = SPRITE_SCALE
	return e


func _initialize() -> void:
	for path in AREAS:
		var area: AreaDef = load(path)
		if area == null:
			push_error("δεν φορτώνει: " + path)
			quit(1)

		# κάθε περιοχή κρατάει δικό της αντίγραφο του τύπου, όπως και οι υπόλοιποι
		var bat := _make_bat()
		var minions: Array[EnemyType] = []
		for e in area.minions:
			if e.id != "bat":
				minions.append(e)
		minions.append(bat)
		area.minions = minions

		var touched := 0
		var all: Array = []
		all.append_array(area.enemies)
		if area.boss:
			all.append(area.boss)
		for e in all:
			if e.ability is SummonerAbility:
				var sa := e.ability as SummonerAbility
				sa.minion_id = "bat"
				sa.keep_clear = KEEP_CLEAR
				touched += 1

		var err := ResourceSaver.save(area, path)
		if err != OK:
			push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
			quit(1)
		print("γράφτηκε %s — minions=%d, καλεστές=%d"
			% [path, area.minions.size(), touched])
	quit(0)
