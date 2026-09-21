class_name AreaDef
extends Resource
## Μια περιοχή: δικό της φόντο, δεξαμενή εχθρών και boss στο τέλος.

@export var id := "goblin_land"
@export var display_name := "Goblin Land"
@export var background: Texture2D

## Χρωματικός τόνος για φόντο και εχθρούς — προσωρινή διαφοροποίηση
## μέχρι να υπάρχουν ξεχωριστά γραφικά ανά περιοχή.
@export var tint := Color.WHITE

## Οι τύποι εχθρών που εμφανίζονται εδώ.
@export var enemies: Array[EnemyType] = []

## Τύποι που ΔΕΝ μπαίνουν στη δεξαμενή τυχαίας εμφάνισης, αλλά πρέπει να είναι
## γνωστοί στο παιχνίδι — π.χ. ό,τι καλεί ο summoner. Μένουν έξω από το pick(),
## αλλιώς θα ξεφύτρωναν και μόνα τους στη νέα σειρά κάθε γύρου.
@export var minions: Array[EnemyType] = []

## Ο εχθρός που χρησιμοποιείται ως boss στο τέλος της περιοχής.
@export var boss: EnemyType
@export var boss_cols := 3
@export var boss_rows := 2
@export var boss_hp_mult := 14.0


func pick(tier_roll: float) -> EnemyType:
	if enemies.is_empty():
		return null
	var idx := clampi(int(tier_roll * enemies.size()), 0, enemies.size() - 1)
	return enemies[idx]
