class_name RageAbility
extends EnemyAbility
## Οργή: κάτω από ένα κατώφλι ζωής ο εχθρός αλλάζει μορφή και πιέζει.
##
## Αλλάζει το σετ ηρεμίας στον αέρα (block.set_idle), βάφεται κόκκινος και
## αρχίζει να κατεβαίνει διπλό βήμα κάθε Ν γύρους — σαν τον καβαλάρη, αλλά
## μόνο αφού οργιστεί. Γυρισμός πίσω δεν υπάρχει: η ζωή δεν ανεβαίνει ποτέ.

@export_range(0.05, 0.95, 0.05) var threshold := 0.5
@export var frames_rage: Array[Texture2D] = []
@export var fps_rage := 9.0
## Πολλαπλασιάζεται πάνω στο υπάρχον modulate, ώστε να μη χαθεί ο τόνος της περιοχής.
## Ανεβάζει το κόκκινο αντί να κατεβάζει το πράσινο, ώστε το δέρμα να μείνει
## πράσινο αλλά αναμμένο — σκέτη μείωση το έκανε σομόν.
@export var tint := Color(1.22, 0.94, 0.88)
@export var every := 2           # κάθε πόσους γύρους κάνει το μεγάλο βήμα
@export var step := 2
@export var announce := "THE KING IS ENRAGED"

var raged := false

var _rounds := 0


func on_damaged(block, game) -> void:
	if raged or block.max_hp <= 0.0:
		return
	if block.hp / block.max_hp > threshold:
		return
	raged = true
	if not frames_rage.is_empty():
		block.set_idle(frames_rage, fps_rage)
	block.modulate *= tint
	if game:
		game.add_shake(8.0)
		if announce != "":
			game._announce(announce)


func advance_rows(_block, default_rows: int) -> int:
	if not raged:
		return default_rows
	_rounds += 1
	if _rounds % every == 0:
		return maxi(default_rows, step)
	return default_rows


func badge() -> String:
	return "!!" if raged else ""


func describe() -> String:
	return "Rage: below %d%% health it charges" % roundi(threshold * 100.0)
