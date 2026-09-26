extends SceneTree
## Γράφει το data/dragons/02_frost.tres με ResourceSaver, ποτέ ως κείμενο.
##
##   godot --headless --path . --script tools/write_frost.gd
##
## Ο δράκος του πάγου: σκούρο κεφάλι με στέμμα από κρυστάλλους αντί για
## κέρατα, και παγοκρύσταλλοι αντί για μπάλες φωτιάς. Το special του είναι το
## FREEZE· όσο κρατάει, βγαίνει η εξελιγμένη μορφή: στενό θωρακισμένο πρόσωπο
## με παγωμένες ρούνες, και κρύσταλλοι που ανοίγουν στα πλάγια σαν φτερά.
##
## Η εξελιγμένη έχει 3 καρέ ανά κατάσταση (ping-pong): στην ηρεμία οι ρούνες
## πάλλονται, στη σκόπευση ανάβουν σταδιακά, στη βολή σκάει παγωμένη ανάσα.
## Επειδή το σχέδιο από μόνο του είναι ήσυχο, παίρνει και glyph_aura: ρούνες
## που αιωρούνται γύρω του και σκάνε στη βολή (scripts/glyph_aura.gd).
## Η βασική μορφή είναι ακόμα ένα στατικό καρέ.

const RES_PATH := "res://data/dragons/02_frost.tres"
const FRAME_W := 64
const SCALE := 2
const EVO_W := 128
const EVO_SCALE := 2
const ACCENT := Color("8fe3ff")      # σπίθες και δαχτυλίδι φόρτισης: παγωμένο γαλάζιο
## Ο παγοκρύσταλλος είναι σχεδιασμένος με τη μύτη πάνω-δεξιά (-45°): το βλήμα
## γυρνάει ώστε η μύτη να κοιτάει την πορεία του, όπου κι αν πάει.
const SHARD_HEADING := -PI / 4.0


func _tex(name_: String, want_w: int = 0) -> Texture2D:
	var path := "res://art/%s.png" % name_
	if not ResourceLoader.exists(path):
		push_error("λείπει: " + path)
		quit(1)
	var t: Texture2D = load(path)
	if want_w > 0 and t.get_width() != want_w:
		push_error("%s: πλάτος %d, περίμενα %d" % [path, t.get_width(), want_w])
		quit(1)
	return t


## frost_awake_<κατάσταση>_1..3, όλα σε ίδιο καμβά.
func _frames(state: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	for i in range(1, 4):
		out.append(_tex("frost_awake_%s_%d" % [state, i], EVO_W))
	return out


func _make_evolved() -> DragonType:
	var a := DragonType.new()
	var idle := _frames("idle")
	var ready_ := _frames("ready")
	var fire := _frames("fire")
	a.id = "frost_evolved"
	a.display_name = "Frost Awakened"
	a.sprite = idle[0]
	a.sprite_idle = idle[0]
	a.sprite_ready = ready_[0]
	a.sprite_fire = fire[0]
	a.frames_idle = idle
	a.frames_ready = ready_
	a.frames_fire = fire
	a.fps_idle = 3.0
	a.fps_ready = 6.0
	a.fps_fire = 12.0
	a.glyph_aura = true
	a.draw_width = float(EVO_W * EVO_SCALE)   # 256 = 2x
	a.tint = Color(1, 1, 1, 1)
	a.accent = ACCENT
	a.ball_sprite = _tex("ice_shard")
	a.ball_aoe_sprite = _tex("ice_shard_aoe")
	a.ball_heading = SHARD_HEADING
	a.special = "freeze"
	a.special_cost = 18.0
	return a


func _initialize() -> void:
	var d := DragonType.new()
	var base := _tex("frost", FRAME_W)
	d.id = "frost"
	d.display_name = "Frost"
	d.sprite = base
	d.sprite_idle = base
	d.sprite_ready = base
	d.sprite_fire = base
	d.frames_idle = [base] as Array[Texture2D]
	d.frames_ready = [base] as Array[Texture2D]
	d.frames_fire = [base] as Array[Texture2D]
	d.ball_sprite = _tex("ice_shard")
	d.ball_aoe_sprite = _tex("ice_shard_aoe")
	d.ball_heading = SHARD_HEADING
	d.draw_width = float(FRAME_W * SCALE)   # 128 = 2x, ακέραιο πολλαπλάσιο
	# λευκό: ο παλιός frost ήταν μαύρος drake βαμμένος γαλάζιος, και το ίδιο
	# tint έβαφε τα νέα σχέδια πολύ πιο μπλε απ' ό,τι είναι
	d.tint = Color(1, 1, 1, 1)
	d.accent = ACCENT
	d.awakened = _make_evolved()
	# FREEZE: όλοι οι εχθροί παγώνουν για FREEZE_ROUNDS γύρους (βλ. main).
	# Ίδιο κόστος με το SWARM που είχε — η ισορροπία θέλει σάρωση.
	d.special = "freeze"
	d.special_cost = 18.0
	d.passive = "ball_every5"
	d.unlock_after_area = 1

	var err := ResourceSaver.save(d, RES_PATH)
	if err != OK:
		push_error("η αποθήκευση απέτυχε: %d" % err)
		quit(1)
	print("γράφτηκε %s — draw_width=%.1f, εξελιγμένη %.1f"
		% [RES_PATH, d.draw_width, d.awakened.draw_width])
	quit(0)
