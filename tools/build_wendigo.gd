extends SceneTree
## Περνάει στο art/ τα γραφικά του μεγάλου boss του Frost Marches (Ice
## Wendigo) και τα παγόβουνά του. Τα αρχικά του PixelLab μένουν στο
## bbdragon-art-proposals/wendigo/raw.
##
##   godot --headless --path . --script tools/build_wendigo.gd
##   godot --headless --path . --script tools/write_wendigo.gd
##
## Τα animate_image βγήκαν με καρφωμένο τελευταίο καρέ: στους βρόχους (idle,
## παγωμένο idle) και στις κινήσεις που γυρίζουν στη στάση (hit, slam) είναι
## ίδιο με το πρώτο και δεν μπαίνει. Στις μεταβάσεις (λάμψη, πάγωμα) το
## καρφωμένο είναι ο ΣΤΟΧΟΣ — εκεί μένει.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/wendigo/raw/"

## όνομα στο art/ -> τα raw καρέ με τη σειρά. Το πρώτο του idle είναι και το
## στατικό sprite (wendigo.png).
const FRAMES := {
	"wendigo_idle": ["idle_0", "idle_1", "idle_2", "idle_3", "idle_4", "idle_5", "idle_6", "idle_7"],
	"wendigo_hit": ["hit_1", "hit_2", "hit_3", "hit_4", "hit_5"],
	# glareup_1: λευκός θόρυβος στα κέρατα — έξω
	"wendigo_glare": ["glareup_2", "glareup_3", "glare"],
	"wendigo_freeze": ["freeze_1", "freeze_2", "freeze_3", "freeze_4", "freeze_5", "freeze_6"],
	"wendigo_frozen": ["fidle_0", "fidle_1", "fidle_2", "fidle_3", "fidle_4", "fidle_5"],
	"wendigo_slam": ["slam_1", "slam_2", "slam_3", "slam_4", "slam_5", "slam_6", "slam_7"],
	# παγόβουνο: ακέραιο, ραγισμένο, έτοιμο να σπάσει
	"iceberg_crack": ["berg_c1", "berg_c2"],
}
const SINGLE := {"wendigo": "idle_0", "iceberg": "berg_a"}


func _load(name_: String) -> Image:
	var im := Image.load_from_file(RAW + name_ + ".png")
	if im == null:
		push_error("λείπει: " + RAW + name_ + ".png")
		quit(1)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name_: String) -> void:
	im.save_png(ProjectSettings.globalize_path("res://art/%s.png" % name_))


func _initialize() -> void:
	for name_ in SINGLE:
		_save(_load(SINGLE[name_]), name_)
	for name_ in FRAMES:
		var list: Array = FRAMES[name_]
		var size := Vector2i.ZERO
		for k in list.size():
			var im := _load(list[k])
			if size == Vector2i.ZERO:
				size = im.get_size()
			elif im.get_size() != size:
				push_error("%s: %s, περίμενα %s" % [list[k], im.get_size(), size])
				quit(1)
				return
			_save(im, "%s_%d" % [name_, k + 1])
		print("%s: %d καρέ" % [name_, list.size()])
	quit(0)
