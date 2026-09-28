extends SceneTree
## Φτιάχνει τη νεκροταφειακή εκδοχή του σκηνικού γύρω από την πίστα, από τα
## ίδια τα υπάρχοντα σχέδια — όπως το tools/build_frost_theme.gd, χωρίς νέα
## generations. Γράφει δίπλα σε κάθε σχέδιο ένα <όνομα>_grave.png, και το main
## τα διαλέγει όταν η περιοχή έχει theme = "grave".
##
##   godot --headless --path . --script tools/build_grave_theme.gd
##
## Τι κάνει σε κάθε pixel — ποτέ αναδειγματοληψία, μόνο χρώμα:
##   - σκοτεινιάζει και ξεθωριάζει την παλέτα, προς ένα ψυχρό μωβ-γκρι
##   - τα βρύα (πράσινο) γίνονται νεκρό, σκονισμένο λαδί
##   - στις δάδες η φλόγα γίνεται πράσινη, φωτιά φαντασμάτων
##   - στο λάβαρο το ύφασμα γίνεται σκούρο μωβ
##   - ιστοί αράχνης σε κάποιες γωνίες κάτω από προεξοχές (μόνο στους πύργους)
## Ό,τι είναι «τυχαίο» βγαίνει από hash της θέσης, ώστε όλα τα καρέ ενός
## στοιχείου να αλλάζουν ίδια και να μην τρεμοπαίζουν.

const WEB := Color(0.78, 0.78, 0.84, 0.55)

## όνομα -> τι επιπλέον χρειάζεται (flame: πράσινη φλόγα, cloth: μωβ ύφασμα,
## webs: ιστοί)
const ITEMS := {
	# τα πλαϊνά (frame_left/right_grave) είναι δικός τους τοίχος κατακομβών,
	# από το tools/build_frame.gd — όχι σκοτεινιασμένο ξύλο
	"frame_top": "",
	"hud_wall": "", "hud_top": "",
	"castle_1": "webs", "castle_2": "webs", "castle_3": "webs",
	"castle_4": "webs", "castle_5": "webs",
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


func _gloom(c: Color) -> Color:
	var l := c.get_luminance()
	var cold := Color(l * 0.94, l * 0.88, l * 1.06, c.a) * 0.72
	cold.a = c.a
	var out := c.lerp(cold, 0.62)
	out.a = c.a
	return out


func _grave(src: Image, mode: String) -> Image:
	var w := src.get_width()
	var h := src.get_height()
	var im := src.duplicate()
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < w and y < h and src.get_pixel(x, y).a > 0.5
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a <= 0.5:
				continue
			if mode == "flame" and _is_flame(c):
				# πορτοκαλί/κίτρινο -> πράσινο φαντασμάτων· ο κίτρινος πυρήνας
				# βγαίνει σχεδόν λευκοπράσινος, οι κόκκινες άκρες βαθύ πράσινο
				var t := clampf(c.h / 0.17, 0.0, 1.0) if c.h < 0.5 else 0.0
				im.set_pixel(x, y, Color.from_hsv(0.36 - t * 0.04, lerpf(0.9, 0.35, t),
					minf(1.0, c.v * 1.05), c.a))
				continue
			if mode == "cloth" and c.h > 0.18 and c.h < 0.48 and c.s > 0.2:
				im.set_pixel(x, y, Color.from_hsv(0.78, c.s * 0.65, c.v * 0.75, c.a))
				continue
			if _is_moss(c):
				im.set_pixel(x, y, Color.from_hsv(0.2, 0.22, c.v * 0.55, c.a))
				continue
			im.set_pixel(x, y, _gloom(c))
	# ιστοί: τρίγωνο 3-4 pixel στις γωνίες κάτω από προεξοχή πάνω από κενό
	if mode == "webs":
		for y in h:
			for x in w:
				if not solid.call(x, y) or solid.call(x, y + 1) or solid.call(x + 1, y + 1):
					continue
				if not solid.call(x + 1, y) or _hash(x * 5, y * 3) > 0.08:
					continue
				var size := 3 + int(_hash(x, y) * 2.0)
				for k in size:
					for j in size - k:
						var px := x + 1 + j
						var py := y + 1 + k
						if px < w and py < h and not solid.call(px, py) and (j + k) % 2 == 0:
							im.set_pixel(px, py, WEB)
	return im


## Κρανία σε παλούκια πάνω στο χαμηλό τείχος του κάστρου, ένα δίπλα σε κάθε
## πύργο (ο δεξής καθρεφτισμένος). Το τείχος ανάμεσα στους πύργους πατάει στο
## y≈46 του καμβά 360x64· το παλούκι (art/deco_skull_pike.png, 24x32,
## PixelLab) καρφώνεται λίγο μέσα του, ώστε να μη φαίνεται να αιωρείται.
const PIKE := "res://art/deco_skull_pike.png"
const PIKE_X := [84, 252]
const PIKE_GROUND := 48


func _add_pikes(im: Image) -> void:
	var pike: Image = (load(PIKE) as Texture2D).get_image()
	pike.convert(Image.FORMAT_RGBA8)
	var used := pike.get_used_rect()
	var y := PIKE_GROUND - used.end.y
	for i in PIKE_X.size():
		var p := pike
		if i == 1:
			p = pike.duplicate()
			p.flip_x()
		im.blend_rect(p, Rect2i(Vector2i.ZERO, p.get_size()), Vector2i(PIKE_X[i], y))


func _initialize() -> void:
	for name_ in ITEMS:
		var path := "res://art/%s.png" % name_
		var tex: Texture2D = load(path)
		if tex == null:
			push_error("λείπει: " + path)
			quit(1)
			return
		var src := tex.get_image()
		src.convert(Image.FORMAT_RGBA8)
		var out := _grave(src, ITEMS[name_])
		if name_.begins_with("castle_"):
			_add_pikes(out)
		var dst := "res://art/%s_grave.png" % name_
		out.save_png(ProjectSettings.globalize_path(dst))
		print("γράφτηκε ", dst)
	quit(0)
