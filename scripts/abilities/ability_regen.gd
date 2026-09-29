class_name RegenerateAbility
extends EnemyAbility
## Αναγέννηση: αν περάσει έναν γύρο χωρίς να χτυπηθεί, παίρνει πίσω ένα
## κομμάτι της ζωής του. Μην τον αφήνεις ούτε έναν γύρο.

@export_range(0.05, 0.5, 0.05) var ratio := 0.2

var _hit := false


func on_damaged(_block, _game) -> void:
	_hit = true


func on_round_end(block, _game) -> void:
	if not _hit and block.hp < block.max_hp:
		block.heal(block.max_hp * ratio)
	_hit = false


func describe() -> String:
	return "Regenerate: heals %d%% after a turn unhit" % roundi(ratio * 100.0)
