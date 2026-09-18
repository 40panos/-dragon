class_name EnemyAbility
extends Resource
## Βάση για τις ικανότητες των εχθρών.
##
## Κάθε εχθρός κρατάει δικό του αντίγραφο (duplicate), οπότε οι ικανότητες
## επιτρέπεται να έχουν εσωτερική κατάσταση — μετρητές, ζωή ασπίδας κ.λπ.
## Όλα τα hooks είναι προαιρετικά: παρακάμπτεις μόνο όσα χρειάζεσαι.

## Καλείται μία φορά μόλις τοποθετηθεί ο εχθρός στο ταμπλό.
func on_spawn(_block) -> void:
	pass


## Πόσες σειρές κατεβαίνει φέτος. Ο καλών ελέγχει αν χωράει.
func advance_rows(_block, default_rows: int) -> int:
	return default_rows


## Απορροφά ζημιά πριν φτάσει στη ζωή. Επιστρέφει όση ζημιά περνάει.
func absorb(_block, amount: float) -> float:
	return amount


## Στο τέλος του γύρου, αφού έχουν κατέβει όλοι.
func on_round_end(_block, _game) -> void:
	pass


## Σύντομη ένδειξη που ζωγραφίζεται πάνω στον εχθρό.
func badge() -> String:
	return ""
