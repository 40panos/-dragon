class_name SiegeTowerAbility
extends EnemyAbility
## Ο πύργος πολιορκίας του Grukk — ο μεγάλος boss του Goblin Land.
##
## Ακίνητος. Πολεμάει με ό,τι ρίχνει ο καταπέλτης του (main.lob_*): τίποτα δεν
## εμφανίζεται από το πουθενά, όλα πετάνε σε καμπύλη από τον πύργο και
## προσγειώνονται. Τρεις φάσεις, ανάλογα με τη ζωή του:
##   1 «Οχυρώσεις»   οδοφράγματα κάθε 2 γύρους + ένα βαρέλι με goblin κάθε γύρο
##   2 «Τύμπανα»     δύο τυμπανιστές δίπλα του: όσο ζουν, ασπίδα στον πύργο
##   3 «Μπαρούτι»    βαρέλια μπαρούτι στο ταμπλό, και η πολιορκία επιταχύνει
## Πολιορκία (doom counter): κάθε `siege_every` γύρους ο καταπέλτης ρίχνει
## βράχο στον δράκο και όλο το ταμπλό κατεβαίνει μία σειρά.
## Αδύναμο σημείο: ο Grukk στην κορυφή — το main διπλασιάζει εκεί τη ζημιά.

@export var siege_every := 5
@export var siege_every_rage := 3
@export var phase2_at := 0.6
@export var phase3_at := 0.3
@export var barricade_every := 2
@export var barricades := 2
@export var kegs := 2
@export var drum_rethrow := 4
@export var minion_id := "goblin"
@export var drummer_id := "war_drummer"
@export var barricade_id := "barricade"
@export var keg_id := "powder_keg"
## Το αδύναμο σημείο, ως κλάσμα του σχεδίου (0..1): ο Grukk στην κορυφή.
@export var weak_uv := Rect2(0.24, 0.0, 0.42, 0.30)
## Καρέ του καταπέλτη που παίζουν σε κάθε ρίψη.
@export var throw_frames: Array[Texture2D] = []
@export var throw_fps := 10.0

var stage := 1
var doom := 5
var _rounds := 0
var _stage_rounds := 0
var _drum_wait := 0


func on_spawn(_block) -> void:
	doom = siege_every


func advance_rows(_block, _default_rows: int) -> int:
	return 0


func doom_left() -> int:
	return doom


## Η φάση αλλάζει τη στιγμή του χτυπήματος (ανακοίνωση, τράνταγμα), αλλά οι
## ρίψεις της περιμένουν το τέλος του γύρου: ένα οδόφραγμα που προσγειώνεται
## ανάμεσα σε μπάλες που πετάνε θα τις παγίδευε.
func on_damaged(block, game) -> void:
	var f: float = block.hp / maxf(block.max_hp, 1.0)
	var want := 1
	if f <= phase3_at:
		want = 3
	elif f <= phase2_at:
		want = 2
	if want > stage:
		stage = want
		_stage_rounds = 0
		_drum_wait = 0
		if stage == 3:
			doom = mini(doom, siege_every_rage)
		game.boss_stage(block, stage)


func on_round_end(block, game) -> void:
	_rounds += 1
	_stage_rounds += 1
	doom -= 1
	var threw := false
	match stage:
		1:
			if _rounds % barricade_every == 1:
				threw = game.lob_specials(block, barricade_id, barricades, 3, 6) > 0 or threw
			threw = game.lob_minions(block, minion_id, 1, 3, 6) > 0 or threw
		2:
			var drums: int = game.count_kind(drummer_id)
			if drums == 0:
				_drum_wait += 1
			if _stage_rounds == 1 or (drums == 0 and _drum_wait >= drum_rethrow):
				_drum_wait = 0
				threw = game.lob_drummers(block, drummer_id) > 0 or threw
			threw = game.lob_minions(block, minion_id, 1, 3, 6) > 0 or threw
		3:
			threw = game.lob_specials(block, keg_id, kegs, 2, 6) > 0 or threw
			if _rounds % 2 == 0:
				threw = game.lob_minions(block, minion_id, 1, 3, 6) > 0 or threw
	if doom <= 0:
		doom = siege_every_rage if stage == 3 else siege_every
		game.siege_shot(block)
		threw = true
	if threw and not throw_frames.is_empty():
		block.play_act(throw_frames, throw_fps)


func describe() -> String:
	return "Siege tower: throws goblins, barricades and powder kegs"
