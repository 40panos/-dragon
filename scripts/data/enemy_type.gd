class_name EnemyType
extends Resource
## Ορισμός ενός τύπου εχθρού. Φτιάξε νέους από τον inspector — δεν χρειάζεται κώδικας.

@export var id := "goblin"
@export var display_name := "Goblin"
@export var sprite: Texture2D

## Καρέ ήρεμης στάσης (idle loop). Αν είναι άδειο, μένει στο στατικό sprite.
@export var frames_idle: Array[Texture2D] = []
@export var fps_idle := 6.0

## Καρέ αντίδρασης σε χτύπημα — παίζουν ΜΙΑ φορά (όχι loop) κάθε φορά που
## δέχεται ζημιά, μετά ξαναγυρίζει στο idle. Αν είναι άδειο, δεν αλλάζει τίποτα.
@export var frames_hit: Array[Texture2D] = []
@export var fps_hit := 12.0

## Πολλαπλασιαστής ζωής πάνω στο επίπεδο του γύρου.
@export var hp_mult := 1.0

## Σε ποια βαθμίδα δυσκολίας εμφανίζεται (0 = πιο αδύναμος).
@export_range(0, 5) var tier := 0

## Προαιρετική ικανότητα. Αντιγράφεται σε κάθε εχθρό ώστε να έχει δική του κατάσταση.
@export var ability: EnemyAbility
