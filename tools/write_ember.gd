extends SceneTree
## Γράφει το data/dragons/01_ember.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_ember.gd

const RES_PATH := "res://data/dragons/01_ember.tres"
const FRAME_W := 37          # φυσικό πλάτος καρέ
const SCALE := 4             # ακέραια μεγέθυνση, χωρίς αναδειγματοληψία


func _load_frames(state: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		var path := "res://art/ember_%s_%d.png" % [state, i]
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
	d.fps_idle = 2.0          # ήρεμο ανοιγοκλείσιμο, ~2s ο κύκλος
	d.fps_ready = 6.0         # παλμός έντασης όσο σημαδεύει
	d.fps_fire = 12.0         # γρήγορο ξέσπασμα φλόγας

	d.draw_width = float(FRAME_W * SCALE)   # 148 = 4x, ακέραιο πολλαπλάσιο
	d.tint = Color(1, 1, 1, 1)

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
