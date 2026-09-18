class_name RiderAbility
extends EnemyAbility
## Καβαλάρης: κάθε Ν γύρους κατεβαίνει διπλό βήμα, αν υπάρχει χώρος.

@export var every := 2
@export var step := 2

var _rounds := 0


func advance_rows(_block, default_rows: int) -> int:
	_rounds += 1
	if _rounds % every == 0:
		return step
	return default_rows


func badge() -> String:
	return ">>"
