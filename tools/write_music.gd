extends SceneTree
## Δίνει σε κάθε περιοχή το soundtrack της (AreaDef.music), με ResourceSaver —
## ποτέ ως κείμενο. Αλλάζει ΜΟΝΟ τη μουσική· ό,τι άλλο έχει η περιοχή μένει.
## Η λούπα δεν γίνεται στο import (loop=false): το MusicPlayer ξαναπιάνει την
## αρχή με crossfade, γιατί τα κομμάτια τελειώνουν απότομα.
##
##   godot --headless --path . --import
##   godot --headless --path . --script tools/write_music.gd
##
## Περιοχές που δεν είναι εδώ μένουν όπως είναι (το Frost Marches σιωπηλό ακόμα).

const MUSIC := {
	"res://data/areas/01_goblin_land.tres": "res://audio/music_goblin_land.mp3",
	"res://data/areas/03_graveyard.tres": "res://audio/music_graveyard.mp3",
}


func _initialize() -> void:
	var failed := false
	for path in MUSIC:
		var song: String = MUSIC[path]
		if not ResourceLoader.exists(song):
			push_error("λείπει: %s (τρέξε πρώτα --import)" % song)
			failed = true
			continue
		var area: AreaDef = load(path)
		area.music = load(song)
		var err := ResourceSaver.save(area, path)
		print("%s: %s — %s" % [path, song.get_file(), error_string(err)])
		failed = failed or err != OK
	quit(1 if failed else 0)
