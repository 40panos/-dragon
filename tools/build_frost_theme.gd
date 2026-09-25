extends SceneTree
## Φτιάχνει τη χειμερινή εκδοχή του σκηνικού γύρω από την πίστα, από τα ίδια
## τα υπάρχοντα σχέδια — χωρίς νέα generations, ώστε να δένει ακριβώς με το
## σκηνικό των goblins. Γράφει δίπλα σε κάθε σχέδιο ένα <όνομα>_frost.png, και
## το main τα διαλέγει όταν η περιοχή έχει theme = "frost".
##
##   godot --headless --path . --script tools/build_frost_theme.gd
##
## Τι κάνει σε κάθε pixel — ποτέ αναδειγματοληψία, μόνο χρώμα:
##   - ψυχραίνει την παλέτα (λίγο λιγότερος κορεσμός, προς το μπλε)
##   - τα βρύα (πράσινο) γίνονται πάχνη
##   - χιόνι κάθεται στις ΠΑΝΩ άκρες: εκεί όπου από πάνω είναι κενό (πολεμίστρες,
##     κορυφές πύργων) ή σκούρο περίγραμμα (πάνω από κάθε πέτρα, ζώνη, πάσσαλο)
##   - κρέμονται παγάκια κάτω από όσα προεξέχουν πάνω από κενό
##   - στις δάδες η φλόγα γίνεται μπλε, στο λάβαρο το ύφασμα παγωμένο μπλε
## Ό,τι είναι «τυχαίο» (πάχος χιονιού, πού κρέμεται παγάκι) βγαίνει από hash της
## θέσης, ώστε όλα τα καρέ ενός στοιχείου να χιονίζονται ίδια και να μην τρεμοπαίζουν.

const SNOW_TOP := Color("eef4fb")
const SNOW_MID := Color("c9d7e8")
const SNOW_LOW := Color("9fb3cc")
const ICICLE := [Color("dff0ff"), Color("a9cdea"), Color("7aa6cf")]

## όνομα -> τι επιπλέον χρειάζεται (flame: μπλε φλόγα, cloth: μπλε ύφασμα)
const ITEMS := {
	"frame_left": "", "frame_right": "", "frame_top": "",
	"hud_wall": "", "hud_top": "",
	"castle_1": "icicles", "castle_2": "icicles", "castle_3": "icicles",
	"castle_4": "icicles", "castle_5": "icicles",
	"deco_torch_1": "flame", "deco_torch_2": "flame", "deco_torch_3": "flame",
	"deco_torch_4": "flame", "deco_torch_5": "flame",
	"deco_banner": "cloth",
}


func _hash(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663) ^ 0x5bd1e995
	h = (h ^ (h >> 13)) * 1274126177
	return float(absi(h ^ (h >> 16)) % 1000) / 1000.0


func _is_moss(c: Color) -> bool:
	return c.g > c.r + 0.04 and c.g > c.b + 0.02 and c.s > 0.2


func _is_flame(c: Color) -> bool:
	return c.s > 0.35 and c.v > 0.45 and (c.h < 0.17 or c.h > 0.95)


func _cool(c: Color) -> Color:
	var l := c.get_luminance()
	var cold := Color(l * 0.90, l * 0.99, l * 1.14, c.a)
	return c.lerp(cold, 0.45)


func _frost(src: Image, mode: String) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var im := src.duplicate()
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	# 1) χρώμα
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			if mode == "flame" and _is_flame(c):
				# πορτοκαλί/κίτρινο -> γαλάζιο/λευκό, κρατώντας τη διαβάθμιση:
				# ο κίτρινος πυρήνας βγαίνει σχεδόν λευκός, οι κόκκινες άκρες βαθύ μπλε
				var t := clampf(c.h / 0.17, 0.0, 1.0) if c.h < 0.5 else 0.0
				var nc := Color.from_hsv(0.60 - t * 0.08, lerpf(0.85, 0.25, t), minf(1.0, c.v * 1.05), c.a)
				im.set_pixel(x, y, nc)
				continue
			if mode == "cloth" and c.h > 0.18 and c.h < 0.48 and c.s > 0.2:
				im.set_pixel(x, y, Color.from_hsv(0.58, c.s * 0.8, c.v * 1.05, c.a))
				continue
			if _is_moss(c):
				# απαλή πάχνη, όχι λευκό: σε λευκό τα βρύα έβγαζαν «δαντέλα»
				# σε όλη την πέτρα
				im.set_pixel(x, y, _cool(c).lerp(SNOW_LOW, 0.55))
				continue
			im.set_pixel(x, y, _cool(c))
	if mode == "flame":
		return im
	# 2) χιόνι στις πάνω άκρες
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5 or c.get_luminance() < 0.14:
				continue
			var above_empty: bool = not solid.call(x, y - 1)
			var above := src.get_pixel(x, y - 1) if y > 0 else Color(0, 0, 0, 0)
			var under_outline := y > 0 and above.a > 0.5 and above.get_luminance() < 0.14 \
				and c.get_luminance() > above.get_luminance() + 0.12
			if not (above_empty or under_outline):
				continue
			# μέσα στο σχέδιο (κάτω από περίγραμμα) μόνο στο μισό περίπου και
			# πάχος 1: σε κάθε πέτρα έβγαζε θόρυβο. Πάνω σε κενό, 1-3 pixel.
			if under_outline and _hash(x + 11, y + 5) > 0.5:
				continue
			var thick := 1 + int(_hash(x, y) * 3.0) if above_empty else 1
			for k in thick:
				var yy := y + k
				if yy >= h or not solid.call(x, yy) or src.get_pixel(x, yy).get_luminance() < 0.14:
					break
				im.set_pixel(x, yy, SNOW_TOP if k == 0 else (SNOW_MID if k == 1 else SNOW_LOW))
	# 3) παγάκια κάτω από προεξοχές
	if mode == "icicles":
		for y in h:
			for x in w:
				if not solid.call(x, y) or solid.call(x, y + 1):
					continue
				if _hash(x * 3, y * 7) > 0.18 or y + 1 >= h:
					continue
				var length := 2 + int(_hash(x, y * 5) * 3.0)
				for k in length:
					var yy := y + 1 + k
					if yy >= h or solid.call(x, yy):
						break
					var col: Color = ICICLE[mini(k, ICICLE.size() - 1)]
					im.set_pixel(x, yy, Color(col, 1.0 - float(k) / float(length + 1) * 0.5))
	return im


func _initialize() -> void:
	for name_ in ITEMS:
		var path := "res://art/%s.png" % name_
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει: " + path)
			quit(1)
		var src := tex.get_image()
		src.convert(Image.FORMAT_RGBA8)
		var out := _frost(src, ITEMS[name_])
		var dst := "res://art/%s_frost.png" % name_
		out.save_png(ProjectSettings.globalize_path(dst))
		print("γράφτηκε ", dst)
	quit(0)
