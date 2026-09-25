extends Node2D
## Καιρός της περιοχής — προς το παρόν μόνο χιόνι. Διαβάζει το `weather` της
## τρέχουσας περιοχής (AreaDef) και, όταν είναι "snow", ρίχνει νιφάδες πάνω
## από το ταμπλό. Ζει μέσα στο Main με z_index πάνω από τους εχθρούς, κάτω
## από τα εφέ και το HUD, ώστε να ακολουθεί το screen shake όπως όλος ο κόσμος.
##
## Οι νιφάδες είναι τετράγωνα 4x4 και 6x6 — δηλαδή 2 και 3 art pixels στην
## κλίμακα x2 του παιχνιδιού — και οι θέσεις τους πέφτουν στο πλέγμα των 2px,
## ώστε να κάθονται στο ίδιο πλέγμα με το υπόλοιπο pixel art και όχι να
## θολώνουν ανάμεσα σε pixel.

const FLAKES := 150
const GRID := 2.0

var m
var _flakes: Array = []
var _active := ""


func _process(delta: float) -> void:
	if m == null:
		return
	var area = m.current_area()
	var kind: String = area.weather if area else ""
	if kind != _active:
		_active = kind
		_flakes.clear()
		if kind == "snow":
			for i in FLAKES:
				_flakes.append(_new_flake(true))
	if _active == "snow":
		var bottom: float = m.ui_top
		for f in _flakes:
			f.t += delta
			f.p.y += f.v * delta
			f.p.x += sin(f.t * f.sway_f + f.phase) * f.sway * delta
			if f.p.y > bottom:
				var n := _new_flake(false)
				f.p = n.p
				f.v = n.v
	queue_redraw()


## Μια νιφάδα. Όσες είναι μεγάλες πέφτουν πιο γρήγορα και φωτεινότερες, ώστε
## να δίνουν βάθος: κοντινές μπροστά, μακρινές αχνές και αργές.
func _new_flake(anywhere: bool) -> Dictionary:
	var big := randf() < 0.3
	var top: float = m.PF_TOP - 36.0
	var y := randf_range(top, m.ui_top) if anywhere else top - randf_range(0.0, 60.0)
	return {
		"p": Vector2(randf_range(0.0, m.W), y),
		"v": randf_range(46.0, 70.0) if big else randf_range(22.0, 40.0),
		"size": 6.0 if big else 4.0,
		"a": randf_range(0.75, 0.95) if big else randf_range(0.45, 0.7),
		"sway": randf_range(8.0, 22.0),
		"sway_f": randf_range(0.6, 1.4),
		"phase": randf() * TAU,
		"t": 0.0,
	}


func _draw() -> void:
	if _active != "snow":
		return
	var top: float = m.PF_TOP - 36.0
	for f in _flakes:
		if f.p.y < top:
			continue
		var p := Vector2(floorf(f.p.x / GRID) * GRID, floorf(f.p.y / GRID) * GRID)
		draw_rect(Rect2(p, Vector2(f.size, f.size)), Color(0.93, 0.97, 1.0, f.a))
