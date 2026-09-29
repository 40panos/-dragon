class_name WarDrumAbility
extends EnemyAbility
## Τύμπανο πολέμου. Όσο χτυπάει έστω ένας τυμπανιστής, ο μεγάλος boss έχει
## ασπίδα και κάθε εχθρός κατεβαίνει μία σειρά παραπάνω. Σκότωσέ τους πρώτα.
## Η ασπίδα υπολογίζεται στο main (update_boss_shield), από όσους ζουν.


func before_advance(_block, game) -> void:
	game.war_drums = true


func describe() -> String:
	return "War drums: shields the boss and hurries every enemy"
