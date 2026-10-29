extends SceneTree
## Φτιάχνει τη θαλασσινή εκδοχή του σκηνικού γύρω από την πίστα, από τα ίδια τα
## υπάρχοντα σχέδια — όπως τα build_frost_theme.gd και build_grave_theme.gd,
## χωρίς νέα generations. Γράφει δίπλα σε κάθε σχέδιο ένα <όνομα>_sea.png, και
## το main τα διαλέγει όταν η περιοχή έχει theme = "sea".
##
##   godot --headless --path . --script tools/build_sea_theme.gd
##
## Τι κάνει σε κάθε pixel — ποτέ αναδειγματοληψία, μόνο χρώμα:
##   - βρεγμένη παλέτα: λίγο πιο σκούρα, προς το ψυχρό πρασινομπλέ της θάλασσας
##   - τα βρύα γίνονται φύκια, σκούρο πρασινωπό του βυθού
##   - στις δάδες η φλόγα γίνεται κυανή, φανάρια βυθού
##   - στο λάβαρο το ύφασμα γίνεται βαθύ μπλε του ωκεανού
##   - φύκια κρέμονται κάτω από τις προεξοχές των πύργων
## Ό,τι είναι «τυχαίο» βγαίνει από hash της θέσης, ώστε όλα τα καρέ ενός
## στοιχείου να αλλάζουν ίδια και να μην τρεμοπαίζουν.

const WEED := Color("2f5a3c")
const WEED_DARK := Color("1d3a2a")

## όνομα -> τι επιπλέον χρειάζεται (flame: κυανή φλόγα, cloth: μπλε ύφασμα,
## weed: φύκια που κρέμονται)
const ITEMS := {
	# τα πλαϊνά (frame_left/right_sea) είναι δικός τους τοίχος από ξύλα και
	# κόκαλα, από το tools/build_frame.gd
	"frame_top": "",
	"hud_wall": "", "hud_top": "",
	"castle_1": "weed", "castle_2": "weed", "castle_3": "weed",
	"castle_4": "weed", "castle_5": "weed",
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


## Βρεγμένη πέτρα και ξύλο: προς το πρασινομπλέ, λίγο πιο σκούρα.
func _wet(c: Color) -> Color:
	var l := c.get_luminance()
	var sea := Color(l * 0.80, l * 0.98, l * 1.08, c.a) * 0.80
	sea.a = c.a
	var out := c.lerp(sea, 0.55)
	out.a = c.a
	return out


func _sea(src: Image, mode: String) -> Image:
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
				# πορτοκαλί/κίτρινο -> κυανό· ο κίτρινος πυρήνας σχεδόν λευκός
				var t := clampf(c.h / 0.17, 0.0, 1.0) if c.h < 0.5 else 0.0
				im.set_pixel(x, y, Color.from_hsv(0.53 - t * 0.03, lerpf(0.85, 0.25, t),
					minf(1.0, c.v * 1.05), c.a))
				continue
			if mode == "cloth" and c.h > 0.18 and c.h < 0.48 and c.s > 0.2:
				im.set_pixel(x, y, Color.from_hsv(0.60, c.s * 0.75, c.v * 0.80, c.a))
				continue
			if _is_moss(c):
				im.set_pixel(x, y, Color.from_hsv(0.40, 0.45, c.v * 0.60, c.a))
				continue
			im.set_pixel(x, y, _wet(c))
	# φύκια: κάτω από ακμή με κενό από κάτω, λωρίδες 2-5 pixel που κρέμονται
	if mode == "weed":
		for y in h:
			for x in w:
				if not solid.call(x, y) or solid.call(x, y + 1):
					continue
				if _hash(x * 7, y * 5) > 0.10:
					continue
				var length := 2 + int(_hash(x, y * 3) * 4.0)
				for k in length:
					var px := x + (1 if k >= 3 and _hash(x, y) > 0.5 else 0)
					var py := y + 1 + k
					if px >= w or py >= h or solid.call(px, py):
						break
					im.set_pixel(px, py, WEED if k < length - 1 else WEED_DARK)
	return im


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
		var out := _sea(src, ITEMS[name_])
		var dst := "res://art/%s_sea.png" % name_
		out.save_png(ProjectSettings.globalize_path(dst))
		print("γράφτηκε ", dst)
	quit(0)
