extends SceneTree
## Φτιάχνει τα μαύρα βλήματα της ξεσκέπαστης μορφής από τα κανονικά.
##
##   godot --headless --path . --script tools/build_dark_balls.gd
##
## Δεν χρειάστηκε νέο σχέδιο: τα δρεπάνια ξαναβάφονται εδώ. Το σχήμα, το
## περίγραμμα και οι σκιές μένουν ακριβώς τα ίδια, οπότε το βλήμα διαβάζεται
## ως το ίδιο αντικείμενο σε άλλη ύλη — σκοτάδι αντί για οστό.
##
## Ο μετασχηματισμός δεν είναι σκέτο σκοτείνιασμα: αυτό θα έλιωνε τα πάντα σε
## μια μαύρη κηλίδα. Ο κορεσμός πέφτει σχεδόν στο μηδέν, η φωτεινότητα
## συμπιέζεται προς τα κάτω αλλά ΔΙΑΤΗΡΕΙ τις διαφορές της, και μπαίνει λίγο
## μενεξεδί ώστε να μην είναι νεκρό γκρι.

const JOBS := [
	{"from": "scythe", "to": "scythe_dark"},
	{"from": "scythe_aoe", "to": "scythe_aoe_dark"},
]

const TINT := Color(0.34, 0.26, 0.46)   # η απόχρωση του σκότους
const FLOOR_ := 0.05                    # πόσο σκούρο γίνεται το πιο σκούρο
const RANGE_ := 0.34                    # πόσο απέχει από αυτό το πιο φωτεινό


func _initialize() -> void:
	for j in JOBS:
		var src := "res://art/%s.png" % j["from"]
		var tex: Texture2D = load(src)
		if tex == null:
			push_error("λείπει: " + src)
			quit(1)
		var im := tex.get_image()
		im.convert(Image.FORMAT_RGBA8)
		for y in im.get_height():
			for x in im.get_width():
				var c := im.get_pixel(x, y)
				if c.a <= 0.0:
					continue
				# φωτεινότητα κατά Rec. 601 — κρατάει τη σχέση φωτός/σκιάς
				var l := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				var v := FLOOR_ + l * RANGE_
				im.set_pixel(x, y, Color(TINT.r * v * 2.0, TINT.g * v * 2.0,
					TINT.b * v * 2.0, c.a))
		var path := "res://art/%s.png" % j["to"]
		var err := im.save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
			quit(1)
		print("γράφτηκε %s από %s" % [path, src])
	quit(0)
