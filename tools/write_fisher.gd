extends SceneTree
## Γράφει το data/dragons/04_fisher.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_fisher.gd
##
## Ο προϊστορικός ψαράς: μωβ κεφάλι δράκου με κέρατα, στέμμα από φτερά και
## κρανίο, κορδόνια με χάντρες. Ρίχνει καμάκια (μονό βλήμα) και τριπλά
## αγκίστρια από κόκαλο (AoE, στριφογυρίζουν). Το special του, HARPOON, κάνει
## μία βολή όπου τα καμάκια διαπερνούν ό,τι βρουν μπροστά τους.
## Τα γραφικά από το tools/build_sea.gd. Ξεκλειδώνει μετά το Graveyard.

const RES_PATH := "res://data/dragons/04_fisher.tres"
const FRAME_W := 64          # φυσικό πλάτος καρέ
const SCALE := 2             # ακέραια μεγέθυνση, χωρίς αναδειγματοληψία


func _load_frames(state: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/fisher_%s_%d.png" % [state, i]
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

	d.id = "fisher"
	d.display_name = "Fisher"
	d.sprite = idle[0]
	d.sprite_idle = idle[0]
	d.sprite_ready = ready_[0]
	d.sprite_fire = fire[0]
	d.frames_idle = idle
	d.frames_ready = ready_
	d.frames_fire = fire

	var glow: Array[Texture2D] = []
	for i in range(1, 4):
		glow.append(_tex("glow_sea_%d" % i))
	d.glow_frames = glow

	d.ball_sprite = _tex("harpoon")
	d.ball_aoe_sprite = _tex("hook_aoe")
	# το καμάκι είναι σχεδιασμένο με τη μύτη πάνω-δεξιά, όπως ο κρύσταλλος του
	# frost· τα αγκίστρια στριφογυρίζουν σαν τα δρεπάνια του death
	d.ball_heading = -PI / 4.0
	d.ball_spin = 0.0

	d.fps_idle = 3.0
	d.fps_ready = 6.0
	d.fps_fire = 12.0
	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)
	d.accent = Color("4fd6e0")     # θαλασσί αφρός: σπίθες, ουρές, λάμψη στο στόμα
	d.special = "harpoon"
	d.special_cost = 12.0
	d.passive = "every5_double"
	d.unlock_after_area = 3

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — draw_width=%.1f, special %s" % [RES_PATH, d.draw_width, d.special])
	quit(0)
