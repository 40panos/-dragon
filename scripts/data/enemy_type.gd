class_name EnemyType
extends Resource
## Ορισμός ενός τύπου εχθρού. Φτιάξε νέους από τον inspector — δεν χρειάζεται κώδικας.

@export var id := "goblin"
@export var display_name := "Goblin"
@export var sprite: Texture2D

## Πολλαπλασιαστής ζωής πάνω στο επίπεδο του γύρου.
@export var hp_mult := 1.0

## Σε ποια βαθμίδα δυσκολίας εμφανίζεται (0 = πιο αδύναμος).
@export_range(0, 5) var tier := 0

## Προαιρετική ικανότητα. Αντιγράφεται σε κάθε εχθρό ώστε να έχει δική του κατάσταση.
@export var ability: EnemyAbility
