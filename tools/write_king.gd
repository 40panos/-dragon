extends SceneTree
## Περνάει τον Goblin King ως boss της Goblin Land, με ResourceSaver.
##
## Μόνο η πρώτη περιοχή τον παίρνει — το Frost Marches κρατάει τον Warlock Lord.
## Οι τρεις ικανότητες δένονται με CompositeAbility, γιατί το EnemyType κρατάει
## ΜΙΑ ability.
##
##   godot --headless --path . --script tools/write_king.gd

const AREA := "res://data/areas/01_goblin_land.tres"
const FRAME_W := 96          # 96x64 = ακριβώς 3:2, όσο και το αποτύπωμα 3x2
const FRAME_H := 64
const IDLE_N := 6
const HIT_N := 6
const RAGE_N := 6
const ROAR_N := 6

## Η ζωή πέφτει μαζί με το τομάρι: με 0.4 μείωση ανά μπάλα περνάει το 60% της
## ζημιάς, οπότε το 14.0 θα έκανε τη μάχη ενάμιση φορά πιο μακριά απ' ό,τι ήταν.
const BOSS_HP_MULT := 9.0
const HIDE_REDUCE := 0.4
const HIDE_MIN := 0.2


func _load_frames(state: String, count: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, count + 1):
		var path := "res://art/king_%s_%d.png" % [state, i]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει το καρέ: " + path)
			quit(1)
		# ίδιος καμβάς παντού, αλλιώς ο βασιλιάς πηδάει από καρέ σε καρέ
		if tex.get_width() != FRAME_W or tex.get_height() != FRAME_H:
			push_error("%s: %dx%d, περίμενα %dx%d"
				% [path, tex.get_width(), tex.get_height(), FRAME_W, FRAME_H])
			quit(1)
		out.append(tex)
	return out


func _make_ability(rage: Array[Texture2D], roar: Array[Texture2D]) -> CompositeAbility:
	# 1. χοντρό τομάρι: κόβει σταθερό ποσό από κάθε μπάλα
	var hide := ThickHideAbility.new()
	hide.reduce = HIDE_REDUCE
	hide.min_through = HIDE_MIN

	# 2. οργή: στο μισό της ζωής αλλάζει μορφή και πιέζει με διπλό βήμα
	var fury := RageAbility.new()
	fury.threshold = 0.5
	fury.frames_rage = rage
	fury.fps_rage = 9.0
	fury.every = 2
	fury.step = 2
	fury.announce = "THE KING IS ENRAGED"

	# 3. πολεμικό κάλεσμα: δύο orc bats κάθε δεύτερο γύρο, με ουρλιαχτό
	var horn := SummonerAbility.new()
	horn.every = 2
	horn.count = 2
	horn.hp_ratio = 0.3
	horn.min_row = 2
	horn.keep_clear = 2
	horn.minion_id = "bat"
	horn.act_frames = roar
	horn.act_fps = 10.0

	var all := CompositeAbility.new()
	var parts: Array[EnemyAbility] = [hide, fury, horn]
	all.parts = parts
	return all


func _make_king() -> EnemyType:
	var idle := _load_frames("idle", IDLE_N)
	var hit := _load_frames("hit", HIT_N)
	var rage := _load_frames("rage", RAGE_N)
	var roar := _load_frames("roar", ROAR_N)

	var e := EnemyType.new()
	e.id = "goblin_king"
	e.display_name = "Goblin King"
	e.sprite = idle[0]
	e.frames_idle = idle
	e.fps_idle = 5.0          # βαρύς, αργή ανάσα
	e.frames_hit = hit
	e.fps_hit = 10.0
	e.hp_mult = 1.0           # η ζωή του boss βγαίνει από το boss_hp_mult
	e.tier = 5
	e.sprite_scale = 1.0
	e.ability = _make_ability(rage, roar)
	return e


func _initialize() -> void:
	var area: AreaDef = load(AREA)
	if area == null:
		push_error("δεν φορτώνει: " + AREA)
		quit(1)
	area.boss = _make_king()
	area.boss_cols = 3
	area.boss_rows = 2
	area.boss_hp_mult = BOSS_HP_MULT

	var err := ResourceSaver.save(area, AREA)
	if err != OK:
		push_error("η αποθήκευση απέτυχε (%d)" % err)
		quit(1)
	print("γράφτηκε %s — boss=%s, %dx%d κελιά, hp_mult=%.1f"
		% [AREA, area.boss.display_name, area.boss_cols, area.boss_rows,
			area.boss_hp_mult])
	quit(0)
