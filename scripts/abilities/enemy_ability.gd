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


## Μόλις ο εχθρός φάει ζημιά και επιβιώσει. Το καλεί το main, γιατί εκεί
## υπάρχει η αναφορά στο παιχνίδι — το block δεν την κρατάει.
func on_damaged(_block, _game) -> void:
	pass


## Μία γραμμή για το Book: τι κάνει η ικανότητα, με τα δικά της νούμερα.
## ΜΟΝΟ ASCII, όπως κάθε κείμενο στην οθόνη.
func describe() -> String:
	return ""


## Το αντίγραφο που παίρνει κάθε εχθρός. Ξεχωριστή συνάρτηση και όχι σκέτο
## duplicate(), ώστε το CompositeAbility να μπορεί να αντιγράψει και τα μέρη
## του — αλλιώς όλοι οι εχθροί θα μοιράζονταν τους ίδιους μετρητές.
func clone() -> EnemyAbility:
	return duplicate() as EnemyAbility


## Σύντομη ένδειξη που ζωγραφίζεται πάνω στον εχθρό.
func badge() -> String:
	return ""
