class_name WendigoAbility
extends EnemyAbility
## Ο Ice Wendigo — ο μεγάλος boss του Frost Marches.
##
## Ακίνητος, όπως ο πύργος του Grukk. Τρία κόλπα:
##   Icebergs   χτυπάει τα νύχια στο έδαφος και παγόβουνα σκίζουν το πάτωμα σε
##              τυχαία κελιά. Έχουν ζωή· αν τα σπάσεις, βγαίνουν από μέσα τέρατα.
##              Αν τα αφήσεις, λιώνουν μόνα τους (IcebergAbility).
##   Χιονοθύελλα  στη μισή ζωή παγώνει μέσα σε κέλυφος πάγου: η πίστα γεμίζει
##              ομίχλη και χιόνι, και από μέσα βγαίνει ένα μεγάλο κύμα εχθρών.
##              Όσο ζει έστω κι ένας, ο Wendigo είναι άτρωτος και γιατρεύεται
##              κάθε γύρο. Μόλις πέσει και ο τελευταίος, σπάει τον πάγο — πιο
##              άγριος: παγόβουνα κάθε γύρο.
##   Βλέμμα     σε τυχαία στιγμή μέσα σε μια βολή, τα μάτια του αστράφτουν: όλες
##              οι μπάλες στον αέρα παγώνουν και σπάνε, η βολή ακυρώνεται.
##
## Ό,τι βγαίνει στο ταμπλό περιμένει το τέλος του γύρου (όπως οι ρίψεις του
## Grukk): ένα παγόβουνο που ξεφυτρώνει ανάμεσα σε μπάλες θα τις παγίδευε.

@export var iceberg_id := "iceberg"
@export var iceberg_every := 2           # γύροι ανάμεσα στα παγόβουνα (πριν τη θύελλα)
@export var iceberg_every_rage := 1      # ...και μετά
@export var icebergs := 2                # πόσα κάθε φορά
@export var icebergs_rage := 3
@export var max_icebergs := 6            # όριο στο ταμπλό, να μη φράξει η πίστα
@export var freeze_at := 0.5
@export var heal_ratio := 0.05           # ανά γύρο, όσο είναι παγωμένος
## Το κύμα της χιονοθύελλας: id -> βάρος, και πόσοι.
@export var wave := {"frost_imp": 5.0, "snow_wolf": 3.0, "viking": 2.0}
@export var wave_count := 10
@export var wave_hp := 0.7               # ζωή μελών του κύματος, πάνω στο κανονικό
## Πιθανότητα ανά γύρο να «κοιτάξει» μέσα στη βολή, και μετά από πόσα
## χτυπήματα το νωρίτερο / το αργότερο. Ποτέ δύο γύρους στη σειρά.
@export var glare_chance := 0.35
@export var glare_chance_rage := 0.5
@export var glare_hits := Vector2i(6, 28)

## Καρέ: χτύπημα στο έδαφος (παγόβουνα), μάτια που ανάβουν (βλέμμα), πάγωμα
## (κανονικό -> κέλυφος), παγωμένη στάση (βρόχος), και η κανονική στάση για
## την επιστροφή.
@export var slam_frames: Array[Texture2D] = []
@export var glare_frames: Array[Texture2D] = []
@export var freeze_frames: Array[Texture2D] = []
@export var frozen_idle: Array[Texture2D] = []
@export var act_fps := 10.0
## Το σημείο ανάμεσα στα μάτια, ως κλάσμα του σχεδίου (0..1): από εκεί ξεκινάει
## η λάμψη του βλέμματος.
@export var eyes_uv := Vector2(0.5, 0.22)
@export var eyes_gap := 0.09             # απόσταση των δύο ματιών, ως κλάσμα του πλάτους

## 1 κανονικός · 2 παγωμένος (κύμα στο ταμπλό) · 3 ξύπνησε, πιο άγριος
var stage := 1
var berg_wait := 2
var wave_out := false        # το κύμα έχει βγει (στο τέλος του πρώτου παγωμένου γύρου)
var _hits := 0
var _glare_at := -1
var _glared_last := false


func on_spawn(_block) -> void:
	berg_wait = iceberg_every
	_glare_at = -1           # ο πρώτος γύρος χωρίς βλέμμα: πρώτα τον γνωρίζεις


func advance_rows(_block, _default_rows: int) -> int:
	return 0


func frozen() -> bool:
	return stage == 2


## Πόσοι γύροι ως τα επόμενα παγόβουνα (για την ένδειξη του HUD).
func icebergs_in() -> int:
	return berg_wait


func on_damaged(block, game) -> void:
	if stage == 1 and block.hp / maxf(block.max_hp, 1.0) <= freeze_at:
		stage = 2
		wave_out = false
		_glare_at = -1
		game.wendigo_freeze(block, self)
		return
	if stage == 2:
		return
	_hits += 1
	if _glare_at > 0 and _hits >= _glare_at:
		_glare_at = -1
		_glared_last = true
		game.wendigo_glare(block, self)


func on_round_end(block, game) -> void:
	_hits = 0
	# βλέμμα στον επόμενο γύρο; αποφασίζεται τώρα, μαζί με το σημείο της βολής
	var chance := glare_chance_rage if stage == 3 else glare_chance
	if stage != 2 and not _glared_last and randf() < chance:
		_glare_at = randi_range(glare_hits.x, glare_hits.y)
	else:
		_glare_at = -1
	_glared_last = false

	if stage == 2:
		if not wave_out:
			wave_out = true
			game.wendigo_wave(block, self)
		elif game.wave_left() == 0:
			stage = 3
			berg_wait = 1
			game.wendigo_thaw(block, self)
		else:
			game.wendigo_heal(block, block.max_hp * heal_ratio)
		return

	berg_wait -= 1
	if berg_wait <= 0:
		berg_wait = iceberg_every_rage if stage == 3 else iceberg_every
		var n := icebergs_rage if stage == 3 else icebergs
		n = mini(n, max_icebergs - game.count_kind(iceberg_id))
		if n > 0:
			game.raise_icebergs(block, self, iceberg_id, n)


## Ένα μέλος του κύματος, με βάση τα βάρη.
func roll_wave() -> String:
	var total := 0.0
	for k in wave:
		total += float(wave[k])
	var r := randf() * total
	for k in wave:
		r -= float(wave[k])
		if r < 0.0:
			return k
	return wave.keys()[0]


func describe() -> String:
	return "Raises icebergs full of monsters. At half health it freezes in a blizzard and heals until its army falls. Its glare can freeze your shots."
