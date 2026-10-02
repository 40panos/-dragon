extends SceneTree
## Γράφει το data/dragons/04_fisher.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_fisher.gd
##
## Ο προϊστορικός ψαράς: μωβ κεφάλι δράκου με κέρατα, στέμμα από φτερά και
## κρανίο, κορδόνια με χάντρες. Ρίχνει καμάκια (μονό βλήμα) και τριπλά
## αγκίστρια από κόκαλο (AoE). Το special του, HARPOON, κάνει μία βολή όπου τα
## καμάκια διαπερνούν ό,τι βρουν μπροστά τους.
##
## Όσο κρατάει το HARPOON βγαίνει η εξελιγμένη μορφή, όπως στους άλλους
## δράκους: διπλάσια, κυριευμένη από τη θάλασσα (πτερύγια, λέπια, δόλωμα
## πεσκαδρίτσας, δόντια ψαριού). Η αλλαγή γίνεται μέσα σε δίνη νερού
## (awaken_style "tide") και τα μάτια της ανάβουν πολύ πιο δυνατά στη βολή.
## Τα γραφικά από το tools/build_sea.gd. Ξεκλειδώνει μετά το Graveyard.

const RES_PATH := "res://data/dragons/04_fisher.tres"
const FRAME_W := 64          # φυσικό πλάτος καρέ
const SCALE := 2             # ακέραια μεγέθυνση, χωρίς αναδειγματοληψία
const EVO_W := 128           # η εξελιγμένη μορφή, διπλάσια στο σχέδιο
const EVO_SCALE := 2


func _load_frames(prefix: String, state: String, want_w: int) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/%s_%s_%d.png" % [prefix, state, i]
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει το καρέ: " + path)
			quit(1)
		# όλα τα καρέ πρέπει να έχουν ίδιο καμβά, αλλιώς ο δράκος πηδάει
		if tex.get_width() != want_w:
			push_error("%s: πλάτος %d, περίμενα %d" % [path, tex.get_width(), want_w])
			quit(1)
		out.append(tex)
	return out


func _tex(name_: String) -> Texture2D:
	var path := "res://art/%s.png" % name_
	if not ResourceLoader.exists(path):
		push_error("λείπει: " + path)
		quit(1)
	return load(path)


func _glow() -> Array[Texture2D]:
	var glow: Array[Texture2D] = []
	for i in range(1, 4):
		glow.append(_tex("glow_sea_%d" % i))
	return glow


## Η εξελιγμένη μορφή. Κανονικός DragonType, οπότε το main τη ζωγραφίζει με
## τον ίδιο κώδικα· γεμίζει μόνο ό,τι αφορά την εμφάνιση.
func _make_evolved() -> DragonType:
	var a := DragonType.new()
	var idle := _load_frames("fisher_awake", "idle", EVO_W)
	var ready_ := _load_frames("fisher_awake", "ready", EVO_W)
	var fire := _load_frames("fisher_awake", "fire", EVO_W)
	a.id = "fisher_evolved"
	a.display_name = "Fisher of the Deep"
	a.sprite = idle[0]
	a.sprite_idle = idle[0]
	a.sprite_ready = ready_[0]
	a.sprite_fire = fire[0]
	a.frames_idle = idle
	a.frames_ready = ready_
	a.frames_fire = fire
	a.glow_frames = _glow()
	a.fps_idle = 3.0
	a.fps_ready = 6.0
	a.fps_fire = 12.0
	a.draw_width = float(EVO_W * EVO_SCALE)   # 256 = 2x
	a.tint = Color(1, 1, 1, 1)
	a.accent = Color("4fd6e0")
	# ίδια βλήματα — το ball_tex() διαβάζει τον ενεργό δράκο, και χωρίς αυτά θα
	# έπεφτε στις μπάλες φωτιάς του ember
	a.ball_sprite = _tex("harpoon")
	a.ball_aoe_sprite = _tex("hook_aoe")
	a.ball_heading = -PI / 4.0
	# τα μάτια: η μεγάλη λάμψη είναι το σήμα της μορφής
	a.eye_glow = 1.0
	a.eye_pos = EVO_EYES
	a.eye_pos_fire.assign(EVO_EYES_FIRE)
	a.eye_color = Color("6ff8ff")
	a.special = "harpoon"
	a.special_cost = 12.0
	return a


## Θέσεις των ματιών (βλ. DragonType.eye_pos), μετρημένες πάνω στα καρέ: η
## πιο φωτεινή κυανή κηλίδα κάθε ματιού στο ready, σε κλάσματα του καρέ.
const EYES := Vector2(0.136, 0.333)
const EYES_FIRE := [Vector2(0.137, 0.46), Vector2(0.137, 0.46), Vector2(0.137, 0.46)]
const EVO_EYES := Vector2(0.13, 0.336)
## στα δύο μεγάλα καρέ της βολής το κεφάλι τινάζεται πάνω, και τα μάτια μαζί
const EVO_EYES_FIRE := [Vector2(0.13, 0.336), Vector2(0.172, 0.534), Vector2(0.172, 0.534)]


func _initialize() -> void:
	var d := DragonType.new()
	var idle := _load_frames("fisher", "idle", FRAME_W)
	var ready_ := _load_frames("fisher", "ready", FRAME_W)
	var fire := _load_frames("fisher", "fire", FRAME_W)

	d.id = "fisher"
	d.display_name = "Fisher"
	d.sprite = idle[0]
	d.sprite_idle = idle[0]
	d.sprite_ready = ready_[0]
	d.sprite_fire = fire[0]
	d.frames_idle = idle
	d.frames_ready = ready_
	d.frames_fire = fire
	d.glow_frames = _glow()

	d.ball_sprite = _tex("harpoon")
	d.ball_aoe_sprite = _tex("hook_aoe")
	# το καμάκι είναι σχεδιασμένο με τη μύτη πάνω-δεξιά, όπως ο κρύσταλλος του frost
	d.ball_heading = -PI / 4.0
	d.ball_spin = 0.0

	d.fps_idle = 3.0
	d.fps_ready = 6.0
	d.fps_fire = 12.0
	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)
	d.accent = Color("4fd6e0")     # θαλασσί αφρός: σπίθες, ουρές, λάμψη στο στόμα
	# πιο ήπια λάμψη στα μάτια από τη μεγάλη μορφή
	d.eye_glow = 0.6
	d.eye_pos = EYES
	d.eye_pos_fire.assign(EYES_FIRE)
	d.awaken_style = "tide"        # δίνη νερού αντί για φλόγα
	d.awakened = _make_evolved()
	d.special = "harpoon"
	d.special_cost = 12.0
	d.passive = "every5_double"
	d.unlock_after_area = 3

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — %.0f / εξελιγμένη %.0f, special %s"
		% [RES_PATH, d.draw_width, (d.awakened as DragonType).draw_width, d.special])
	quit(0)
