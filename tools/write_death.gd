extends SceneTree
## Γράφει το data/dragons/03_death.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_death.gd
##
## Ο δράκος του θανάτου: κρανίο με κέρατα, πράσινη φωτιά ψυχών, και δρεπάνια
## αντί για μπάλες φωτιάς. Χτισμένος σαν τον frost και όχι σαν τον ember —
## δεν έχει ξυπνημένη μορφή, οπότε το special του είναι το SWARM, που δεν
## χρειάζεται δεύτερο σετ καρέ.

const RES_PATH := "res://data/dragons/03_death.tres"
const FRAME_W := 64          # φυσικό πλάτος καρέ
const SCALE := 2             # ακέραια μεγέθυνση, χωρίς αναδειγματοληψία


func _load_frames(state: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/death_%s_%d.png" % [state, i]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει το καρέ: " + path)
			quit(1)
		# όλα τα καρέ πρέπει να έχουν ίδιο καμβά, αλλιώς ο δράκος πηδάει
		if tex.get_width() != FRAME_W:
			push_error("%s: πλάτος %d, περίμενα %d" % [path, tex.get_width(), FRAME_W])
			quit(1)
		out.append(tex)
	return out


## Τα καρέ του περιγράμματος λάμψης, από το tools/build_glow.gd. Λείπουν
## σιωπηλά: χωρίς αυτά το block ξαναπέφτει στους λευκούς δακτύλιους.
func _load_glow(set_: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/glow_%s_%d.png" % [set_, i]
		if ResourceLoader.exists(path):
			out.append(load(path))
	return out


func _tex(name_: String) -> Texture2D:
	var path := "res://art/%s.png" % name_
	if not ResourceLoader.exists(path):
		push_error("λείπει: " + path)
		quit(1)
	return load(path)


func _initialize() -> void:
	var d := DragonType.new()

	var idle := _load_frames("idle")
	var ready_ := _load_frames("ready")
	var fire := _load_frames("fire")

	d.id = "death"
	d.display_name = "Death"

	# στατικά sprite: το πρώτο καρέ κάθε κατάστασης, ως εφεδρεία
	d.sprite = idle[0]
	d.sprite_idle = idle[0]
	d.sprite_ready = ready_[0]
	d.sprite_fire = fire[0]

	d.frames_idle = idle
	d.frames_ready = ready_
	d.frames_fire = fire
	d.glow_frames = _load_glow("death")

	# δρεπάνια αντί για μπάλες φωτιάς — και στη βολή και στο κουμπί του HUD
	d.ball_sprite = _tex("scythe")
	d.ball_aoe_sprite = _tex("scythe_aoe")

	# ping-pong 0,1,2,1: η περίοδος είναι 4 βήματα
	d.fps_idle = 3.0
	d.fps_ready = 6.0
	d.fps_fire = 12.0

	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)
	d.accent = Color("7bd93a")     # πράσινη φωτιά ψυχών, όχι πορτοκαλί

	# Το SWARM ρίχνει άλλη μια πλήρη ριπή· ταιριάζει σε δράκο που πετάει
	# δρεπάνια και δεν χρειάζεται δεύτερη μορφή όπως το INFERNO.
	# Το κόστος είναι ΣΚΟΤΩΜΟΙ: ο ember είναι στο 8 μετά τη σάρωση, και ο
	# death μπαίνει λίγο πιο ψηλά γιατί ξεκλειδώνει αργότερα, με τον παίκτη
	# να σκοτώνει ήδη πολύ πιο γρήγορα.
	d.special = "swarm"
	d.special_cost = 12.0
	d.passive = "ball_every5"
	d.unlock_after_area = 2

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — draw_width=%.1f (%dx%d ανά καρέ, %dx)"
		% [RES_PATH, d.draw_width, FRAME_W, idle[0].get_height(), SCALE])
	quit(0)
