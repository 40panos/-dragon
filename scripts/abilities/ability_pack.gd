class_name PackHunterAbility
extends EnemyAbility
## Αγέλη: όταν έχει δίπλα του άλλον της ίδιας αγέλης (ίδιο είδος), κατεβαίνει
## περισσότερο. Σκότωσε τον ένα και ο άλλος ηρεμεί.
##
## Η γειτονιά κοιτιέται στο before_advance, με το ταμπλό όπως ήταν στον γύρο·
## μέσα στο κατέβασμα τα γύρω κελιά αλλάζουν ήδη, και δύο λύκοι θα έβλεπαν
## διαφορετική εικόνα ανάλογα με τη σειρά που κινήθηκαν.

@export var extra := 1

var _pack := false


func before_advance(block, game) -> void:
	_pack = false
	for nb in game.grid.neighbors(block):
		if is_instance_valid(nb) and nb.kind == block.kind:
			_pack = true
			return


func advance_rows(_block, default_rows: int) -> int:
	return default_rows + extra if _pack else default_rows


func describe() -> String:
	return "Pack: moves %d more row next to another of its kind" % extra
