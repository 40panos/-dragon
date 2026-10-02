extends SceneTree
## Ορίζει το πλέγμα κάθε περιοχής (AreaDef.cols / cell_px / pixel_snap), με
## ResourceSaver — ποτέ ως κείμενο. Αλλάζει ΜΟΝΟ αυτά· ό,τι άλλο έχει η
## περιοχή μένει. Περιοχές που δεν είναι εδώ κρατάνε το βασικό πλέγμα του main
## (7 στήλες, κελί 85.7).
##
##   godot --headless --path . --script tools/build_floor.gd   (το φόντο στο νέο πλέγμα)
##   godot --headless --path . --import
##   godot --headless --path . --script tools/write_layout.gd
##
## Το Frost Marches: 8 στήλες με κελί 72. Κουτί 66 -> τα 32px σχέδια χωράνε
## ακριβώς x2 (64), οι 3x3 boss (96px) επίσης x2 (192). Το φόντο του είναι
## πλακίδια 36 art pixels σε 8 στήλες (x2 = ένα κελί).

const LAYOUT := {
	"res://data/areas/02_frost_marches.tres": {"cols": 8, "cell_px": 72.0, "pixel_snap": true},
}


func _initialize() -> void:
	var failed := false
	for path in LAYOUT:
		var spec: Dictionary = LAYOUT[path]
		var area: AreaDef = load(path)
		area.cols = spec.cols
		area.cell_px = spec.cell_px
		area.pixel_snap = spec.pixel_snap
		var err := ResourceSaver.save(area, path)
		print("%s: %d στήλες, κελί %.0f, snap %s — %s"
			% [path, area.cols, area.cell_px, area.pixel_snap, error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)
