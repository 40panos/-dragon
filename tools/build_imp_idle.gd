extends SceneTree
## Ξαναφτιάχνει το idle του Frost Imp από το ίδιο το στατικό του σχέδιο.
##
##   godot --headless --path . --script tools/build_imp_idle.gd
##
## Τα καρέ που είχε βγάλει το animate_image του PixelLab άλλαζαν χρώματα από
## καρέ σε καρέ: κέρατα και κεφάλι σκούραιναν στο 2ο, μαύρες κηλίδες στα πόδια
## στα 6-8, και στον βρόχο ο imp «μαύριζε». Εδώ κάθε καρέ είναι το ίδιο
## σχέδιο με τα ίδια ακριβώς pixel· κινείται μόνο ο κορμός: το πάνω μισό
## (κεφάλι, ώμοι, χέρια) κατεβαίνει ένα pixel στην εκπνοή και ξανανεβαίνει.
## Τα πόδια μένουν καρφωμένα, ώστε ο imp να μη «χορεύει» στο κελί.

const SRC := "res://art/frost_imp.png"
## Μετατόπιση του πάνω μισού ανά καρέ, σε art pixels. 8 καρέ στα 7 fps:
## κρατάει λίγο πάνω, κατεβαίνει, κρατάει κάτω, ανεβαίνει.
const BOB := [0, 0, 0, 1, 1, 1, 1, 0]
## Πού «σπάει» το σώμα, ως κλάσμα του ύψους του σχεδίου από πάνω.
const WAIST := 0.58


func _initialize() -> void:
	var src: Image = (load(SRC) as Texture2D).get_image()
	src.convert(Image.FORMAT_RGBA8)
	var used := src.get_used_rect()
	var waist := used.position.y + int(used.size.y * WAIST)
	for i in BOB.size():
		var dy: int = BOB[i]
		var im := Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8)
		# κάτω μισό όπως είναι
		for y in range(waist, src.get_height()):
			for x in src.get_width():
				im.set_pixel(x, y, src.get_pixel(x, y))
		# πάνω μισό μετατοπισμένο· πατάει πάνω στη μέση, όχι κάτω από αυτήν
		for y in range(0, waist):
			for x in src.get_width():
				var c := src.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				var ty := y + dy
				if ty < src.get_height():
					im.set_pixel(x, ty, c)
		var dst := "res://art/frost_imp_idle_%d.png" % (i + 1)
		im.save_png(ProjectSettings.globalize_path(dst))
		print("γράφτηκε ", dst)
	quit(0)
