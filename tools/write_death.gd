extends SceneTree
## Γράφει το data/dragons/03_death.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_death.gd
##
## Ο δράκος του θανάτου: κρανίο με κέρατα, πράσινη φωτιά ψυχών, και δρεπάνια
## αντί για μπάλες φωτιάς — τα οποία στριφογυρίζουν στον αέρα.
##
## Έχει εξελιγμένη μορφή, που βγαίνει όσο τρέχει το SWARM: το main δείχνει τη
## δεύτερη μορφή όποιου δράκου έχει μία, ανεξάρτητα από το ποιο special ρίχνει.

const RES_PATH := "res://data/dragons/03_death.tres"
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


## Η εξελιγμένη μορφή — βγαίνει όσο τρέχει το special, όπως ο ξυπνημένος ember.
## Είναι κανονικός DragonType, οπότε το main τη ζωγραφίζει με τον ίδιο κώδικα·
## γεμίζει μόνο ό,τι αφορά την εμφάνιση.
func _make_evolved() -> DragonType:
	var a := DragonType.new()
	# Η μορφή χωρίς μάσκα. Στην ηρεμία τα μάτια είναι μαύρα κενά· στη στόχευση
	# μαζεύεται σκοτάδι γύρω τους· στη βολή εμφανίζονται άσπρες ίριδες που
	# στενεύουν σε σχισμή.
	var idle := _load_frames("evo2", "idle", EVO_W)
	var ready_ := _load_frames("evo2", "ready", EVO_W)
	var fire := _load_frames("evo2", "fire", EVO_W)
	a.id = "death_evolved"
	a.display_name = "Death Unmasked"
	a.sprite = idle[0]
	a.sprite_idle = idle[0]
	a.sprite_ready = ready_[0]
	a.sprite_fire = fire[0]
	a.frames_idle = idle
	a.frames_ready = ready_
	a.frames_fire = fire
	# η λάμψη πάνω στον εχθρό που χτυπάει: σκοτεινή φλόγα αντί για πράσινη
	a.glow_frames = _load_glow("void")
	a.fps_idle = 3.0
	a.fps_ready = 6.0
	a.fps_fire = 12.0
	a.draw_width = float(EVO_W * EVO_SCALE)   # 256 = 2x
	a.tint = Color(1, 1, 1, 1)
	# μαύρα particles, όχι πράσινα: όλα όσα εκπέμπει η μορφή χωρίς μάσκα είναι
	# σκοτάδι. Το _accent() διαβάζει τον ενεργό δράκο, οπότε αλλάζουν μαζί της.
	a.accent = Color("221a2b")
	a.dark_eyes = true
	# δικά της βλήματα: τα ίδια δρεπάνια ξαναβαμμένα σε σκοτάδι, από το
	# tools/build_dark_balls.gd. Το ball_tex() διαβάζει τον ενεργό δράκο,
	# οπότε αλλάζουν τη στιγμή που βγαίνει η μορφή.
	a.ball_sprite = load("res://art/scythe_dark.png")
	a.ball_aoe_sprite = load("res://art/scythe_aoe_dark.png")
	a.ball_spin = 2.4
	# το main διαβάζει τον ΚΥΡΙΟ δράκο γι' αυτά, αλλά μπαίνουν ίδια ώστε το
	# .tres να μη διαβάζεται σαν να διαφωνούν οι δύο μορφές
	a.special = "swarm"
	a.special_cost = 12.0
	return a


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

	var idle := _load_frames("death", "idle", FRAME_W)
	var ready_ := _load_frames("death", "ready", FRAME_W)
	var fire := _load_frames("death", "fire", FRAME_W)

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
	d.ball_spin = 2.4              # στροφές/δευτ. — τα δρεπάνια στριφογυρίζουν
	d.awaken_style = "skull"       # μαύρη νεκροκεφαλή αντί για φλόγα
	d.awakened = _make_evolved()
	# Το SWARM ρίχνει άλλη μια πλήρη ριπή. Το κόστος είναι ΣΚΟΤΩΜΟΙ: ο ember
	# είναι στο 8 μετά τη σάρωση, και ο death μπαίνει λίγο πιο ψηλά γιατί
	# ξεκλειδώνει αργότερα, με τον παίκτη να σκοτώνει ήδη πολύ πιο γρήγορα.
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
