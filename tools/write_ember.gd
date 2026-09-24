extends SceneTree
## Γράφει το data/dragons/01_ember.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_ember.gd

const RES_PATH := "res://data/dragons/01_ember.tres"
const FRAME_W := 64          # φυσικό πλάτος καρέ
const SCALE := 2             # ακέραια μεγέθυνση, χωρίς αναδειγματοληψία
const AWAKE_W := 128         # το ίδιο, για την ξυπνημένη μορφή
const AWAKE_SCALE := 2


func _load_frames(state: String, prefix := "ember", want_w := FRAME_W) -> Array[Texture2D]:
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


## Τα καρέ του περιγράμματος λάμψης, από το tools/build_glow.gd. Λείπουν
## σιωπηλά: χωρίς αυτά το block ξαναπέφτει στους παλιούς λευκούς δακτύλιους,
## που είναι αποδεκτή εικόνα, όχι σφάλμα.
func _load_glow(set_: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/glow_%s_%d.png" % [set_, i]
		var tex: Texture2D = load(path) if ResourceLoader.exists(path) else null
		if tex:
			out.append(tex)
	return out


## Η μορφή που βγαίνει όσο καίει το INFERNO: ίδια λογική καρέ, μεγαλύτερο
## σχέδιο. Είναι κανονικός DragonType, οπότε το main τη ζωγραφίζει με τον
## ίδιο κώδικα — μόνο ό,τι αφορά την εμφάνιση γεμίζει εδώ.
func _make_awakened() -> DragonType:
	var a := DragonType.new()
	var idle := _load_frames("idle", "ember_awake", AWAKE_W)
	var ready_ := _load_frames("ready", "ember_awake", AWAKE_W)
	var fire := _load_frames("fire", "ember_awake", AWAKE_W)
	a.id = "ember_awakened"
	a.display_name = "Ember Awakened"
	a.sprite = idle[0]
	a.sprite_idle = idle[0]
	a.sprite_ready = ready_[0]
	a.sprite_fire = fire[0]
	a.frames_idle = idle
	a.frames_ready = ready_
	a.frames_fire = fire
	a.fps_idle = 3.0
	a.fps_ready = 6.0
	a.fps_fire = 12.0
	a.draw_width = float(AWAKE_W * AWAKE_SCALE)   # 256 = 2x
	a.tint = Color(1, 1, 1, 1)
	# Το special_ready() διαβάζει πάντα τον ΚΥΡΙΟ δράκο, όχι την ενεργή μορφή,
	# οπότε αυτό δεν επηρεάζει το παιχνίδι — μπαίνει ίδιο για να μη διαβάζεται
	# αντιφατικά το .tres, όπου η ξυπνημένη έδειχνε άλλο κόστος από τον ember.
	a.special = "inferno"
	a.special_cost = 8.0
	return a


func _initialize() -> void:
	var d := DragonType.new()

	var idle := _load_frames("idle")
	var ready_ := _load_frames("ready")
	var fire := _load_frames("fire")

	d.id = "ember"
	d.display_name = "Ember"

	# στατικά sprite: το πρώτο καρέ κάθε κατάστασης, ως εφεδρεία
	d.sprite = idle[0]
	d.sprite_idle = idle[0]
	d.sprite_ready = ready_[0]
	d.sprite_fire = fire[0]

	d.frames_idle = idle
	d.frames_ready = ready_
	d.frames_fire = fire

	# το φλογερό περίγραμμα που ανάβει στον εχθρό όταν τον χτυπάς
	d.glow_frames = _load_glow("fire")

	# ping-pong 0,1,2,1: η περίοδος είναι 4 βήματα
	d.fps_idle = 3.0          # αργό τρεμόπαιγμα της φλόγας, ~1.3s ο κύκλος
	d.fps_ready = 6.0         # οι φλέβες ανάβουν όσο σημαδεύει
	d.fps_fire = 12.0         # γρήγορο ξέσπασμα φλόγας πάνω από το κεφάλι

	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)
	d.awakened = _make_awakened()

	# ιδιότητες παιχνιδιού
	d.special = "inferno"
	# ΣΚΟΤΩΜΟΙ, όχι ζημιά — το special φορτίζει ανά νεκρό εχθρό. Το 150 ήταν η
	# παλιά τιμή σε ζημιά και είχε μείνει εδώ όταν άλλαξε το σύστημα: το
	# tools/balance_sim.gd έτρεχε πάντα με override, οπότε κανείς δεν είδε ότι
	# στο πραγματικό παιχνίδι το INFERNO δεν φόρτιζε ΠΟΤΕ (80 σκοτωμοί ως τον
	# γύρο 20, 0/60 νίκες επί του boss).
	#
	# Το 8 βγήκε από σάρωση με 60 runs ανά τιμή: πρώτο γέμισμα στον γύρο 7,
	# διάμεσος θάνατος 17 (από 14), 22/60 έφτασαν στον boss (από 9/60). Ο
	# ελάχιστος θάνατος είναι ο γύρος 12, οπότε κάθε παίκτης το βλέπει άνετα
	# πριν τον boss του γύρου 20.
	d.special_cost = 8.0
	d.passive = "every5_double"
	d.unlock_after_area = 0

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — draw_width=%.1f (%dx%d ανά καρέ, %dx)"
		% [RES_PATH, d.draw_width, FRAME_W, idle[0].get_height(), SCALE])
	quit(0)
