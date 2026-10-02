class_name IcebergAbility
extends EnemyAbility
## Παγόβουνο του Wendigo: δεν κατεβαίνει, φράζει τον δρόμο σε μπάλες και
## εχθρούς, και ραγίζει σε στάδια όσο τρώει ζημιά. Αν το σπάσεις, πετάγονται
## από μέσα τέρατα — καλύτερα να το αποφύγεις: μετά από `turns` γύρους λιώνει
## μόνο του, χωρίς να βγάλει τίποτα.

@export var turns := 5
## Τι κρύβει μέσα: id -> βάρος, και πόσα βγαίνουν.
@export var inside := {"frost_imp": 3.0, "snow_wolf": 2.0}
@export var count := 2
## Τα στάδια ραγίσματος: [1] κάτω από τα 2/3 της ζωής, [2] κάτω από το 1/3.
## Το [0] είναι το ακέραιο (το sprite του).
@export var crack_frames: Array[Texture2D] = []

var crack := 0


func on_spawn(block) -> void:
	block.life_turns = turns
	block.life_max = turns


func advance_rows(_block, _default_rows: int) -> int:
	return 0


func on_damaged(block, game) -> void:
	var f: float = block.hp / maxf(block.max_hp, 1.0)
	var want := 0
	if f <= 1.0 / 3.0:
		want = 2
	elif f <= 2.0 / 3.0:
		want = 1
	if want > crack and want < crack_frames.size():
		crack = want
		block.set_idle([crack_frames[want]] as Array[Texture2D], 1.0)
		game.iceberg_cracked(block)


func on_round_end(block, game) -> void:
	block.life_turns -= 1
	if block.life_turns <= 0:
		game.iceberg_melt(block)


## Το σπάσιμο γίνεται deferred, όπως στο ShatterAbility: ο θάνατος έρχεται
## μέσα από σύγκρουση μπάλας, όπου νέα σώματα φυσικής δεν μπαίνουν με ασφάλεια.
func on_death(block, game) -> void:
	var ids: Array[String] = []
	for i in count:
		ids.append(_roll())
	game.call_deferred("iceberg_burst", block.col, block.row, block.position, ids)


func _roll() -> String:
	var total := 0.0
	for k in inside:
		total += float(inside[k])
	var r := randf() * total
	for k in inside:
		r -= float(inside[k])
		if r < 0.0:
			return k
	return inside.keys()[0]


func describe() -> String:
	return "Iceberg: break it and monsters climb out. Melts after %d turns" % turns
