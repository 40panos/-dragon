class_name BarricadeAbility
extends EnemyAbility
## Οδόφραγμα: άθραυστο, δεν κατεβαίνει, και γκρεμίζεται μόνο του μετά από
## `turns` γύρους. Αλλάζει τις γωνίες των αναπηδήσεων — και φράζει τον δρόμο
## και στους εχθρούς που έρχονται από πίσω. Το βαρέλι μπαρούτι το γκρεμίζει.

@export var turns := 3


func on_spawn(block) -> void:
	block.life_turns = turns
	block.life_max = turns


func advance_rows(_block, _default_rows: int) -> int:
	return 0


func on_round_end(block, game) -> void:
	block.life_turns -= 1
	if block.life_turns <= 0:
		game.crumble(block)


func describe() -> String:
	return "Barricade: unbreakable, falls apart after %d turns" % turns
