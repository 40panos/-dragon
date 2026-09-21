extends SceneTree
## Χτίζει τις τέσσερις λωρίδες του πλαισίου από ξεχωριστά κομμάτια 64x64.
##
##   godot --headless --path . --script tools/build_frame.gd
##
## Ίδια λογική με το build_floor.gd: το main τραβάει ΕΝΑ έτοιμο texture ανά
## πλευρά, οπότε η σύνθεση γίνεται εδώ μια φορά. Τα πλαϊνά είναι ξύλινο
## palisade με σιδερένιες ζώνες· πάνω και κάτω πέτρινο παραπέτο, ώστε το
## πλαίσιο να «κάθεται» σε πέτρα και να μην είναι ξύλο ολόγυρα.
##
## Τα στολίδια (δάδα, λάβαρο, κρανίο) ψήνονται μέσα στις πλαϊνές λωρίδες:
## το _draw_torches() του main σβήνει μόνο του όταν υπάρχει tex_frame_left,
## ακριβώς γιατί περιμένει οι δάδες να είναι ήδη ζωγραφισμένες εδώ.

const TILE := 64
const SIDE_ROWS := 13          # 13 * 64 = 832, όσο ψηλά χρειάζεται η λωρίδα
const BAND_COLS := 10          # 10 * 64 = 640 πλάτος για πάνω και κάτω

# σε ποια σειρά κάθεται το κάθε στολίδι, και πόσο ψηλά μέσα της
const DECOR := [
	["deco_torch", 2, 0],
	["deco_banner", 5, 0],
	["deco_torch", 8, 0],
	["deco_skull", 11, 8],
]


func _img(name_: String) -> Image:
	var tex: Texture2D = load("res://art/%s.png" % name_)
	if tex == null:
		push_error("λείπει: " + name_)
		quit(1)
	var im := tex.get_image()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name_: String) -> void:
	var path := "res://art/%s.png" % name_
	var err := im.save_png(ProjectSettings.globalize_path(path))
	if err != OK:
		push_error("η αποθήκευση απέτυχε (%d): %s" % [err, path])
		quit(1)
	print("γράφτηκε %s — %dx%d" % [path, im.get_width(), im.get_height()])


## Οριζόντια λωρίδα από ένα πλακίδιο που επαναλαμβάνεται.
func _band(tile: Image, cols: int) -> Image:
	var out := Image.create(cols * TILE, TILE, false, Image.FORMAT_RGBA8)
	for c in cols:
		out.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(c * TILE, 0))
	return out


func _initialize() -> void:
	var palisade := _img("wall_palisade")
	var parapet := _img("wall_parapet")

	# --- πλαϊνά: στοίβα από palisade, με τα στολίδια από πάνω
	var left := Image.create(TILE, SIDE_ROWS * TILE, false, Image.FORMAT_RGBA8)
	for r in SIDE_ROWS:
		left.blit_rect(palisade, Rect2i(0, 0, TILE, TILE), Vector2i(0, r * TILE))
	for d in DECOR:
		var deco := _img(d[0])
		var x := int((TILE - deco.get_width()) * 0.5)
		var y := int(d[1]) * TILE + int(d[2])
		# blend, όχι blit: τα στολίδια έχουν διάφανο φόντο και πρέπει να
		# πατήσουν πάνω στο ξύλο, όχι να το τρυπήσουν
		left.blend_rect(deco, Rect2i(Vector2i.ZERO, deco.get_size()), Vector2i(x, y))
	_save(left, "frame_left")

	# η δεξιά πλευρά είναι η αριστερή καθρεφτισμένη, ώστε οι δύο μεριές να
	# κοιτάνε η μία την άλλη αντί να είναι ίδιες μετατοπισμένες
	var right := Image.create_from_data(left.get_width(), left.get_height(),
		false, left.get_format(), left.get_data())
	right.flip_x()
	_save(right, "frame_right")

	# --- πάνω και κάτω: πέτρα
	_save(_band(parapet, BAND_COLS), "frame_top")
	_save(_band(parapet, BAND_COLS), "frame_floor")
	quit(0)
