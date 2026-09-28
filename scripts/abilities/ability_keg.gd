class_name PowderKegAbility
extends EnemyAbility
## Βαρέλι μπαρούτι. Σκάει με το πρώτο χτύπημα και η έκρηξη πιάνει τα γύρω
## κελιά (3x3): σκοτώνει τα minions, γκρεμίζει οδοφράγματα και, αν ο boss
## είναι δίπλα, του παίρνει ένα κομμάτι της ζωής του. Ρίσκο με ανταμοιβή.
## Αν το αφήσεις, το φυτίλι καίγεται σε `fuse` γύρους: σκάει μόνο του, χωρίς
## να πειράξει κανέναν, και από τα συντρίμμια πετάγονται goblins.

@export var fuse := 3
## Ζημιά της έκρηξης στον boss, ως ποσοστό της μέγιστης ζωής του.
@export var boss_ratio := 0.07
@export var fizzle_minions := 2
@export var minion_id := "goblin"


func on_spawn(block) -> void:
	block.fuse = fuse


func on_round_end(block, game) -> void:
	block.fuse -= 1
	if block.fuse <= 0:
		game.keg_fizzle(block, minion_id, fizzle_minions)


func on_death(block, game) -> void:
	# deferred: ο θάνατος έρχεται μέσα από σύγκρουση μπάλας
	game.call_deferred("keg_blast", block.col, block.row, block.position, boss_ratio)


func describe() -> String:
	return "Powder keg: hit it to blow up everything around it"
