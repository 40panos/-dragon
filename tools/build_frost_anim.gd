extends SceneTree
## Περνάει στο art/ τα καρέ του μικρού Frost (βασική μορφή), που βγήκαν με το
## animate_image του PixelLab πάνω στο art/frost.png. Τα αρχικά μένουν στο
## bbdragon-art-proposals/graveyard/raw/anim (frost_<κατάσταση>_0..4, όπου 0
## είναι το ίδιο το frost.png).
##
##   godot --headless --path . --script tools/build_frost_anim.gd
##   godot --headless --path . --script tools/write_frost.gd
##
## Ποια καρέ κρατάμε (παίζουν ping-pong, βλ. DragonType.frame_for):
##   idle  0-3: ανάσα, οι κρύσταλλοι λαμπυρίζουν (το 4 είναι ξανά το 0)
##   ready 0-2: τα μάτια στενεύουν, ο κορμός των κρυστάλλων ανάβει. Στο 2 το
##              μοντέλο έβαψε τα μάτια κόκκινα — εδώ γυρίζουν στο γαλάζιο του.
##   fire  0-2: οι κρύσταλλοι αστράφτουν λευκοί. Τα 3-4 έχαναν τη μορφή του
##              κεφαλιού (λευκή μάζα στο στόμα) και έμειναν έξω.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/graveyard/raw/anim/"
const KEEP := {"idle": [0, 1, 2, 3], "ready": [0, 1, 2], "fire": [0, 1, 2]}


## Κόκκινα / πορτοκαλί μάτια -> το παγωμένο γαλάζιο του δράκου.
func _cool_eyes(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a < 0.5 or c.s < 0.35 or c.v < 0.3:
				continue
			if c.h < 0.12 or c.h > 0.92:
				im.set_pixel(x, y, Color.from_hsv(0.52, clampf(c.s, 0.4, 0.8), maxf(c.v, 0.85), c.a))


func _initialize() -> void:
	for state in KEEP:
		var n := 1
		for idx in KEEP[state]:
			var path: String = RAW + "frost_%s_%d.png" % [state, idx]
			var im := Image.load_from_file(path)
			if im == null or im.get_width() != 64:
				push_error("λείπει ή λάθος μέγεθος: " + path)
				quit(1)
				return
			im.convert(Image.FORMAT_RGBA8)
			_cool_eyes(im)
			var dst := "res://art/frost_%s_%d.png" % [state, n]
			im.save_png(ProjectSettings.globalize_path(dst))
			print("γράφτηκε ", dst)
			n += 1
	quit(0)
