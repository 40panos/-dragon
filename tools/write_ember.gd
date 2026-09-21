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

	# ping-pong 0,1,2,1: η περίοδος είναι 4 βήματα
	d.fps_idle = 3.0          # αργό τρεμόπαιγμα της φλόγας, ~1.3s ο κύκλος
	d.fps_ready = 6.0         # οι φλέβες ανάβουν όσο σημαδεύει
	d.fps_fire = 12.0         # γρήγορο ξέσπασμα φλόγας πάνω από το κεφάλι

	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)
	d.awakened = _make_awakened()

	# ιδιότητες παιχνιδιού, όπως ήταν
	d.special = "inferno"
	d.special_cost = 150.0
	d.passive = "every5_double"
	d.unlock_after_area = 0

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — draw_width=%.1f (%dx%d ανά καρέ, %dx)"
		% [RES_PATH, d.draw_width, FRAME_W, idle[0].get_height(), SCALE])
	quit(0)
