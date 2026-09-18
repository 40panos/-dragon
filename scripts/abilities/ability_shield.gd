class_name ShieldAbility
extends EnemyAbility
## Ασπιδοφόρος: η ασπίδα έχει δική της ζωή και τρώει όλη τη ζημιά μέχρι να σπάσει.

@export var ratio := 1.0     # ζωή ασπίδας ως ποσοστό της ζωής του εχθρού

var shield := 0.0
var shield_max := 0.0


func on_spawn(block) -> void:
	shield_max = maxf(1.0, block.max_hp * ratio)
	shield = shield_max


func absorb(_block, amount: float) -> float:
	if shield <= 0.0:
		return amount
	var used := minf(shield, amount)
	shield -= used
	return amount - used


func badge() -> String:
	return "" if shield <= 0.0 else "[]"
