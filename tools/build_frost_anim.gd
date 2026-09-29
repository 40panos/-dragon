extends SceneTree
## Περνάει στο art/ τα καρέ του μικρού Frost (βασική μορφή). Τα αρχικά μένουν
## στο bbdragon-art-proposals/graveyard/raw.
##
##   godot --headless --path . --script tools/build_frost_anim.gd
##   godot --headless --path . --script tools/write_frost.gd
##
## idle  : animate_image του PixelLab πάνω στο art/frost.png (anim/frost_idle_0..3,
##         το 4 είναι ξανά το 0). Ανάσα, οι κρύσταλλοι λαμπυρίζουν.
## ready : edit του frost.png (frost_edit/ready_a) και δύο παραλλαγές του (b, c).
##         Φόρτιση, όπως οι πυρακτωμένες ρωγμές του ember: παγωμένες ρούνες
##         ανάβουν σε όλο το πρόσωπο, οι κρύσταλλοι ασπρίζουν, φαίνονται τα δόντια.
## fire  : edit (frost_edit/fire_a) και δύο παραλλαγές. Δέσμη παγωμένης ανάσας
##         από το στόμα και θραύσματα γύρω από το στέμμα, όπως η φλόγα του ember.
## Όλα παίζουν ping-pong (DragonType.frame_for), οπότε η σειρά b-a-c κάνει τη
## μέτρια λάμψη κέντρο του κύκλου.
## Πρώτη δοκιμή για ready/fire ήταν κι αυτή με animate_image, αλλά οι αλλαγές
## έβγαιναν τόσο διακριτικές που στο παιχνίδι δεν φαίνονταν καθόλου.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/graveyard/raw/"
const SOURCES := {
	"idle": ["anim/frost_idle_0", "anim/frost_idle_1", "anim/frost_idle_2", "anim/frost_idle_3"],
	"ready": ["frost_edit/ready_b", "frost_edit/ready_a", "frost_edit/ready_c"],
	"fire": ["frost_edit/fire_b", "frost_edit/fire_a", "frost_edit/fire_c"],
}


func _initialize() -> void:
	for state in SOURCES:
		# καθάρισε παλιά καρέ που περισσεύουν
		var k := 1
		while FileAccess.file_exists(ProjectSettings.globalize_path("res://art/frost_%s_%d.png" % [state, k])):
			if k > SOURCES[state].size():
				DirAccess.remove_absolute(ProjectSettings.globalize_path("res://art/frost_%s_%d.png" % [state, k]))
				DirAccess.remove_absolute(ProjectSettings.globalize_path("res://art/frost_%s_%d.png.import" % [state, k]))
			k += 1
		var n := 1
		for src in SOURCES[state]:
			var path: String = RAW + src + ".png"
			var im := Image.load_from_file(path)
			if im == null or im.get_width() != 64 or im.get_height() != 64:
				push_error("λείπει ή λάθος μέγεθος: " + path)
				quit(1)
				return
			im.convert(Image.FORMAT_RGBA8)
			var dst := "res://art/frost_%s_%d.png" % [state, n]
			im.save_png(ProjectSettings.globalize_path(dst))
			print("γράφτηκε ", dst)
			n += 1
	quit(0)
