class_name ShatterAbility
extends EnemyAbility
## Θρυμματισμός: όταν σκοτωθεί, σπάει σε μικρότερα κομμάτια που πιάνουν το
## κελί του και τα διπλανά. Σκότωσέ τον νωρίς, πριν γεμίσει το ταμπλό.
##
## Το σπάσιμο γίνεται deferred: ο θάνατος έρχεται μέσα από σύγκρουση μπάλας,
## και νέα σώματα φυσικής δεν μπαίνουν με ασφάλεια μέσα στο callback της. Οι
## τιμές του block περνάνε ως ορίσματα, γιατί ως τότε μπορεί να έχει φύγει.

@export var minion_id := "shardling"
@export var count := 2
## Ζωή κάθε κομματιού, ως ποσοστό της ζωής του εχθρού που έσπασε.
@export var hp_ratio := 0.3


func on_death(block, game) -> void:
	game.call_deferred("spawn_near", block.col, block.row, block.cw, block.ch,
		block.max_hp, minion_id, count, hp_ratio)


func describe() -> String:
	return "Shatter: breaks into %d shards when killed" % count
