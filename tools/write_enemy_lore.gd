extends SceneTree
## Γράφει τις περιγραφές των εχθρών για το Book μέσα στα data/areas/*.tres,
## με ResourceSaver — ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_enemy_lore.gd
##
## Οι εχθροί ζουν ως sub-resources ΚΑΙ στα δύο αρχεία περιοχών, οπότε το ίδιο
## κείμενο μπαίνει σε όποιο αρχείο έχει εχθρό με αυτό το id. Τα κείμενα είναι
## ΜΟΝΟ ASCII: η pixel γραμματοσειρά δεν έχει ελληνικά ούτε — • ·.

const AREAS := [
	"res://data/areas/01_goblin_land.tres",
	"res://data/areas/02_frost_marches.tres",
]

const LORE := {
	"goblin": "Small, greedy and never alone. One goblin is a joke; a whole row of them is a wall.",
	"orc": "Rides a war boar that charges forward every other turn. Burn it before it closes the gap.",
	"knight": "A deserter in stolen plate. The shield soaks every blow until it cracks, so hit it hard and often.",
	"brute": "All muscle and no plan. Slow to fall, so bring plenty of fire.",
	"warlock": "Chants in the back rows and calls servants to the field. Silence it first.",
	"bat": "Summoned by warlocks and kings. Weak alone, but they fill the gaps fast.",
	"goblin_king": "Crowned by the biggest club. Thick hide, a furious temper when wounded, and guards who answer his call.",
	"warlock_boss": "Master of the frozen covens. Keeps calling servants from the ice until he falls.",
}


func _initialize() -> void:
	for path in AREAS:
		var area: AreaDef = load(path)
		var all: Array[EnemyType] = []
		all.append_array(area.enemies)
		all.append_array(area.minions)
		if area.boss:
			all.append(area.boss)
		var n := 0
		for e in all:
			if LORE.has(e.id):
				e.description = LORE[e.id]
				n += 1
			else:
				push_warning("χωρίς περιγραφή: %s" % e.id)
		var err := ResourceSaver.save(area, path)
		print("%s: %d περιγραφές, %s" % [path, n, error_string(err)])
	quit()
