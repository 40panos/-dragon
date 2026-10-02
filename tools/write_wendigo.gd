extends SceneTree
## Προσθέτει στο Frost Marches τον μεγάλο boss (Ice Wendigo, 3x3) και τα
## παγόβουνά του, με ResourceSaver — ποτέ ως κείμενο. Κρατάει ό,τι άλλο έχει
## η περιοχή· ο Yeti μένει ως `boss` και γίνεται mini-boss στον γύρο 10.
##
##   godot --headless --path . --script tools/build_wendigo.gd
##   godot --headless --path . --script tools/write_wendigo.gd
##
## Τα κείμενα είναι ΜΟΝΟ ASCII: η pixel γραμματοσειρά δεν έχει ελληνικά.

const PATH := "res://data/areas/02_frost_marches.tres"


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


func _initialize() -> void:
	var area: AreaDef = load(PATH)

	var ab := WendigoAbility.new()
	ab.slam_frames = _frames("wendigo", "slam")
	ab.freeze_frames = _frames("wendigo", "freeze")
	ab.frozen_idle = _frames("wendigo", "frozen")
	# βλέμμα: τα μάτια ανάβουν, κρατάνε, σβήνουν (το κύμα κρύου φεύγει στο φουλ)
	var g := _frames("wendigo", "glare")
	ab.glare_frames = [g[0], g[1], g[2], g[2], g[2], g[2], g[2], g[0]] as Array[Texture2D]
	ab.act_fps = 10.0
	ab.eyes_uv = Vector2(0.495, 0.245)
	ab.eyes_gap = 0.09

	var w := EnemyType.new()
	w.id = "ice_wendigo"
	w.display_name = "Ice Wendigo"
	w.frames_idle = _frames("wendigo", "idle")
	w.frames_hit = _frames("wendigo", "hit")
	w.sprite = w.frames_idle[0]
	w.fps_idle = 6.0
	w.fps_hit = 12.0
	w.hp_mult = 1.0
	w.tier = 5
	w.min_round = 1
	w.weight = 1.0
	w.ability = ab
	w.face_center = Vector2(48, 24)          # το κρανίο ανάμεσα στα κέρατα
	w.description = "The hunger of the frozen north. It tears icebergs from the ground, and anything that breaks them frees what sleeps inside. Wound it deep and it hides in ice while a blizzard brings its army. Never meet its gaze."

	var berg_ab := IcebergAbility.new()
	berg_ab.crack_frames = [_tex("iceberg"), _tex("iceberg_crack_1"), _tex("iceberg_crack_2")] as Array[Texture2D]
	var berg := EnemyType.new()
	berg.id = "iceberg"
	berg.display_name = "Iceberg"
	berg.sprite = _tex("iceberg")
	berg.hp_mult = 2.0
	berg.ability = berg_ab
	berg.hidden_in_book = true

	area.final_boss = w
	area.final_cols = 3
	area.final_rows = 3
	area.final_hp_mult = 30.0
	area.specials = [berg] as Array[EnemyType]
	# ο Yeti, πλέον mini-boss στον γύρο 10: η ζωή του υπολογίζεται από τον
	# γύρο, οπότε ο πολλαπλασιαστής ανεβαίνει, όπως έγινε με τον Goblin King
	area.boss_hp_mult = 16.0

	var err := ResourceSaver.save(area, PATH)
	print("%s: μεγάλος boss %s, %d specials — %s"
		% [PATH, w.id, area.specials.size(), error_string(err)])
	quit(0 if err == OK else 1)
