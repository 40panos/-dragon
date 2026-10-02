extends SceneTree
## Δίνει στο κάλεσμα του Warlock τα καρέ cast του (art/warlock_cast_*), με
## ResourceSaver — ποτέ ως κείμενο. Ο Goblin King έχει ήδη τον βρυχηθμό του.
##
##   godot --headless --path . --script tools/write_stage1_fx.gd

const PATH := "res://data/areas/01_goblin_land.tres"


func _initialize() -> void:
	var area: AreaDef = load(PATH)
	var frames: Array[Texture2D] = []
	var i := 1
	while ResourceLoader.exists("res://art/warlock_cast_%d.png" % i):
		frames.append(load("res://art/warlock_cast_%d.png" % i))
		i += 1
	var done := false
	for e in area.enemies:
		if e.id == "warlock" and e.ability is SummonerAbility:
			e.ability.act_frames = frames
			e.ability.act_fps = 12.0
			done = true
	if not done:
		push_error("δεν βρέθηκε το κάλεσμα του warlock")
		quit(1)
		return
	var err := ResourceSaver.save(area, PATH)
	print("%s: warlock cast %d καρέ — %s" % [PATH, frames.size(), error_string(err)])
	quit(0 if err == OK else 1)
