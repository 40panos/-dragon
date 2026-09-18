class_name SaveManager
extends RefCounted
## Αποθήκευση με πεδίο έκδοσης, ώστε να μπορεί να μεταναστεύσει αργότερα
## χωρίς να σπάσουν τα υπάρχοντα αρχεία των παικτών.

const PATH := "user://save.json"
const LEGACY_PATH := "user://best.dat"
const VERSION := 2


static func defaults() -> Dictionary:
	return {
		"version": VERSION,
		"best_score": 0,
		"best_round": 0,
		"unlocked_areas": 1,
		"unlocked_dragons": ["ember"],
		"selected_dragon": "ember",
	}


static func load_data() -> Dictionary:
	var data := defaults()

	if FileAccess.file_exists(PATH):
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					data[k] = parsed[k]
		return _migrate(data)

	# μετανάστευση από την παλιά μορφή (σκέτος ακέραιος)
	if FileAccess.file_exists(LEGACY_PATH):
		var lf := FileAccess.open(LEGACY_PATH, FileAccess.READ)
		if lf:
			data["best_score"] = lf.get_32()
		save_data(data)

	return data


static func save_data(data: Dictionary) -> void:
	data["version"] = VERSION
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))


static func _migrate(data: Dictionary) -> Dictionary:
	var v := int(data.get("version", 1))
	if v < 2:
		# η έκδοση 1 κρατούσε μόνο ρεκόρ· τα υπόλοιπα παίρνουν προεπιλογές
		var base := defaults()
		base["best_score"] = int(data.get("best_score", 0))
		data = base
		save_data(data)
	return data
