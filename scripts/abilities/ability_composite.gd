class_name CompositeAbility
extends EnemyAbility
## Πολλές ικανότητες σε έναν εχθρό. Το EnemyType κρατάει ΜΙΑ ability, οπότε
## ένα boss με περισσότερες τις δένει εδώ.
##
## Τα hooks προωθούνται με τη σειρά της λίστας. Το absorb και το advance_rows
## περνάνε αλυσιδωτά το αποτέλεσμα του προηγούμενου, ώστε δύο μέρη να μπορούν
## να μειώσουν μαζί την ίδια ζημιά.

@export var parts: Array[EnemyAbility] = []


func clone() -> EnemyAbility:
	var c := duplicate() as CompositeAbility
	var fresh: Array[EnemyAbility] = []
	for p in parts:
		if p:
			fresh.append(p.clone())
	c.parts = fresh
	return c


func on_spawn(block) -> void:
	for p in parts:
		p.on_spawn(block)


func advance_rows(block, default_rows: int) -> int:
	var rows := default_rows
	for p in parts:
		rows = p.advance_rows(block, rows)
	return rows


func absorb(block, amount: float) -> float:
	var through := amount
	for p in parts:
		through = p.absorb(block, through)
	return through


func on_round_end(block, game) -> void:
	for p in parts:
		p.on_round_end(block, game)


func on_damaged(block, game) -> void:
	for p in parts:
		p.on_damaged(block, game)


func badge() -> String:
	var tags: Array[String] = []
	for p in parts:
		var t: String = p.badge()
		if t != "":
			tags.append(t)
	return " ".join(tags)
