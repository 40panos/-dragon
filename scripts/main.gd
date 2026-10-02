extends Node2D
## BBdragon — κύρια ροή παιχνιδιού.
##
## Το περιεχόμενο (εχθροί, δράκοι, περιοχές) ζει σε αρχεία .tres μέσα στο
## res://data/ και φορτώνεται δυναμικά· η προσθήκη νέων δεν αγγίζει κώδικα.

const COLS := 7          # δοκιμαστικά: λιγότερες στήλες = μεγαλύτερο κελί (πλάτος & ύψος μαζί)
const BALL_SPEED := 950.0
const FIRE_GAP := 0.08
const PF_W := 600.0           # σταθερό πλάτος πεδίου ώστε τα κελιά να μένουν τετράγωνα
const BORDER := 60.0
const PF_TOP := 190.0
const DEATH_GAP := 218.0
const UI_BAND := 142.0
const TRIPLE_TURNS := 3
## Πόσους γύρους κρατάει το FREEZE. Σε αυτούς οι εχθροί δεν κατεβαίνουν, οι
## ικανότητές τους σωπαίνουν και δεν μπαίνει νέα σειρά· ο δράκος μένει στην
## εξελιγμένη μορφή του ως το τέλος του τελευταίου.
const FREEZE_ROUNDS := 2
const FROZEN_TINT := Color(0.62, 0.86, 1.35)   # πάνω στον τόνο της περιοχής, στο self_modulate
const PTS_HIT := 5
const PTS_KILL := 25

const ADVANCE_TIME := 0.18    # διάρκεια του κατεβάσματος μιας σειράς
const DRAGON_DROP := 70.0     # πόσο κάτω από τη γραμμή του δαπέδου κάθεται ο δράκος
const AWAKE_DROP := 40.0      # η ξυπνημένη μορφή είναι διπλάσια, κάθεται ακόμα πιο χαμηλά
const INFERNO_BALL_SCALE := 1.75   # πόσο μεγαλώνει το σχέδιο της μπάλας στο INFERNO
const LAIR_SCALE := 2.0            # η φωλιά είναι σε art pixels, δείχνεται x2 (όπως ο δράκος)
const LAIR_FRAMES := 5             # καρέ ανά ζωντανεμένο στοιχείο (φωλιά και δάδες)
const LAIR_FPS := 7.0              # αργός ρυθμός: η λάβα σιγοκαίει, δεν τρεμοπαίζει

## Ποιο σετ φωλιάς παίζει. Το tools/build_lair.gd βγάζει δύο με κοινή
## γεωμετρία: "lair" (ηφαίστεια και λάβα) και "castle" (πυργίσκοι και
## πολεμίστρες). Αλλαγή εδώ και μόνο — τα δύο σετ είναι εναλλάξιμα.
const LAIR_SET := "castle"
const TORCH_FPS := 9.0

## Τα στολίδια του πλαισίου. Ίδια νούμερα με το DECOR του tools/build_frame.gd —
## οι δάδες και το λάβαρο ΔΕΝ ψήνονται πια μέσα στο frame_left.png, γιατί
## κινούνται· σχεδιάζονται από πάνω, στην ίδια ακριβώς θέση που είχαν.
const DECO_TILE := 64.0
const DECO_ROWS := 13.0
const DECO_TORCH_ROWS := [2, 8]
const DECO_BANNER_ROW := 5
const ROUNDS_PER_AREA := 20   # ο boss εμφανίζεται στον τελευταίο γύρο κάθε περιοχής
const SPLASH_RATIO := 0.33    # ζημιά σε λειτουργία AoE, στον στόχο και στους γείτονες

## ΔΟΚΙΜΕΣ: ξεκλειδώνει κάθε δράκο από τον πρώτο γύρο, ώστε να τους δοκιμάζεις
## χωρίς να φτάνεις στους boss. Γύρνα το σε false για κανονικό παιχνίδι — τα
## δεδομένα των δράκων (unlock_after_area) δεν πειράχτηκαν, μόνο παρακάμπτονται.
## Είναι μεταβλητή κι όχι σταθερά ώστε τα tests να τη γυρίζουν false και να
## ελέγχουν την πραγματική λογική ξεκλειδώματος.
var unlock_all_dragons := false

## ΔΟΚΙΜΕΣ: κουμπί TEST δίπλα στη μουσική, με μενού για άλμα σε πίστα/boss,
## έξτρα μπάλες κ.λπ. Γύρνα το σε false πριν το δώσεις σε άλλους.
var debug_menu := true
var debug_open := false

const BlockScene := preload("res://scenes/block.tscn")
const BallScene := preload("res://scenes/ball.tscn")
const OrbScene := preload("res://scenes/orb.tscn")

# ---------------------------------------------------------------- διάταξη
var W := 0.0
var H := 0.0
var cell := 0.0
var pf_left := 0.0
var pf_right := 0.0
var floor_y := 0.0
var ui_top := 0.0
var death_row := 11

# ---------------------------------------------------------------- κατάσταση
var phase := "aim"
var paused := false
var score := 0
var kills := 0
var level := 1
var ball_count := 1
var gained := 0
var launch_x := 0.0
var next_x := -1.0
var aim_dir := Vector2.UP
var aiming := false
## Το δάχτυλο κατέβηκε κάτω από το δάπεδο, πάνω στον δράκο: αν αφεθεί εκεί,
## η βολή ακυρώνεται. Χωρίς αυτό δεν υπήρχε τρόπος να μετανιώσεις ένα σημάδι.
var aim_cancel := false
var transition_t := -1.0       # χρόνος μέσα στο cinematic αλλαγής περιοχής· <0 = κανένα
var _trans_swapped := false
var visual_area_index := 0     # η περιοχή που δείχνουν σκηνικό και καιρός (βλ. visual_area)

# ---------------------------------------------------------------- μεγάλος boss
## Ο mini-boss (ο παλιός boss της περιοχής) έρχεται σε αυτόν τον γύρο, όταν η
## περιοχή έχει και μεγάλο boss (AreaDef.final_boss) για τον τελευταίο.
const MINIBOSS_ROUND := 10
const INTRO_CLEAR := 0.6       # ο χάρτης σβήνει
const INTRO_DROP := 0.55       # ο boss πέφτει από ψηλά
const INTRO_END := 1.9         # τέλος εισόδου, ξαναπαίζεις
var boss_intro_t := -1.0
var _intro_spawned := false
var war_drums := false         # χτυπάει τύμπανο: όλοι κατεβαίνουν μία σειρά παραπάνω
## Ό,τι πετάει ο boss: {from, to, tex, t, dur, h, spin, cb}. Όσο υπάρχουν, η
## φάση είναι "boss_act" και ο παίκτης περιμένει να προσγειωθούν.
var lobs: Array = []
var reserved := {}             # κελιά όπου πέφτει κάτι· κανείς άλλος δεν τα παίρνει
var fx_anims: Array = []       # εκρήξεις: {frames, pos, t, fps, scale}
var explosion_frames: Array[Texture2D] = []
var tex_spawn_barrel: Texture2D
var tex_boulder: Texture2D
var tex_cracks: Texture2D      # ρωγμές στο έδαφος όταν προσγειώνεται boss
var tex_emote: Texture2D       # συννεφάκι θυμού του mini-boss
var charge_frames: Array[Texture2D] = []   # βελάκια ταχύτητας στο διπλό βήμα
var summon_frames: Array[Texture2D] = []   # μαγικός κύκλος του καλέσματος
var to_fire := 0
var fire_timer := 0.0
var shot_time := 0.0
var live_balls := 0
var triple_turns := 0
var freeze_rounds := 0      # γύροι παγώματος που απομένουν (FREEZE)
var balls_fired := 0
var t := 0.0
var banner := ""
var banner_time := 0.0

var aoe_mode := false
var special_charge := 0.0
var inferno_active := false
## Η ΜΟΡΦΗ είναι ξεχωριστή από το bonus ζημιάς: κάθε δράκος με awakened μορφή
## μεταμορφώνεται όταν ρίχνει το special του, αλλά μόνο το INFERNO τριπλασιάζει
## τη ζημιά. Χωρίς τον διαχωρισμό, ο death θα έπαιρνε δώρο x3 μαζί με το SWARM.
var awake_active := false

# χρόνος που απομένει στη φλόγα που καλύπτει την εναλλαγή μικρού/μεγάλου
# δράκου. Παίζει ΜΙΑ φορά, και στις δύο κατευθύνσεις της αλλαγής.
const AWAKEN_TIME := 0.55
const AWAKEN_FRAMES := 8
var awaken_t := 0.0
var awaken_frames: Array[Texture2D] = []

# ---------------------------------------------------------------- ζωντάνια
var sparks: Array = []
var shake := 0.0
var recoil := 0.0          # κλωτσιά όταν φεύγει μπάλα, σβήνει γρήγορα
var tilt := 0.0            # στροφή κεφαλιού προς τη στόχευση, με εξομάλυνση
var fx: Node2D

var grid: BattleGrid
var boss = null

# ---------------------------------------------------------------- περιεχόμενο
var save := {}
var areas: Array = []
var dragons: Array = []
var enemy_by_id := {}
var area_index := 0
var dragon: DragonType
var run_dragons: Array[String] = []   # ξεκλείδωτοι δράκοι σε αυτό το run
var picker_open := false
var new_dragon := false               # ξεκλειδώθηκε δράκος που δεν έχει δει ακόμα ο παίκτης

var fireball_tex: Texture2D
var fireball_aoe_tex: Texture2D
var tex_frame_left: Texture2D
var tex_frame_right: Texture2D
var tex_frame_top: Texture2D
var lair_frames: Array[Texture2D] = []
var torch_frames: Array[Texture2D] = []
var tex_banner: Texture2D
var tex_hud_wall: Texture2D
var tex_hud_top: Texture2D
var tex_hud_panel: Texture2D
var font: Font
var bestiary       # το Book και οι ειδοποιήσεις νέων εχθρών (scripts/bestiary.gd)
var weather        # χιόνι κ.λπ. πάνω από το ταμπλό (scripts/weather.gd)
var glyph_aura     # ρούνες γύρω από δράκους με glyph_aura (scripts/glyph_aura.gd)
var music: MusicPlayer         # το soundtrack της περιοχής (AreaDef.music), scripts/music.gd
var volume_open := false       # ανοιχτό το πάνελ έντασης κάτω από τη νότα
var volume_drag := false       # σέρνεται η μπάρα έντασης


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = _load_font()
	var vs := get_viewport_rect().size
	W = vs.x
	H = vs.y
	cell = PF_W / float(COLS)
	pf_left = (W - PF_W) * 0.5
	pf_right = pf_left + PF_W
	floor_y = H - DEATH_GAP
	ui_top = H - UI_BAND
	death_row = int(floor((floor_y - PF_TOP) / cell))
	launch_x = W * 0.5

	fireball_tex = _load_tex("fireball")
	fireball_aoe_tex = _load_tex("fireball_aoe")
	for i in range(1, AWAKEN_FRAMES + 1):
		var af := _load_tex("awaken_%d" % i)
		if af:
			awaken_frames.append(af)
	tex_hud_panel = _load_tex("hud_panel")

	_load_content()
	save = SaveManager.load_data()
	_make_music()
	_apply_theme()
	_build_walls()
	_make_fx()
	_make_hud()
	_start()


## Τα εφέ μπαίνουν σε ψηλό z_index, πάνω από τους εχθρούς.
func _make_fx() -> void:
	# ο καιρός κάτω από τα εφέ: οι σπίθες των χτυπημάτων μένουν μπροστά
	weather = Node2D.new()
	weather.set_script(load("res://scripts/weather.gd"))
	weather.z_index = 40
	weather.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(weather)
	weather.m = self
	glyph_aura = Node2D.new()
	glyph_aura.set_script(load("res://scripts/glyph_aura.gd"))
	glyph_aura.z_index = 45
	glyph_aura.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(glyph_aura)
	glyph_aura.m = self
	fx = Node2D.new()
	fx.set_script(load("res://scripts/fx.gd"))
	fx.z_index = 50
	add_child(fx)
	fx.m = self


## Το HUD μπαίνει σε CanvasLayer ώστε να μένει πάνω από εχθρούς και μπάλες.
func _make_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var hud := Node2D.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(hud)
	hud.m = self
	# το Book από πάνω από το HUD, στο ίδιο layer
	bestiary = Node2D.new()
	bestiary.set_script(load("res://scripts/bestiary.gd"))
	bestiary.process_mode = Node.PROCESS_MODE_ALWAYS
	bestiary.m = self
	layer.add_child(bestiary)
	# το μαύρο του cinematic, πάνω από όλα (scripts/fade.gd)
	var top := CanvasLayer.new()
	top.layer = 20
	add_child(top)
	var fade := Node2D.new()
	fade.set_script(load("res://scripts/fade.gd"))
	fade.process_mode = Node.PROCESS_MODE_ALWAYS
	fade.visible = false
	top.add_child(fade)
	fade.m = self


# ---------------------------------------------------------------- περιεχόμενο

## Φορτώνει το σκηνικό της τρέχουσας περιοχής (βλ. AreaDef.theme): για κάθε
## στοιχείο προτιμά το <όνομα>_<theme>.png και, αν λείπει, πέφτει στο βασικό.
## Καλείται στην αρχή του run και όποτε αλλάζει περιοχή — όχι σε κάθε καρέ.
func _apply_theme() -> void:
	visual_area_index = area_index
	var area := current_area()
	var theme: String = area.theme if area else ""
	var pick := func(name_: String) -> Texture2D:
		if theme != "":
			var t := _load_tex("%s_%s" % [name_, theme])
			if t:
				return t
		return _load_tex(name_)
	tex_frame_left = pick.call("frame_left")
	tex_frame_right = pick.call("frame_right")
	tex_frame_top = pick.call("frame_top")
	lair_frames.clear()
	torch_frames.clear()
	for i in range(1, LAIR_FRAMES + 1):
		var lf: Texture2D = pick.call("%s_%d" % [LAIR_SET, i])
		if lf:
			lair_frames.append(lf)
		var tf: Texture2D = pick.call("deco_torch_%d" % i)
		if tf:
			torch_frames.append(tf)
	tex_banner = pick.call("deco_banner")
	tex_hud_wall = pick.call("hud_wall")
	tex_hud_top = pick.call("hud_top")
	_play_area_music()


# ---------------------------------------------------------------- μουσική

## Ο player παίζει και στην παύση: η σίγαση γίνεται μόνο από το κουμπί mute.
func _make_music() -> void:
	music = MusicPlayer.new()
	add_child(music)


## Βάζει το κομμάτι της τρέχουσας περιοχής. Αν είναι ήδη αυτό που παίζει, δεν
## το ξεκινάει από την αρχή — αλλιώς κάθε restart θα έκοβε τη μουσική.
func _play_area_music() -> void:
	if music == null:
		return
	var area := current_area()
	_apply_music_volume()
	music.play_stream(area.music if area else null)


func music_muted() -> bool:
	return bool(save.get("music_muted", false))


## Ένταση μουσικής, 0..1.
func music_volume() -> float:
	return clampf(float(save.get("music_volume", 0.8)), 0.0, 1.0)


## Σιωπηλή: είτε σε mute είτε με την ένταση στο μηδέν.
func music_silent() -> bool:
	return music_muted() or music_volume() <= 0.0


func _apply_music_volume() -> void:
	if music == null:
		return
	music.set_volume(music_volume())
	music.set_paused(music_silent())


func _toggle_music() -> void:
	save["music_muted"] = not music_muted()
	SaveManager.save_data(save)
	_apply_music_volume()


## Η ένταση από τη θέση x πάνω στη μπάρα. Δεν αποθηκεύει: αυτό γίνεται όταν
## σηκωθεί το δάχτυλο, όχι σε κάθε κίνηση του συρσίματος.
func _set_volume_at(x: float) -> void:
	var bar := volume_bar_rect()
	save["music_volume"] = clampf((x - bar.position.x) / bar.size.x, 0.0, 1.0)
	# όποιος σέρνει την ένταση θέλει να ακούσει μουσική
	if music_muted() and music_volume() > 0.0:
		save["music_muted"] = false
	_apply_music_volume()


## Πάτημα όσο είναι ανοιχτό το πάνελ έντασης. Η νότα και οτιδήποτε έξω από το
## πάνελ το κλείνουν.
func _volume_press(p: Vector2) -> void:
	if volume_mute_rect().has_point(p):
		_toggle_music()
	elif volume_bar_rect().grow(18.0).has_point(p):
		volume_drag = true
		_set_volume_at(p.x)
	elif not volume_panel_rect().has_point(p):
		volume_open = false


func _load_tex(name_: String) -> Texture2D:
	var p := "res://art/%s.png" % name_
	return load(p) if ResourceLoader.exists(p) else null


## Καρέ <όνομα>_1..N, όσα υπάρχουν.
func _load_seq(name_: String) -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var i := 1
	while ResourceLoader.exists("res://art/%s_%d.png" % [name_, i]):
		out.append(load("res://art/%s_%d.png" % [name_, i]))
		i += 1
	return out


## Η γραμματοσειρά του παιχνιδιού. Είναι pixel font, οπότε το antialiasing
## και το subpixel positioning πρέπει να φύγουν — αλλιώς τα γράμματα
## θολώνουν και χάνουν το πλέγμα τους.
func _load_font() -> Font:
	var p := "res://art/ui_font.ttf"
	if not ResourceLoader.exists(p):
		return ThemeDB.fallback_font
	var f := load(p) as FontFile
	if f == null:
		return ThemeDB.fallback_font
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	f.hinting = TextServer.HINTING_NONE
	return f


func _load_content() -> void:
	areas = _load_dir("res://data/areas")
	dragons = _load_dir("res://data/dragons")
	for a in areas:
		for e in a.enemies:
			enemy_by_id[e.id] = e
		for e in a.minions:
			enemy_by_id[e.id] = e
		if a.boss:
			enemy_by_id[a.boss.id] = a.boss
		if a.final_boss:
			enemy_by_id[a.final_boss.id] = a.final_boss
		for e in a.specials:
			enemy_by_id[e.id] = e
	explosion_frames.clear()
	var ei := 1
	while ResourceLoader.exists("res://art/explosion_%d.png" % ei):
		explosion_frames.append(load("res://art/explosion_%d.png" % ei))
		ei += 1
	tex_spawn_barrel = _load_tex("spawn_barrel")
	tex_boulder = _load_tex("boulder")
	tex_cracks = _load_tex("fx_cracks")
	tex_emote = _load_tex("fx_emote_angry")
	charge_frames = _load_seq("fx_charge")
	summon_frames = _load_seq("fx_summon")


func _load_dir(dir_path: String) -> Array:
	var names := []
	var d := DirAccess.open(dir_path)
	if d == null:
		return []
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir():
			var n := f.trim_suffix(".remap")
			if n.ends_with(".tres") and not names.has(n):
				names.append(n)
		f = d.get_next()
	d.list_dir_end()
	names.sort()
	var out := []
	for n in names:
		var r = load(dir_path + "/" + n)
		if r:
			out.append(r)
	return out


func current_area() -> AreaDef:
	if areas.is_empty():
		return null
	return areas[clampi(area_index, 0, areas.size() - 1)]


## Κάθε run ξεκινάει μόνο με τους δράκους που δεν θέλουν ξεκλείδωμα· οι υπόλοιποι
## ανοίγουν νικώντας τον boss της περιοχής τους και χάνονται στο game over.
func _reset_dragons() -> void:
	run_dragons.clear()
	for d in dragons:
		if unlock_all_dragons or d.unlock_after_area <= 0:
			run_dragons.append(d.id)
	if run_dragons.is_empty() and not dragons.is_empty():
		run_dragons.append(dragons[0].id)
	dragon = dragon_by_id(run_dragons[0]) if not run_dragons.is_empty() else null
	picker_open = false
	new_dragon = false


func dragon_by_id(id: String) -> DragonType:
	for d in dragons:
		if d.id == id:
			return d
	return null


func is_dragon_unlocked(d: DragonType) -> bool:
	return d != null and run_dragons.has(d.id)


## Το βλήμα που ρίχνει ο τρέχων δράκος. Ο ember ρίχνει φωτιά, ο death δρεπάνια.
## Το ίδιο εικονίδιο δείχνει και το κουμπί του HUD, ώστε να μη λέει άλλο το
## κουμπί κι άλλο να φεύγει από το στόμα. Δράκος χωρίς δικό του βλήμα πέφτει
## στα καθολικά, οπότε δεν χρειάστηκε να αλλάξουν οι παλιοί.
## Το χρώμα που εκπέμπει ο τρέχων δράκος, σε ένταση `f`. Οι σπίθες και η
## λάμψη του στόματος ήταν σταθερά πορτοκαλί, που πάνω στον πράσινο δράκο του
## θανάτου έδειχνε σαν να πετάει φωτιά ενώ πετάει δρεπάνια.
func _accent(f: float) -> Color:
	# ο ΕΝΕΡΓΟΣ δράκος, όχι ο κύριος: η εξελιγμένη μορφή έχει δικό της χρώμα,
	# οπότε οι σπίθες της αλλάζουν μαζί της όταν βγαίνει
	var dg := active_dragon()
	var c: Color = dg.accent if dg else Color("ff9e2c")
	return c.lerp(Color.WHITE, 1.0 - clampf(f, 0.0, 1.0))


func ball_tex(aoe: bool) -> Texture2D:
	# ο ΕΝΕΡΓΟΣ δράκος: η εξελιγμένη μορφή ρίχνει δικά της βλήματα, οπότε όσο
	# κρατάει η μεταμόρφωση φεύγουν τα μαύρα δρεπάνια αντί για τα οστέινα
	var dg := active_dragon()
	if dg:
		if aoe and dg.ball_aoe_sprite:
			return dg.ball_aoe_sprite
		if not aoe and dg.ball_sprite:
			return dg.ball_sprite
	return fireball_aoe_tex if (aoe and fireball_aoe_tex) else fireball_tex


## Αλλαγή δράκου επιτρέπεται μόνο πριν από τη βολή.
func can_switch_dragon() -> bool:
	return phase == "aim" and not aiming and not frozen()


func select_dragon(id: String) -> bool:
	var d := dragon_by_id(id)
	if not can_switch_dragon() or not is_dragon_unlocked(d):
		return false
	dragon = d
	# οι εχθροί που στέκονται ήδη στο ταμπλό πρέπει να πάρουν τη λάμψη του νέου
	# δράκου — αλλιώς θα συνέχιζαν να ανάβουν με τη φλόγα του προηγούμενου
	_refresh_glow()
	return true


## Η λάμψη χτυπήματος που αφήνει ο δράκος ΑΥΤΗ τη στιγμή. Ακολουθεί την ενεργή
## μορφή, όπως τα βλήματα και τα particles: η ξεσκέπαστη μορφή του death αφήνει
## σκοτάδι αντί για πράσινη φλόγα. Μορφή χωρίς δική της πέφτει στου βασικού.
func glow_now() -> Array[Texture2D]:
	var dg := active_dragon()
	if dg and not dg.glow_frames.is_empty():
		return dg.glow_frames
	if dragon:
		return dragon.glow_frames
	return []


## Περνάει τη λάμψη της τρέχουσας μορφής σε όσους εχθρούς στέκονται ήδη στο
## ταμπλό. Καλείται όταν αλλάζει δράκος ΚΑΙ όταν αλλάζει μορφή — αλλιώς όσοι
## ζούσαν πριν τη μεταμόρφωση θα συνέχιζαν να ανάβουν με την παλιά.
func _refresh_glow() -> void:
	var g := glow_now()
	var c := _accent(1.0)
	for b in get_tree().get_nodes_in_group("block"):
		if is_instance_valid(b):
			b.glow_frames = g
			b.burst_color = c


# ---------------------------------------------------------------- στήσιμο

func _build_walls() -> void:
	_wall(Vector2(pf_left - 100.0, H * 0.5), Vector2(200.0, H * 3.0))
	_wall(Vector2(pf_right + 100.0, H * 0.5), Vector2(200.0, H * 3.0))
	_wall(Vector2(W * 0.5, PF_TOP - 106.0), Vector2(W * 3.0, 200.0))


func _wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	body.add_child(cs)
	add_child(body)


func _start() -> void:
	Engine.time_scale = 1.0
	paused = false
	get_tree().paused = false
	for g in ["block", "orb", "ball"]:
		for n in get_tree().get_nodes_in_group(g):
			n.queue_free()

	grid = BattleGrid.new(COLS)
	boss = null
	_reset_dragons()

	# κάθε run ξεκινάει από την αρχή
	area_index = 0
	visual_area_index = 0
	transition_t = -1.0
	boss_intro_t = -1.0
	lobs.clear()
	reserved.clear()
	fx_anims.clear()
	_soft.clear()
	_reset_wendigo_fx()
	level = 1
	_apply_theme()

	score = 0
	kills = 0
	ball_count = 1
	gained = 0
	live_balls = 0
	to_fire = 0
	next_x = -1.0
	triple_turns = 0
	freeze_rounds = 0
	balls_fired = 0
	special_charge = 0.0
	inferno_active = false
	awake_active = false
	aoe_mode = false
	launch_x = W * 0.5
	phase = "aim"
	_announce("%s - ROUND %d" % [current_area().display_name if current_area() else "", level])
	_add_row()


func _announce(text: String) -> void:
	banner = text
	banner_time = 2.6


# ---------------------------------------------------------------- ζωντάνια

const MAX_SPARKS := 240


func add_sparks(pos: Vector2, count: int, col: Color, speed: float, size := 4.0) -> void:
	if sparks.size() > MAX_SPARKS:
		return
	for i in count:
		var a := randf() * TAU
		var life := randf_range(0.16, 0.40)
		sparks.append({
			"p": pos,
			"v": Vector2(cos(a), sin(a)) * randf_range(speed * 0.35, speed),
			"life": life,
			"max": life,
			"c": col,
			"r": randf_range(size * 0.5, size),
		})


func add_shake(amount: float) -> void:
	shake = minf(shake + amount, 9.0)


## Ποιος δράκος σχεδιάζεται τώρα: όσο καίει το INFERNO παίρνει τη θέση του η
## ξυπνημένη μορφή, αν ο τύπος έχει μία. Όλα τα υπόλοιπα (καρέ, ρυθμοί, πλάτος
## σχεδίασης) βγαίνουν από αυτήν, οπότε δεν χρειάζεται δεύτερο μονοπάτι κώδικα.
func active_dragon() -> DragonType:
	if dragon and awake_active and dragon.awakened is DragonType:
		return dragon.awakened
	return dragon


## Κρατάει κλειδωμένα τα χειριστήρια όσο υπάρχουν μπάλες στο ταμπλό: ούτε
## αλλαγή βλήματος ούτε INFERNO μέσα στη ριπή.
func controls_locked() -> bool:
	return phase != "aim"


## Πού πατάει ο δράκος. Κάθεται μέσα στη ζώνη κάτω από την τελευταία σειρά
## πλακιδίων, όχι πάνω στη γραμμή του δαπέδου, ώστε να μην κρύβει το πεδίο.
func dragon_base() -> Vector2:
	var drop := DRAGON_DROP
	if dragon and active_dragon() != dragon:
		drop += AWAKE_DROP
	return Vector2(launch_x, floor_y + drop)


## Θέση στόματος, ακολουθώντας τη στροφή του κεφαλιού — από εκεί βγαίνει η φωτιά.
func mouth_pos() -> Vector2:
	var h := 60.0
	var dg := active_dragon()
	if dg:
		var dt := dg.frame_for(dragon_phase(), aiming, t)
		if dt:
			h = dg.draw_width * float(dt.get_height()) / float(dt.get_width())
	return dragon_base() + Vector2(0, -h * 0.45).rotated(tilt)


func _update_life(delta: float) -> void:
	recoil = maxf(0.0, recoil - delta * 5.5)
	awaken_t = maxf(0.0, awaken_t - delta)

	# το κεφάλι στρέφεται προς εκεί που σημαδεύεις
	var want := 0.0
	if phase == "aim" and aiming:
		want = clampf(aim_dir.x, -1.0, 1.0) * 0.30
	elif phase == "shoot":
		want = clampf(aim_dir.x, -1.0, 1.0) * 0.20
	tilt = lerpf(tilt, want, clampf(delta * 9.0, 0.0, 1.0))

	var drag := 1.0 - minf(delta * 5.0, 0.9)
	var i := sparks.size() - 1
	while i >= 0:
		var s: Dictionary = sparks[i]
		s["life"] -= delta
		if s["life"] <= 0.0:
			sparks.remove_at(i)
		else:
			s["p"] += s["v"] * delta
			s["v"] *= drag
			s["v"].y += 260.0 * delta
		i -= 1

	if shake > 0.01:
		shake = maxf(0.0, shake - delta * 26.0)
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	elif position != Vector2.ZERO:
		position = Vector2.ZERO


# ---------------------------------------------------------------- πλέγμα

func block_center(col: int, row: int, cw: int, ch: int) -> Vector2:
	return Vector2(
		pf_left + (col + cw * 0.5) * cell,
		PF_TOP + (row + ch * 0.5) * cell)


func _add_row() -> void:
	var area := current_area()
	if area and area.final_boss:
		# mini-boss στη μέση της περιοχής, μεγάλος boss στο τέλος
		if area_round() >= ROUNDS_PER_AREA and boss == null:
			_begin_boss_intro()
			return
		if area_round() == MINIBOSS_ROUND and boss == null:
			_spawn_boss()
			return
		# όσο παλεύεις τον μεγάλο boss δεν πέφτουν σειρές — μόνο ό,τι ρίχνει
		if boss_alive() and boss.is_final:
			return
	elif level % ROUNDS_PER_AREA == 0 and boss == null:
		_spawn_boss()
		return

	var free_cols: Array = []
	var placed := 0
	for c in COLS:
		if not grid.is_free(c, 0):
			continue
		if randf() < 0.62:
			_spawn_enemy(c, 0, _roll_enemy(), level)
			placed += 1
		else:
			free_cols.append(c)
	if placed == 0 and not free_cols.is_empty():
		var idx := randi() % free_cols.size()
		_spawn_enemy(free_cols[idx], 0, _roll_enemy(), level)
		free_cols.remove_at(idx)
	if not free_cols.is_empty() and randf() < 0.85:
		var k := "ball"
		if randf() < 0.12:
			k = "triple"
		_spawn_orb(free_cols[randi() % free_cols.size()], k)


func _roll_enemy() -> EnemyType:
	var area := current_area()
	if area == null:
		return null
	return area.pick(randf(), area_round())


## Ο γύρος μέσα στην τρέχουσα περιοχή, από 1 έως ROUNDS_PER_AREA.
func area_round() -> int:
	return level - area_index * ROUNDS_PER_AREA


func _spawn_enemy(col: int, row: int, type: EnemyType, hp_level: float) -> void:
	if type == null:
		return
	var hp := maxf(1.0, round(hp_level * type.hp_mult))
	_make_block(col, row, type, hp, 1, 1, false)


func _spawn_boss() -> void:
	var area := current_area()
	if area == null or area.boss == null:
		return
	var cw: int = area.boss_cols
	var ch: int = area.boss_rows
	var col := int((COLS - cw) * 0.5)
	if not grid.fits(col, 0, cw, ch):
		for b in grid.blocks():
			if b.row < ch:
				grid.erase(b)
				add_sparks(b.position, 6, Color("d9d2c0"), 160.0, 4.0)
				b.vanish()
	var hp := maxf(10.0, round(level * area.boss_hp_mult))
	boss = _make_block(col, 0, area.boss, hp, cw, ch, true)
	# είσοδος: πέφτει από τον ουρανό, και όσο πέφτει ο παίκτης περιμένει
	var target: Vector2 = boss.position
	boss.position.y = target.y - H * 0.5
	var tw := create_tween()
	tw.tween_property(boss, "position:y", target.y, MINI_DROP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_mini_landed.bind(boss))
	after(MINI_DROP + 0.25, func(): pass)


const MINI_DROP := 0.45
const CRACKS_LIFE := 2.6


## Ο mini-boss προσγειώθηκε: ρωγμές στο έδαφος κάτω του (διακριτικές, σβήνουν
## σε λίγα δευτερόλεπτα), σκόνη, μικρό τράνταγμα, και ένα emote — ο βρυχηθμός
## του και ένα συννεφάκι θυμού πάνω από το κεφάλι.
func _mini_landed(b) -> void:
	if b == null or not is_instance_valid(b):
		return
	add_shake(5.0)
	_ground_impact(b)
	var area := current_area()
	# το emote έρχεται λίγο μετά την πτώση, όταν έχει κάτσει η σκόνη· η
	# ανακοίνωση περιμένει κι αυτή, γιατί η πινακίδα της πέφτει ακριβώς πάνω
	# στο κεφάλι του boss και θα το έκρυβε
	later(EMOTE_DELAY, _mini_emote.bind(b))
	_announce_later("MINI-BOSS - %s" % (area.boss.display_name.to_upper() if area and area.boss else ""),
		EMOTE_DELAY + EMOTE_TIME)


func _mini_emote(b) -> void:
	if b == null or not is_instance_valid(b) or b.is_vanishing():
		return
	var act := _act_frames(b.ability)
	if not act.is_empty():
		b.play_act(act, 10.0)
	add_shake(2.0)
	if tex_emote:
		# μέσα στο κουτί του, πάνω δεξιά από το κεφάλι: ο mini-boss στέκεται στην
		# πρώτη σειρά, και πιο ψηλά το συννεφάκι έβγαινε πάνω στο παραπέτο
		play_fx([tex_emote], b.position + Vector2(b.box.x * 0.30, -b.box.y * 0.22), 2.0, 1.0,
			EMOTE_TIME, 0.35, false, true)


const EMOTE_DELAY := 1.0
const EMOTE_TIME := 1.6
var _soft: Array = []          # [χρόνος, callable]: καθυστερήσεις που ΔΕΝ σταματάνε το παιχνίδι


## Κάτι που γίνεται σε λίγο, χωρίς να περιμένει ο παίκτης (σε αντίθεση με το after).
func later(delay: float, cb: Callable) -> void:
	_soft.append([delay, cb])


func _update_soft(delta: float) -> void:
	var i := _soft.size() - 1
	while i >= 0:
		_soft[i][0] -= delta
		if _soft[i][0] <= 0.0:
			var cb: Callable = _soft[i][1]
			_soft.remove_at(i)
			cb.call()
		i -= 1


## Ανακοίνωση που βγαίνει σε λίγο, χωρίς να σταματάει το παιχνίδι.
func _announce_later(text: String, delay: float) -> void:
	later(delay, _announce.bind(text))


## Ρωγμές και σκόνη κάτω από ό,τι προσγειώθηκε βαριά (mini-boss, μεγάλος boss).
func _ground_impact(b) -> void:
	var base_y: float = b.position.y + b.box.y * 0.5
	if tex_cracks:
		# Ρωγμές ΜΟΝΟ στα κελιά όπου πάτησε, πίσω του: μία ανά κελί, κομμένη
		# στα όριά του, ώστε να μη βγαίνει έξω από το αποτύπωμά του. Κάθε κελί
		# δείχνει άλλο κομμάτι της ρωγμής (μετατοπισμένο κέντρο), και το χώμα
		# σκουραίνει λίγο — φαίνονται εκεί όπου το σώμα του αφήνει κενό.
		for cx in b.cw:
			for cy in b.ch:
				var cr := Rect2(pf_left + (b.col + cx) * cell, PF_TOP + (b.row + cy) * cell, cell, cell)
				var jitter := Vector2(randf_range(-22.0, 22.0), randf_range(-14.0, 14.0))
				_floor_cracks(cr, cr.get_center() + jitter, CRACKS_LIFE, 1.0)
	for i in 12:
		var x: float = b.position.x + randf_range(-b.box.x * 0.55, b.box.x * 0.55)
		add_sparks(Vector2(x, base_y), 2, Color("a8906a"), 170.0, 6.0)


## Ρωγμή στο πάτωμα, κομμένη στο κελί `cr`. Στο χιόνι (θέμα "frost") είναι
## πάγος: η ίδια ρωγμή ξαναχρωματισμένη σε μπλε, με αχνό γαλάζιο από κάτω
## αντί για σκούρο χώμα — το καφέ έμοιαζε με λάσπη.
func _floor_cracks(cr: Rect2, at: Vector2, life: float, fade: float) -> void:
	if tex_cracks == null:
		return
	var a := visual_area()
	var icy: bool = a != null and a.theme == "frost"
	play_fx([_ice_cracks() if icy else tex_cracks], at, 2.0, 1.0, life, fade, true)
	fx_anims[-1]["clip"] = cr
	if icy:
		fx_anims[-1]["under"] = Color(0.55, 0.8, 1.0, 0.18)


var _ice_cracks_tex: Texture2D


## Η ρωγμή του χώματος σε πάγο: η φωτεινότητα κάθε pixel κρατιέται και
## ξαναβάφεται από βαθύ μπλε (σκοτάδι της ρωγμής) ως σχεδόν λευκό (άκρες).
func _ice_cracks() -> Texture2D:
	if _ice_cracks_tex:
		return _ice_cracks_tex
	var im := tex_cracks.get_image()
	im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	var deep := Color("1d4f8f")
	var light := Color("d8f0ff")
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var l := clampf(c.get_luminance() * 2.2, 0.0, 1.0)
			var nc := deep.lerp(light, l)
			nc.a = c.a
			im.set_pixel(x, y, nc)
	_ice_cracks_tex = ImageTexture.create_from_image(im)
	return _ice_cracks_tex


## Τα καρέ «δράσης» μιας ικανότητας (π.χ. ο βρυχηθμός του βασιλιά, που είναι
## τα act_frames του καλέσματός του), ψάχνοντας και μέσα σε σύνθετες.
func _act_frames(ab) -> Array[Texture2D]:
	if ab == null:
		return []
	if "act_frames" in ab and not ab.act_frames.is_empty():
		return ab.act_frames
	if ab is CompositeAbility:
		for p in ab.parts:
			var f := _act_frames(p)
			if not f.is_empty():
				return f
	return []


func _make_block(col: int, row: int, type: EnemyType, hp: float, cw: int, ch: int, as_boss: bool):
	var b := BlockScene.instantiate()
	add_child(b)
	b.add_to_group("block")
	b.col = col
	b.row = row
	b.is_boss = as_boss
	b.invulnerable = type.invulnerable
	b.show_hp = type.show_hp
	var box := Vector2(cw * cell - 6.0, ch * cell - 6.0)
	b.setup(hp, box, type.id, type.sprite, type.ability, cw, ch,
		type.frames_idle, type.fps_idle, type.frames_hit, type.fps_hit,
		type.sprite_scale)
	b.glow_frames = glow_now()
	b.burst_color = _accent(1.0)
	b.position = block_center(col, row, cw, ch)
	var area := current_area()
	if area:
		b.modulate = area.tint
	grid.place(b)
	b.damaged.connect(_on_block_damaged.bind(b))
	if freeze_rounds > 0:
		b.self_modulate = FROZEN_TINT     # ό,τι γεννιέται μέσα στο πάγωμα, παγωμένο
		b.set_frozen(true)
	if bestiary and not type.hidden_in_book:
		bestiary.saw(type)
	return b


## Καλείται από το ShatterAbility (deferred): γεννάει έως `count` minions στο
## κελί όπου ήταν ο εχθρός και στα διπλανά του. Παίρνει τιμές και όχι το ίδιο
## το block, γιατί ως την ώρα της κλήσης εκείνο έχει ήδη ελευθερωθεί.
func spawn_near(col: int, row: int, cw: int, ch: int, source_hp: float,
		minion_id: String, count: int, hp_ratio: float) -> void:
	var type: EnemyType = enemy_by_id.get(minion_id)
	if type == null:
		return
	var spots: Array[Vector2i] = []
	for c in cw:
		for r in ch:
			spots.append(Vector2i(col + c, row + r))
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		spots.append(Vector2i(col, row) + d)
	var hp := maxf(1.0, round(source_hp * hp_ratio))
	var made := 0
	for s in spots:
		if made >= count:
			break
		if s.x < 0 or s.x >= COLS or s.y < 0 or s.y >= death_row:
			continue
		if not grid.is_free(s.x, s.y):
			continue
		_make_block(s.x, s.y, type, hp, 1, 1, false)
		made += 1


const ABILITY_GAP := 0.06     # ανάσα ανάμεσα στα βήματα της σειράς ικανοτήτων
const CHARGE_TIME := 0.24      # το dash του καβαλάρη
var _post_charges: Array = []  # [block, έξτρα σειρές] για μετά το γενικό κατέβασμα
var _post_summons: Array = []  # καλέσματα για μετά τα charges
var _collecting := false       # μέσα στο τέλος γύρου: οι ικανότητες μαζεύονται σε ουρά


## Τα έξτρα βήματα, αφού έχουν σταθεί όλοι: βελάκια ταχύτητας με άνεμο στο
## κελί απ' όπου φεύγει, γραμμές ταχύτητας πίσω του, σκόνη και μικρό
## τράνταγμα εκεί που πατάει. Γίνονται όλα μαζί, ώστε να μη σέρνεται ο ρυθμός.
func _run_charges(charges: Array) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	var any := false
	# από κάτω προς τα πάνω, ώστε όποιος είναι μπροστά να ελευθερώνει χώρο
	charges.sort_custom(func(a, c): return a[0].row > c[0].row)
	for ch in charges:
		var b = ch[0]
		if not is_instance_valid(b) or b.is_vanishing() or not grid.blocks().has(b):
			continue
		var step: int = ch[1]
		while step > 0 and not grid.fits(b.col, b.row + step, b.cw, b.ch, b):
			step -= 1
		if step <= 0:
			continue
		any = true
		# από το πλέγμα, όχι από τον κόμβο: το γενικό κατέβασμα μπορεί να μην
		# έχει τελειώσει ακόμα στην οθόνη
		var from := block_center(b.col, b.row, b.cw, b.ch)
		if not charge_frames.is_empty():
			play_fx(charge_frames, from, 2.0, 18.0, -1.0, 0.12)
		for k in 6:
			add_sparks(from + Vector2(randf_range(-cell * 0.3, cell * 0.3), 0), 1,
				Color(1, 1, 1, 0.9), 90.0, 4.0)
		grid.move_to(b, b.col, b.row + step)
		b.begin_move(CHARGE_TIME)
		var to := block_center(b.col, b.row, b.cw, b.ch)
		tween.tween_property(b, "position:y", to.y, CHARGE_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_callback(_charge_landed.bind(b)).set_delay(CHARGE_TIME * 0.8)
	if not any:
		tween.kill()
		return
	for b in grid.blocks():
		if b.row + b.ch > death_row:
			_game_over()
			return


func _charge_landed(b) -> void:
	if not is_instance_valid(b):
		return
	add_sparks(b.position + Vector2(0, cell * 0.38), 8, Color("c9b28a"), 140.0, 5.0)
	add_shake(1.5)


const SUMMON_CAST := 0.28      # ο καλεστής «φορτίζει»
const SUMMON_BOLT := 0.26      # το μαγικό βλήμα ως το κελί
const SUMMON_RISE := 0.32      # ο κύκλος ανοίγει, το minion υψώνεται
const SUMMON_COL := Color("c77dff")


## Καλείται από το SummonerAbility, αλλά δεν γεννάει αμέσως: μπαίνει στην
## ουρά και παίζει αφού σταθούν όλοι (_run_summons), ώστε το μάτι να το πιάνει.
func summon_minion(source, minion_id: String, hp_ratio: float, min_row: int,
		max_row: int, keep_clear: int = 0) -> void:
	var s := [source, minion_id, hp_ratio, min_row, max_row, keep_clear]
	if _collecting:
		_post_summons.append(s)
	else:
		_run_summons([s])        # εκτός τέλους γύρου (π.χ. tests): ξεκινάει αμέσως


## Τα καλέσματα, όλα μαζί: ο καλεστής φουσκώνει μέσα σε μωβ αύρα που
## πάλλεται, με σπίθες που ανεβαίνουν· μετά ένα μαγικό βλήμα πετάει από αυτόν
## στο κελί-στόχο, εκεί ανοίγει ο κύκλος, και το minion υψώνεται από μέσα του.
func _run_summons(summons: Array) -> void:
	var cast_done := {}
	for s in summons:
		var src = s[0]
		if not is_instance_valid(src) or src.is_vanishing():
			continue
		var roar: bool = src.is_boss
		if not cast_done.has(src):
			cast_done[src] = true
			var act := _act_frames(src.ability)
			if roar:
				# ο boss δεν κάνει μαγικά: βρυχάται, και το κάλεσμα είναι πολεμικό
				src.cast_pulse(WARCRY_TIME, "roar")
				if not act.is_empty():
					src.play_act(act, float(act.size()) / WARCRY_TIME)
				add_shake(3.5)
			else:
				src.cast_pulse(SUMMON_CAST + SUMMON_BOLT)
				if not act.is_empty():
					src.play_act(act, float(act.size()) / (SUMMON_CAST + SUMMON_BOLT))
				for k in 10:
					var off := Vector2(randf_range(-src.box.x, src.box.x) * 0.45, src.box.y * 0.4)
					add_sparks(src.position + off, 1, SUMMON_COL, 120.0, 5.0)
		_summon_now(src, s[1], s[2], s[3], s[4], s[5], roar)


func _summon_now(source, minion_id: String, hp_ratio: float, min_row: int,
		max_row: int, keep_clear: int = 0, warcry := false) -> void:
	var type: EnemyType = enemy_by_id.get(minion_id)
	if type == null:
		return
	# Δύο ανεξάρτητα κάτω όρια, και ισχύουν ΚΑΙ ΤΑ ΔΥΟ: το max_row του τύπου,
	# και η ζώνη ασφαλείας αμέσως πριν τον δράκο.
	var last_row := mini(max_row, death_row - 1 - maxi(keep_clear, 0))
	if last_row < min_row:
		return
	var cells := []
	for c in grid.free_cells(min_row, last_row):
		if not reserved.has(c):
			cells.append(c)
	if cells.is_empty():
		return
	var spot: Vector2i = cells[randi() % cells.size()]
	# όσο πιο μπροστά γεννιέται, τόσο λιγότερη ζωή
	var depth := clampf(float(spot.y) / float(maxi(death_row, 1)), 0.0, 1.0)
	var hp := maxf(1.0, round(source.max_hp * hp_ratio * (1.0 - depth * 0.5)))
	reserved[spot] = true
	var at := block_center(spot.x, spot.y, 1, 1)
	if warcry:
		# έρχονται από ψηλά, πάνω από το ταμπλό, πετώντας προς το κελί τους —
		# λίγο μετά το πρώτο κύμα του βρυχηθμού, όχι όλα μαζί
		var sky := Vector2(clampf(at.x + randf_range(-160.0, 160.0), pf_left, pf_right), PF_TOP - 120.0)
		after(WARCRY_TIME * 0.45 + randf_range(0.0, 0.15), _warcry_fly.bind(sky, at, spot, type, hp))
		return
	var from: Vector2 = source.position + Vector2(0, -source.box.y * 0.3)
	after(SUMMON_CAST, _summon_bolt.bind(from, at, spot, type, hp))


const WARCRY_TIME := 0.55      # ο βρυχηθμός του boss
const WARCRY_FLY := 0.45       # η πτήση των minions προς τα κελιά τους


## Το minion πετάει από τον ουρανό στο κελί του, με τα δικά του καρέ ηρεμίας
## να παίζουν όσο πετάει (οι νυχτερίδες χτυπάνε φτερά), και προσγειώνεται με
## σκόνη — χωρίς κύκλο, χωρίς μαγεία.
func _warcry_fly(sky: Vector2, at: Vector2, spot: Vector2i, type: EnemyType, hp: float) -> void:
	lob(sky, at, type.sprite, _warcry_land.bind(spot, type, hp), -50.0, WARCRY_FLY, 0.0,
		2.0 * type.sprite_scale)
	if not type.frames_idle.is_empty():
		lobs[-1]["frames"] = type.frames_idle
		lobs[-1]["fps"] = 16.0


func _warcry_land(spot: Vector2i, type: EnemyType, hp: float) -> void:
	reserved.erase(spot)
	if phase == "over" or not grid.is_free(spot.x, spot.y):
		return
	var at := block_center(spot.x, spot.y, 1, 1)
	add_sparks(at + Vector2(0, cell * 0.3), 8, Color("c9b28a"), 130.0, 5.0)
	var b = _make_block(spot.x, spot.y, type, hp, 1, 1, false)
	b.appear("pop")


## Το μαγικό βλήμα: μια μικρή μωβ σφαίρα που πετάει σε χαμηλή καμπύλη
## από τον καλεστή στο κελί, με ουρά από σπίθες.
func _summon_bolt(from: Vector2, at: Vector2, spot: Vector2i, type: EnemyType, hp: float) -> void:
	add_sparks(from, 12, SUMMON_COL, 180.0, 6.0)
	var orb: Texture2D = summon_frames[2] if summon_frames.size() > 2 else null
	lob(from, at, orb, _summon_circle.bind(at, spot, type, hp), 60.0, SUMMON_BOLT, 12.0, 1.5)
	lobs[-1]["trail"] = SUMMON_COL


func _summon_circle(at: Vector2, spot: Vector2i, type: EnemyType, hp: float) -> void:
	if not summon_frames.is_empty():
		play_fx(summon_frames, at, 2.2, float(summon_frames.size()) / SUMMON_RISE,
			SUMMON_RISE + 0.3, 0.3, true)
	add_sparks(at, 10, SUMMON_COL, 140.0, 5.0)
	after(SUMMON_RISE, _summon_land.bind(spot, type, hp))


func _summon_land(spot: Vector2i, type: EnemyType, hp: float) -> void:
	reserved.erase(spot)
	if phase == "over" or not grid.is_free(spot.x, spot.y):
		return
	var at := block_center(spot.x, spot.y, 1, 1)
	add_sparks(at, 12, SUMMON_COL, 200.0, 5.0)
	var b = _make_block(spot.x, spot.y, type, hp, 1, 1, false)
	b.appear("rise")


func _spawn_orb(col: int, kind: String) -> void:
	var o := OrbScene.instantiate()
	add_child(o)
	o.add_to_group("orb")
	o.kind = kind
	o.col = col
	o.row = 0
	o.position = block_center(col, 0, 1, 1)
	o.body_entered.connect(_on_orb_taken.bind(o))


func _on_orb_taken(_body: Node, orb: Node) -> void:
	if not is_instance_valid(orb):
		return
	if orb.kind == "triple":
		triple_turns = TRIPLE_TURNS
	else:
		gained += 1
	orb.queue_free()


# ---------------------------------------------------------------- ζημιά

func _on_ball_struck(block, ball) -> void:
	if not is_instance_valid(block):
		return
	var dmg: float = ball.damage
	# ασπίδα που κρατάει: τετράγωνο προστασίας στην πλευρά του χτυπήματος,
	# αντί για τις σπίθες — μόνο όσο υπάρχει ασπίδα
	if block.ability is ShieldAbility and block.ability.shield > 0.0:
		block.guard_flash(ball.position - block.position)
	else:
		add_sparks(ball.position, 5, _accent(0.82), 190.0, 4.0)
	# αδύναμο σημείο του μεγάλου boss (ο Grukk στην κορυφή): διπλή ζημιά,
	# χρυσές σπίθες — ο παίκτης βλέπει ότι βρήκε το σημείο
	if block.is_final and block.weak_rect.has_area() and not block.shield_on:
		if block.weak_rect.grow(10.0).has_point(block.to_local(ball.position)):
			dmg *= WEAK_MULT
			add_sparks(ball.position, 8, Color("ffe066"), 260.0, 6.0)
			add_shake(1.2)
	_hurt(block, dmg)
	if aoe_mode:
		for nb in grid.neighbors(block):
			if ball.splashed.has(nb):
				continue          # κάθε μπάλα πιτσιλίζει ένα block μία φορά
			ball.splashed[nb] = true
			_hurt(nb, ball.damage)


func _hurt(block, amount: float) -> float:
	if not is_instance_valid(block):
		return 0.0
	return block.take_damage(amount)


func _on_block_damaged(destroyed: bool, _amount: float, block) -> void:
	score += PTS_KILL if destroyed else PTS_HIT
	if not destroyed:
		# η ικανότητα μαθαίνει για τη ζημιά από εδώ — το block δεν κρατάει
		# αναφορά στο παιχνίδι
		if block.ability:
			block.ability.on_damaged(block, self)
		return
	add_sparks(block.position, 16, _accent(0.70), 280.0, 6.0)
	add_shake(7.0 if block.is_boss else 2.5)
	kills += 1
	special_charge += 1.0          # το special γεμίζει με σκοτωμούς, όχι με ζημιά
	grid.erase(block)
	if block.ability:
		block.ability.on_death(block, self)
	if block.kind == "war_drummer":
		call_deferred("update_boss_shield")
	if block == boss:
		boss = null
		var area := current_area()
		if block.is_final or area == null or area.final_boss == null:
			_boss_fallen(block)
			_clear_area()
		else:
			_announce("MINI-BOSS DOWN!")


func boss_alive() -> bool:
	return boss != null and is_instance_valid(boss)


func _clear_area() -> void:
	# ξεκλείδωμα δράκου που ανοίγει με αυτή την περιοχή — μόνο για αυτό το run
	var unlocked_now := false
	for d in dragons:
		if d.unlock_after_area == area_index + 1 and not run_dragons.has(d.id):
			run_dragons.append(d.id)
			new_dragon = true
			unlocked_now = true
			_announce("NEW DRAGON: %s" % d.display_name)
	if not unlocked_now:
		_announce("AREA CLEARED!")


# ---------------------------------------------------------------- χειρισμός

func frame_left() -> float:
	return pf_left - BORDER


func frame_right() -> float:
	return pf_right + BORDER


# Η γεωμετρία του HUD ζει εδώ και όχι στο hud.gd, γιατί από αυτήν βγαίνουν
# και τα πατήματα. Όλα τα γραφικά του είναι σε art pixels και δείχνονται x2,
# οπότε τα μεγέθη εδώ είναι τα διπλά των PNG (π.χ. hud_btn 38 -> 76).

const HUD_BTN := 76.0                          # hud_btn.png, μενού και παύση
const HUD_PANEL := Vector2(344.0, 160.0)       # hud_panel.png, ένα από τα δύο πάνελ
const HUD_PANEL_GAP := 24.0                    # κενό ανάμεσά τους, κάτω από τον δράκο
const HUD_MEDAL := Vector2(146.0, 110.0)       # hud_medal.png
const HUD_CLAW := Vector2(132.0, 130.0)        # hud_claw.png


## Παύση: πάνω δεξιά γωνία. Το μενού είναι το συμμετρικό της, πάνω αριστερά.
func pause_rect() -> Rect2:
	return Rect2(frame_right() - 20.0 - HUD_BTN, 18.0, HUD_BTN, HUD_BTN)


func menu_rect() -> Rect2:
	return Rect2(frame_left() + 20.0, 18.0, HUD_BTN, HUD_BTN)


## Μουσική: αμέσως αριστερά από την παύση. Ανοίγει το πάνελ έντασης.
func mute_rect() -> Rect2:
	var pr := pause_rect()
	return Rect2(pr.position.x - 10.0 - HUD_BTN, pr.position.y, HUD_BTN, HUD_BTN)


## Κουμπί TEST: αμέσως αριστερά από τη μουσική (μόνο όταν debug_menu).
func debug_rect() -> Rect2:
	var mr := mute_rect()
	return Rect2(mr.position.x - 10.0 - HUD_BTN, mr.position.y, HUD_BTN, HUD_BTN)


# ---------------------------------------------------------------- test menu
# Πλέγμα: μία στήλη ανά περιοχή (START / MINI / BOSS) και από κάτω τα
# βοηθήματα (μπάλες, special, καθάρισμα). Όλα για δοκιμές στο κινητό, όπου
# δεν υπάρχει κονσόλα.

const DBG_COLS := 3
const DBG_BTN := Vector2(168.0, 50.0)
const DBG_GAP := 12.0
const DBG_PAD := 20.0
const DBG_TITLE := 58.0
const DBG_HEAD := 30.0         # τίτλοι στηλών (ονόματα περιοχών)


## Τα κουμπιά του μενού: [ετικέτα, ενέργεια, όρισμα].
func debug_buttons() -> Array:
	var out := []
	for w in ["start", "mini", "boss"]:
		for i in mini(areas.size(), DBG_COLS):
			var label := "START"
			if w == "mini":
				label = "MINI-BOSS" if areas[i].final_boss else "ROUND %d" % MINIBOSS_ROUND
			elif w == "boss":
				label = "BOSS"
			out.append([label, "jump", [i, w]])
	out.append(["+10 BALLS", "balls", 10])
	out.append(["+50 BALLS", "balls", 50])
	out.append(["SPECIAL", "special", 0])
	out.append(["KILL ALL", "clear", 0])
	out.append(["BOSS -50%", "hurt_boss", 0.5])
	out.append(["CLOSE", "close", 0])
	return out


func debug_panel_rect() -> Rect2:
	var rows := ceili(float(debug_buttons().size()) / DBG_COLS)
	var w := DBG_COLS * DBG_BTN.x + (DBG_COLS - 1) * DBG_GAP + DBG_PAD * 2.0
	# + το κενό πριν από τα βοηθήματα και η γραμμή πληροφοριών στο κάτω μέρος
	var h := DBG_TITLE + DBG_HEAD + rows * (DBG_BTN.y + DBG_GAP) + DBG_GAP * 3.0 + DBG_PAD + 22.0
	return Rect2((W - w) * 0.5, PF_TOP - 40.0, w, h)


func debug_button_rect(i: int) -> Rect2:
	var p := debug_panel_rect()
	var c := i % DBG_COLS
	var r := i / DBG_COLS
	# κενό ανάμεσα στις πίστες και στα βοηθήματα
	var extra := DBG_GAP * 2.0 if r >= 3 else 0.0
	return Rect2(p.position.x + DBG_PAD + c * (DBG_BTN.x + DBG_GAP),
		p.position.y + DBG_TITLE + DBG_HEAD + r * (DBG_BTN.y + DBG_GAP) + extra, DBG_BTN.x, DBG_BTN.y)


func _debug_press(p: Vector2) -> void:
	if not debug_panel_rect().grow(DBG_GAP * 3.0).has_point(p):
		debug_open = false
		return
	var btns := debug_buttons()
	for i in btns.size():
		if debug_button_rect(i).has_point(p):
			_debug_do(btns[i][1], btns[i][2])
			return


func _debug_do(action: String, arg) -> void:
	match action:
		"jump":
			debug_jump(arg[0], arg[1])
			debug_open = false
		"balls":
			ball_count += int(arg)
			_announce("+%d BALLS (x%d)" % [int(arg), ball_count])
		"special":
			if dragon:
				special_charge = dragon.special_cost
				_announce("SPECIAL READY")
		"clear":
			for b in grid.blocks():
				if b != boss:
					grid.erase(b)
					add_sparks(b.position, 6, Color("d9d2c0"), 160.0, 4.0)
					b.vanish()
			update_boss_shield()
			_announce("BOARD CLEARED")
		"hurt_boss":
			if boss_alive():
				_hurt(boss, boss.hp * float(arg))
		"close":
			debug_open = false


## Άλμα σε περιοχή: "start" (γύρος 1), "mini" (γύρος MINIBOSS_ROUND), "boss"
## (τελευταίος γύρος — έρχεται ο boss, με την είσοδό του αν είναι μεγάλος).
## Σταματάει ό,τι τρέχει: μπάλες, ρίψεις, cinematic.
func debug_jump(area_i: int, which: String) -> void:
	for b in get_tree().get_nodes_in_group("ball"):
		b.queue_free()
	live_balls = 0
	to_fire = 0
	Engine.time_scale = 1.0
	lobs.clear()
	reserved.clear()
	fx_anims.clear()
	_soft.clear()
	_reset_wendigo_fx()
	transition_t = -1.0
	boss_intro_t = -1.0
	freeze_rounds = 0
	inferno_active = false
	awake_active = false
	paused = false
	get_tree().paused = false
	for b in grid.blocks():
		grid.erase(b)
		b.vanish()
	for o in get_tree().get_nodes_in_group("orb"):
		o.queue_free()
	boss = null
	area_index = clampi(area_i, 0, areas.size() - 1)
	var r := 1
	if which == "mini":
		r = MINIBOSS_ROUND
	elif which == "boss":
		r = ROUNDS_PER_AREA
	level = area_index * ROUNDS_PER_AREA + r
	_apply_theme()
	phase = "aim"
	aiming = false
	_add_row()
	if phase == "aim":
		var area := current_area()
		_announce("%s - ROUND %d" % [area.display_name if area else "", area_round()])


## Το πάνελ έντασης κρέμεται κάτω από τη νότα, στοιχισμένο με την παύση δεξιά.
func volume_panel_rect() -> Rect2:
	var w := 330.0
	return Rect2(pause_rect().end.x - w, mute_rect().end.y + 10.0, w, 92.0)


## Mute μέσα στο πάνελ, αριστερά.
func volume_mute_rect() -> Rect2:
	var r := volume_panel_rect()
	return Rect2(r.position + Vector2(12.0, 12.0), Vector2(68.0, 68.0))


## Η μπάρα έντασης, δεξιά από το mute.
func volume_bar_rect() -> Rect2:
	var r := volume_panel_rect()
	var x := volume_mute_rect().end.x + 26.0
	return Rect2(x, r.get_center().y - 2.0, r.end.x - 30.0 - x, 20.0)


## Τα δύο πάνελ της κάτω μπάρας, αριστερό και δεξί (το δεξί είναι καθρέφτισμα).
func hud_panel_rect(right: bool) -> Rect2:
	var y := H - HUD_PANEL.y - 18.0
	var cx := (frame_left() + frame_right()) * 0.5
	if right:
		return Rect2(cx + HUD_PANEL_GAP * 0.5, y, HUD_PANEL.x, HUD_PANEL.y)
	return Rect2(cx - HUD_PANEL_GAP * 0.5 - HUD_PANEL.x, y, HUD_PANEL.x, HUD_PANEL.y)


## Το κέντρο της στρογγυλής υποδοχής κάθε πάνελ, κοντά στην εξωτερική του άκρη.
func hud_socket(right: bool) -> Vector2:
	var r := hud_panel_rect(right)
	var y := r.position.y + r.size.y * 0.54
	if right:
		return Vector2(r.end.x - r.size.x * 0.21, y)
	return Vector2(r.position.x + r.size.x * 0.21, y)


## Special: το δαχτυλίδι με τα νύχια, στην υποδοχή του δεξιού πάνελ.
func special_rect() -> Rect2:
	var s := hud_socket(true)
	return Rect2(s - Vector2(HUD_CLAW.x * 0.5, HUD_CLAW.y * 0.5 + 4.0), HUD_CLAW)


## Διακόπτης SINGLE / AOE: δύο θέσεις μέσα στο δεξί πάνελ.
func aoe_rect() -> Rect2:
	var r := hud_panel_rect(true)
	var x := r.position.x + 30.0
	var w := hud_socket(true).x - 78.0 - x
	return Rect2(x, r.position.y + r.size.y * 0.57, w, 40.0)


## Ποια θέση του διακόπτη πατήθηκε: αριστερά SINGLE (false), δεξιά AOE (true).
func aoe_pick(p: Vector2) -> bool:
	return p.x >= aoe_rect().get_center().x


## Επιλογή δράκου: το μετάλλιο στην υποδοχή του αριστερού πάνελ.
func dragon_rect() -> Rect2:
	var s := hud_socket(false)
	return Rect2(s - Vector2(HUD_MEDAL.x * 0.5, HUD_MEDAL.y * 0.5 + 6.0), HUD_MEDAL)


# ---------------------------------------------------------------- επιλογή δράκου
# Κάρτες σε πλέγμα 3 στηλών: χωράνε 9 δράκοι στο πεδίο. Για περισσότερους
# θα χρειαστούν σελίδες ή κύλιση.

const PICKER_COLS := 3
const PICKER_PAD := 20.0
const PICKER_GAP := 14.0
const PICKER_TITLE := 74.0
const PICKER_CARD_H := 250.0


func picker_panel_rect() -> Rect2:
	var rows := ceili(float(dragons.size()) / PICKER_COLS)
	var h := PICKER_TITLE + rows * (PICKER_CARD_H + PICKER_GAP) - PICKER_GAP + PICKER_PAD + 44.0
	var x := frame_left() + 16.0
	return Rect2(x, PF_TOP - 20.0, frame_right() - 16.0 - x, h)


func picker_card_rect(i: int) -> Rect2:
	var panel := picker_panel_rect()
	var w := (panel.size.x - PICKER_PAD * 2.0 - PICKER_GAP * (PICKER_COLS - 1)) / PICKER_COLS
	var c := i % PICKER_COLS
	var r := i / PICKER_COLS
	return Rect2(panel.position.x + PICKER_PAD + c * (w + PICKER_GAP),
		panel.position.y + PICKER_TITLE + r * (PICKER_CARD_H + PICKER_GAP), w, PICKER_CARD_H)


## Πάτημα όσο είναι ανοιχτή η επιλογή: κάρτα = διάλεξε, οπουδήποτε αλλού = κλείσε.
func picker_press(p: Vector2) -> void:
	for i in dragons.size():
		if picker_card_rect(i).has_point(p):
			if select_dragon(dragons[i].id):
				picker_open = false
			return
	picker_open = false


## Πόσο κοντά είναι το passive του δράκου στο επόμενο «χτύπημά» του, 0..1.
## Γεμάτο = η επόμενη μπάλα (ή ο επόμενος γύρος) το ενεργοποιεί.
func passive_progress() -> float:
	if dragon == null:
		return 0.0
	match dragon.passive:
		"ball_every5":
			return float(level % 5) / 5.0
		_:
			return float(balls_fired % 5) / 4.0


func special_ready() -> bool:
	return dragon != null and special_charge >= dragon.special_cost


func _unhandled_input(event: InputEvent) -> void:
	# όσο είναι ανοιχτό το Book ή μια κάρτα εχθρού, όλα τα πατήματα πάνε εκεί
	if bestiary and bestiary.is_open():
		if event is InputEventMouseButton and event.pressed 				and event.button_index == MOUSE_BUTTON_LEFT:
			bestiary.press(get_global_mouse_position())
		return
	# όσο είναι ανοιχτό το test menu, πιάνει όλα τα πατήματα
	if debug_open:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_debug_press(get_global_mouse_position())
		return
	# όσο είναι ανοιχτό το πάνελ έντασης, πιάνει όλα τα πατήματα
	if volume_open:
		var vp := get_global_mouse_position()
		if event is InputEventMouseMotion:
			if volume_drag:
				_set_volume_at(vp.x)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_volume_press(vp)
			elif volume_drag:
				volume_drag = false
				SaveManager.save_data(save)
		return
	if event is InputEventMouseMotion:
		if phase == "aim" and aiming:
			_set_aim(get_global_mouse_position())
		return

	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var p := get_global_mouse_position()
	# ειδοποιήσεις νέων εχθρών και κουμπί του Book
	if mb.pressed and not paused and bestiary and bestiary.press(p):
		aiming = false
		return
	if mb.pressed and pause_rect().has_point(p):
		_toggle_pause()
		return
	# δουλεύει και μέσα στην παύση
	if mb.pressed and mute_rect().has_point(p):
		volume_open = true
		aiming = false
		return
	if mb.pressed and debug_menu and debug_rect().has_point(p):
		debug_open = true
		aiming = false
		return
	# δεν υπάρχει ακόμα οθόνη μενού· το κουμπί ανοίγει την παύση, που είναι
	# το μέρος όπου θα ζήσει όταν φτιαχτεί
	if mb.pressed and menu_rect().has_point(p):
		_toggle_pause()
		return
	if paused:
		return
	# ο επιλογέας δράκου πιάνει τα πάντα όσο είναι ανοιχτός
	if picker_open:
		if mb.pressed:
			picker_press(p)
		return
	if mb.pressed and dragon_rect().has_point(p):
		if can_switch_dragon():
			picker_open = true
			new_dragon = false
		return
	# όσο πετάνε μπάλες, τα δύο αυτά κουμπιά είναι κλειδωμένα — το HUD τα
	# δείχνει γκριζαρισμένα, και εδώ το πάτημα απλώς καταπίνεται
	if mb.pressed and aoe_rect().has_point(p):
		# δύο θέσεις δίπλα-δίπλα: το πάτημα διαλέγει εκείνη που πατήθηκε
		if not controls_locked():
			aoe_mode = aoe_pick(p)
		return
	if mb.pressed and special_rect().has_point(p):
		if not controls_locked():
			_use_special()
		return
	# πατήματα στην κάτω μπάρα χειριστηρίων δεν ξεκινούν στόχευση
	if mb.pressed and p.y >= ui_top:
		return

	match phase:
		"aim":
			if mb.pressed:
				aiming = true
				_set_aim(get_global_mouse_position())
			elif aiming:
				aiming = false
				if aim_cancel:
					aim_cancel = false
				else:
					_fire()
		"shoot":
			if mb.pressed:
				Engine.time_scale = 1.0 if Engine.time_scale > 1.0 else 3.0
		"over":
			if mb.pressed:
				_start()


## Ανάβει τη φλόγα που σκεπάζει την αλλαγή μορφής. Χωρίς αυτήν ο μικρός
## δράκος θα γινόταν μεγάλος μέσα σε ένα καρέ.
func _awaken_flash() -> void:
	awaken_t = AWAKEN_TIME
	add_shake(5.0)


func _use_special() -> void:
	if not special_ready():
		return
	match dragon.special:
		"swarm":
			if phase == "shoot":
				to_fire += ball_count
			else:
				inferno_active = false
				_fire()
				to_fire += ball_count
			_announce("SWARM!")
		"freeze":
			freeze_rounds = FREEZE_ROUNDS
			_paint_frozen()
			# παγωμένη σκόνη πάνω σε κάθε εχθρό τη στιγμή που πιάνει ο πάγος
			for fb in grid.blocks():
				if is_instance_valid(fb):
					add_sparks(fb.position, 6, Color("dff4ff"), 150.0, 4.0)
			add_shake(4.0)
			_announce("FREEZE!")
		_:
			inferno_active = true
			_announce("INFERNO!")
	# η μεταμόρφωση δεν ανήκει σε ένα συγκεκριμένο special: όποιος δράκος έχει
	# δεύτερη μορφή τη βγάζει όταν ρίχνει το δικό του, όποιο κι αν είναι αυτό
	if dragon.awakened is DragonType:
		awake_active = true
		_awaken_flash()
		_refresh_glow()
	special_charge = 0.0


## Για ό,τι κινείται μόνο του (π.χ. η αύρα): σταματάει στην παύση και στο Book.
func frozen_world_paused() -> bool:
	return frozen()


## Παγωμένο παιχνίδι: παύση, ή ανοιχτό Book / κάρτα εχθρού.
func frozen() -> bool:
	return paused or (bestiary != null and bestiary.is_open())


func _toggle_pause() -> void:
	if phase == "over":
		return
	paused = not paused
	get_tree().paused = paused


## Πόσο κάτω από τη γραμμή του δαπέδου πρέπει να κατέβει το δάχτυλο για να
## ακυρωθεί η βολή — πάνω στο κεφάλι του δράκου.
const AIM_CANCEL_DROP := 30.0


func _set_aim(p: Vector2) -> void:
	aim_cancel = p.y > floor_y + AIM_CANCEL_DROP
	var d := p - Vector2(launch_x, floor_y - 18.0)
	if d.y > -20.0:
		d.y = -20.0
	d = d.normalized()
	var min_y := 0.2
	if -d.y < min_y:
		var sx := 1.0 if d.x >= 0.0 else -1.0
		d = Vector2(sx * sqrt(1.0 - min_y * min_y), -min_y)
	aim_dir = d


func _fire() -> void:
	phase = "shoot"
	to_fire = ball_count
	fire_timer = 0.0
	shot_time = 0.0
	next_x = -1.0
	gained = 0
	live_balls = 0
	Engine.time_scale = 1.0


# ---------------------------------------------------------------- βρόχος

func _process(delta: float) -> void:
	t += delta
	if banner_time > 0.0:
		banner_time = maxf(0.0, banner_time - delta)
		if banner_time == 0.0:
			banner = ""
	if not frozen():
		_update_life(delta)
		if in_transition():
			_update_transition(delta)
		if boss_intro_t >= 0.0:
			_update_boss_intro(delta)
		_update_lobs(delta)
		_update_fx_anims(delta)
		_update_wendigo_fx(delta)
		_update_soft(delta)
	queue_redraw()
	if frozen() or phase != "shoot":
		return
	shot_time += delta
	if shot_time > 9.0:
		Engine.time_scale = 3.0
	if to_fire > 0:
		fire_timer -= delta
		while to_fire > 0 and fire_timer <= 0.0:
			_shoot_once()
			to_fire -= 1
			fire_timer += FIRE_GAP


func _shoot_once() -> void:
	if triple_turns > 0:
		for a in PackedFloat32Array([-0.13, 0.0, 0.13]):
			_make_ball(aim_dir.rotated(a))
	else:
		_make_ball(aim_dir)


func _make_ball(dir: Vector2) -> void:
	var b := BallScene.instantiate()
	add_child(b)
	b.add_to_group("ball")
	b.position = Vector2(launch_x, floor_y - 18.0)
	b.velocity = dir * BALL_SPEED
	b.speed = BALL_SPEED
	b.floor_y = floor_y
	# σε λειτουργία AoE η μπάλα σκάει σε γειτονικά κελιά, οπότε δείχνει
	# διαφορετικό βλήμα — το ίδιο που δείχνει και το κουμπί
	b.sprite = ball_tex(aoe_mode)
	# στο INFERNO η μπάλα ζωγραφίζεται μεγαλύτερη· το σχήμα σύγκρουσης μένει
	# ίδιο, ώστε να μη μεγαλώνει κρυφά και η ευκολία του σημαδιού
	b.draw_scale = INFERNO_BALL_SCALE if awake_active else 1.0
	if dragon:
		b.spin = dragon.ball_spin
		b.trail_color = dragon.accent
	var bdg := active_dragon()
	if bdg:
		b.heading = bdg.ball_heading
	b.damage = _ball_damage()
	b.died.connect(_on_ball_died)
	b.struck.connect(_on_ball_struck)
	live_balls += 1
	balls_fired += 1
	recoil = 1.0
	add_sparks(mouth_pos(), 7, _accent(1.0), 230.0, 5.0)


func _ball_damage() -> float:
	var dmg := 1.0
	if dragon and dragon.passive == "every5_double" and balls_fired % 5 == 4:
		dmg *= 2.0                      # κάθε 5η μπάλα
	if inferno_active:
		dmg *= 3.0
	if aoe_mode:
		dmg *= SPLASH_RATIO
	return dmg


func _on_ball_died(x: float) -> void:
	if next_x < 0.0:
		next_x = clampf(x, pf_left + 20.0, pf_right - 20.0)
	live_balls -= 1
	if live_balls <= 0 and to_fire == 0:
		_end_turn()


func _end_turn() -> void:
	Engine.time_scale = 1.0
	# πριν βγουν οι νέοι εχθροί του γύρου: οι δικές τους ειδοποιήσεις ξεκινούν από 0
	if bestiary:
		bestiary.turn_ended()
	# γύρος παγώματος: μετράει κανονικά, αλλά ο κόσμος δεν κουνιέται
	var frozen_turn := freeze_rounds > 0
	if frozen_turn:
		freeze_rounds -= 1
	# η εξελιγμένη μορφή κρατάει όσο κρατάει το πάγωμα, όχι μόνο μία βολή
	var keep_form := frozen_turn and freeze_rounds > 0
	if awake_active and not keep_form:
		_awaken_flash()      # η ίδια φλόγα καλύπτει και την επιστροφή
	var was_awake := awake_active and not keep_form
	inferno_active = false
	awake_active = awake_active and keep_form
	if was_awake:
		_refresh_glow()        # γύρισε η βασική μορφή, γυρίζει και η λάμψη της
	ball_count += gained
	if next_x >= 0.0:
		launch_x = next_x
	if triple_turns > 0:
		triple_turns -= 1
	# όσο ζει ο boss ο γύρος δεν προχωράει, αλλιώς αλλάζει η περιοχή κάτω από τα πόδια του
	# και το ξεκλείδωμα πάει στη λάθος περιοχή· οι σειρές εχθρών συνεχίζουν κανονικά
	if not boss_alive():
		level += 1
		if dragon and dragon.passive == "ball_every5" and level % 5 == 0:
			ball_count += 1

	var new_area := clampi(int((level - 1) / ROUNDS_PER_AREA), 0, maxi(areas.size() - 1, 0))
	if new_area != area_index:
		# η λογική αλλάζει περιοχή αμέσως· τα γραφικά και το ταμπλό στο μαύρο
		# του cinematic (_area_swap), ώστε να μη φανεί η αλλαγή
		area_index = new_area
		_begin_area_transition()
		return

	if frozen_turn:
		if freeze_rounds == 0:
			_paint_frozen()        # λιώνει: οι εχθροί ξαναπαίρνουν το χρώμα τους
		phase = "aim"
		return

	var tween := create_tween()
	tween.set_parallel(true)

	# κατέβασμα: από κάτω προς τα πάνω, ώστε να ελευθερώνεται χώρος μπροστά
	var ordered := grid.blocks()
	ordered.sort_custom(func(a, b): return (a.row + a.ch) > (b.row + b.ch))
	# πρώτα κοιτάνε όλοι γύρω τους, με το ταμπλό ακόμα ακίνητο (π.χ. η αγέλη)
	war_drums = false
	_post_charges.clear()
	_post_summons.clear()
	_collecting = true
	for b in ordered:
		if b.ability:
			b.ability.before_advance(b, self)
	for b in ordered:
		var want := 1
		if b.ability:
			want = b.ability.advance_rows(b, 1)
		# τα τύμπανα πολέμου σπρώχνουν όποιον κινείται μία σειρά παραπάνω
		if war_drums and want > 0 and not b.is_boss:
			want += 1
		# Ό,τι κάνει παραπάνω από ένα βήμα (καβαλάρης, τύμπανα) κατεβαίνει πρώτα
		# μία σειρά μαζί με όλους, και κάνει το υπόλοιπο ΧΩΡΙΣΤΑ μόλις σταθούν
		# όλοι (_run_charges) — αλλιώς το διπλό βήμα χανόταν μέσα στη γενική
		# κίνηση και ο παίκτης δεν έβλεπε ποιος έκανε τι.
		if want >= 2 and b.cw == 1 and not b.is_boss:
			_post_charges.append([b, want - 1])
			want = 1
		var step := want
		while step > 0 and not grid.fits(b.col, b.row + step, b.cw, b.ch, b):
			step -= 1
		if step > 0:
			grid.move_to(b, b.col, b.row + step)
			b.begin_move(ADVANCE_TIME)      # όσο κατεβαίνει, κρύβει το περίγραμμά του
			tween.tween_property(b, "position:y",
				block_center(b.col, b.row, b.cw, b.ch).y, ADVANCE_TIME)

	for o in get_tree().get_nodes_in_group("orb"):
		o.row += 1
		if o.row >= death_row:
			o.queue_free()
		else:
			tween.tween_property(o, "position:y",
				block_center(o.col, o.row, 1, 1).y, ADVANCE_TIME)

	for b in grid.blocks():
		if b.ability and is_instance_valid(b) and not b.is_vanishing():
			b.ability.on_round_end(b, self)
	update_boss_shield()
	_collecting = false

	for b in grid.blocks():
		if b.row + b.ch > death_row:
			_game_over()
			return

	_add_row()
	# Οι ικανότητες, μία-μία αφού σταθούν όλοι: πρώτα τα charges, μετά τα
	# καλέσματα. Ο παίκτης περιμένει (after), αλλά μόνο όσο κρατάνε.
	var at := ADVANCE_TIME + ABILITY_GAP
	if not _post_charges.is_empty():
		var charges := _post_charges.duplicate()
		after(at, _run_charges.bind(charges))
		at += CHARGE_TIME + ABILITY_GAP
	if not _post_summons.is_empty():
		var summons := _post_summons.duplicate()
		after(at, _run_summons.bind(summons))
	# ό,τι πέταξε ο boss πρέπει να προσγειωθεί πριν ξαναρίξεις
	if phase != "boss_intro":
		phase = "boss_act" if not lobs.is_empty() else "aim"


## Βάφει τους εχθρούς παγωμένους όσο κρατάει το FREEZE και τους ξεβάφει όταν
## λιώσει. Στο self_modulate, όχι στο modulate: εκεί ζουν ο τόνος της περιοχής
## και το κόκκινο της Rage, που αλλιώς θα χάνονταν στο ξεπάγωμα.
# ---------------------------------------------------------------- μεγάλος boss
# Είσοδος: ο χάρτης σβήνει με σπίθες, ο boss πέφτει από ψηλά και σηκώνει
# σκόνη. Μετά μένει ακίνητος και ό,τι βγάζει το ΡΙΧΝΕΙ (lob_*): κάθε minion,
# οδόφραγμα ή βαρέλι πετάει σε καμπύλη από τον καταπέλτη και προσγειώνεται —
# τίποτα δεν εμφανίζεται από το πουθενά.

const WEAK_MULT := 2.0
const LOB_TIME := 0.75
const LOB_HEIGHT := 170.0


func _begin_boss_intro() -> void:
	boss_intro_t = 0.0
	_intro_spawned = false
	phase = "boss_intro"
	aiming = false
	aim_cancel = false
	banner = ""
	add_shake(5.0)
	# ό,τι στέκεται στο ταμπλό σβήνει — όχι σε ένα καρέ, με σπίθες και ξεθώριασμα
	for b in grid.blocks():
		grid.erase(b)
		add_sparks(b.position, 6, Color("d9d2c0"), 160.0, 4.0)
		b.vanish()
	for o in get_tree().get_nodes_in_group("orb"):
		add_sparks(o.position, 5, Color("ffb638"), 140.0, 4.0)
		o.queue_free()
	freeze_rounds = 0
	_announce("WARNING - BOSS INCOMING")


func _update_boss_intro(delta: float) -> void:
	boss_intro_t += delta
	if not _intro_spawned and boss_intro_t >= INTRO_CLEAR:
		_intro_spawned = true
		_spawn_final_boss()
	if boss_intro_t >= INTRO_END:
		boss_intro_t = -1.0
		phase = "aim"


## Ολοκληρώνει αμέσως την είσοδο (tests).
func finish_boss_intro() -> void:
	if boss_intro_t < 0.0:
		return
	if not _intro_spawned:
		_intro_spawned = true
		_spawn_final_boss()
	if boss and is_instance_valid(boss):
		boss.position = block_center(boss.col, boss.row, boss.cw, boss.ch)
	boss_intro_t = -1.0
	phase = "aim"


func _spawn_final_boss() -> void:
	var area := current_area()
	if area == null or area.final_boss == null:
		return
	var cw: int = area.final_cols
	var ch: int = area.final_rows
	var col := int((COLS - cw) * 0.5)
	var hp := maxf(20.0, round(level * area.final_hp_mult))
	boss = _make_block(col, 0, area.final_boss, hp, cw, ch, true)
	boss.is_final = true
	# αδύναμο σημείο: ποσοστό του σχεδίου (weak_uv της ικανότητας), σε τοπικές
	# συντεταγμένες του κουτιού όπου ζωγραφίζεται το πορτρέτο
	if boss.ability and "weak_uv" in boss.ability:
		var uv: Rect2 = boss.ability.weak_uv
		var ps: Vector2 = (boss.box - Vector2(6, 6)) * boss.sprite_scale
		boss.weak_rect = Rect2(-ps * 0.5 + uv.position * ps, uv.size * ps)
	# πτώση από ψηλά, με επιτάχυνση — και προσγείωση με σκόνη και τράνταγμα
	var target: Vector2 = boss.position
	boss.position.y = target.y - H * 0.6
	var tw := create_tween()
	tw.tween_property(boss, "position:y", target.y, INTRO_DROP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_boss_landed)


func _boss_landed() -> void:
	if boss == null or not is_instance_valid(boss):
		return
	add_shake(9.0)
	_ground_impact(boss)
	_announce("BOSS - %s" % boss_name())


func boss_name() -> String:
	var area := current_area()
	if area and area.final_boss:
		return area.final_boss.display_name.to_upper()
	return ""


## Ο μεγάλος boss έπεσε: δυνατή έκρηξη στο σώμα του.
func _boss_fallen(b) -> void:
	if not b.is_final:
		return
	add_shake(9.0)
	for i in 4:
		var p: Vector2 = b.position + Vector2(randf_range(-80, 80), randf_range(-80, 80))
		_play_explosion(p, 2.5 + randf())


## Η φάση του boss άλλαξε (το καλεί η ικανότητά του).
func boss_stage(b, stage: int) -> void:
	add_shake(6.0)
	add_sparks(b.position, 20, Color("ffb347"), 260.0, 6.0)
	match stage:
		2: _announce("GRUKK: BEAT THE DRUMS!")
		3: _announce("GRUKK: BRING THE POWDER!")


func boss_doom() -> int:
	if boss_alive() and boss.is_final and boss.ability and boss.ability.has_method("doom_left"):
		return boss.ability.doom_left()
	return -1


func count_kind(id: String) -> int:
	var n := 0
	for b in grid.blocks():
		if b.kind == id and not b.is_vanishing():
			n += 1
	return n


## Ασπίδα του μεγάλου boss: όσο ζει τυμπανιστής.
func update_boss_shield() -> void:
	if boss_alive() and boss.is_final:
		boss.shield_on = count_kind("war_drummer") > 0


# ---- ρίψεις

## Από πού φεύγουν οι ρίψεις: ο καταπέλτης στο πλάι του πύργου.
func _launch_point(src) -> Vector2:
	if src and is_instance_valid(src):
		return src.position + Vector2(src.box.x * 0.30, -src.box.y * 0.30)
	return Vector2(W * 0.5, PF_TOP)


## Ελεύθερα κελιά για ρίψη, ανάμεσα σε σειρές, μακριά από τη γραμμή θανάτου
## και από όσα έχουν ήδη κρατηθεί από άλλη ρίψη.
func _throw_cells(min_row: int, max_row: int, n: int) -> Array:
	var last := mini(max_row, death_row - 3)
	var cells := []
	for c in grid.free_cells(min_row, last):
		if not reserved.has(c):
			cells.append(c)
	cells.shuffle()
	return cells.slice(0, n)


func lob(from: Vector2, to: Vector2, tex: Texture2D, on_land: Callable,
		height := LOB_HEIGHT, dur := LOB_TIME, spin := 7.0, scale := 2.0) -> void:
	lobs.append({"from": from, "to": to, "tex": tex, "t": 0.0, "dur": dur,
		"h": height, "spin": spin, "scale": scale, "cb": on_land})
	if phase == "aim":
		phase = "boss_act"


## Η θέση ενός βλήματος σε καμπύλη: ευθεία από-προς, με παραβολή από πάνω.
func lob_pos(l: Dictionary) -> Vector2:
	var k: float = clampf(l.t / l.dur, 0.0, 1.0)
	return (l.from as Vector2).lerp(l.to, k) + Vector2(0, -4.0 * l.h * k * (1.0 - k))


func _update_lobs(delta: float) -> void:
	if lobs.is_empty():
		return
	var i := lobs.size() - 1
	while i >= 0:
		var l: Dictionary = lobs[i]
		l.t += delta
		# ουρά από σπίθες πίσω από ό,τι πετάει με χρώμα ουράς (μαγικό βλήμα)
		if l.has("trail") and l.t < l.dur:
			add_sparks(lob_pos(l), 2, l.trail, 60.0, 5.0)
		if l.t >= l.dur:
			lobs.remove_at(i)
			(l.cb as Callable).call()
		i -= 1
	if lobs.is_empty() and phase == "boss_act":
		phase = "aim"


## Βαρέλια με minions: σπάνε στην προσγείωση και το minion πετάγεται έξω.
func lob_minions(src, id: String, n: int, min_row: int, max_row: int) -> int:
	var type: EnemyType = enemy_by_id.get(id)
	if type == null:
		return 0
	var cells := _throw_cells(min_row, max_row, n)
	for c in cells:
		reserved[c] = true
		var hp := maxf(1.0, round(level * type.hp_mult))
		lob(_launch_point(src), block_center(c.x, c.y, 1, 1), tex_spawn_barrel,
			_land_spawn.bind(c, type, hp, "pop", true))
	return cells.size()


## Οδοφράγματα και βαρέλια μπαρούτι: πετάει το ίδιο το αντικείμενο.
func lob_specials(src, id: String, n: int, min_row: int, max_row: int) -> int:
	var type: EnemyType = enemy_by_id.get(id)
	if type == null:
		return 0
	var cells := _throw_cells(min_row, max_row, n)
	for c in cells:
		reserved[c] = true
		var mode := "rise" if type.invulnerable else "pop"
		lob(_launch_point(src), block_center(c.x, c.y, 1, 1), type.sprite,
			_land_spawn.bind(c, type, 1.0, mode, false), LOB_HEIGHT, LOB_TIME,
			2.0 if type.invulnerable else 7.0)
	return cells.size()


## Δύο τυμπανιστές, ένας σε κάθε πλευρά του πύργου.
func lob_drummers(src, id: String) -> int:
	var type: EnemyType = enemy_by_id.get(id)
	if type == null:
		return 0
	var sides := [
		[Vector2i(1, 1), Vector2i(0, 1), Vector2i(1, 2), Vector2i(0, 2), Vector2i(1, 0), Vector2i(0, 0), Vector2i(1, 3)],
		[Vector2i(5, 1), Vector2i(6, 1), Vector2i(5, 2), Vector2i(6, 2), Vector2i(5, 0), Vector2i(6, 0), Vector2i(5, 3)],
	]
	var n := 0
	for side in sides:
		for c: Vector2i in side:
			if c.x >= 0 and c.x < COLS and grid.is_free(c.x, c.y) and not reserved.has(c):
				reserved[c] = true
				var hp := maxf(1.0, round(level * type.hp_mult))
				lob(_launch_point(src), block_center(c.x, c.y, 1, 1), tex_spawn_barrel,
					_land_spawn.bind(c, type, hp, "pop", true))
				n += 1
				break
	return n


func _land_spawn(c: Vector2i, type: EnemyType, hp: float, mode: String, barrel: bool) -> void:
	reserved.erase(c)
	var at := block_center(c.x, c.y, 1, 1)
	add_shake(1.5)
	if barrel:
		# το βαρέλι σπάει: σανίδες και σκόνη
		add_sparks(at, 10, Color("8a5a2b"), 220.0, 6.0)
		add_sparks(at, 6, Color("c9b28a"), 120.0, 5.0)
	else:
		add_sparks(at + Vector2(0, cell * 0.35), 8, Color("a8906a"), 150.0, 5.0)
	if phase == "over" or not grid.is_free(c.x, c.y):
		return
	var b = _make_block(c.x, c.y, type, hp, 1, 1, false)
	b.appear(mode)
	if type.id == "war_drummer":
		update_boss_shield()


# ---- πολιορκία, εκρήξεις

## Ο καταπέλτης ρίχνει βράχο στον δράκο· στην πρόσκρουση όλο το ταμπλό
## κατεβαίνει μία σειρά (εκτός από όσα δεν κουνιούνται: boss, οδοφράγματα).
func siege_shot(src) -> void:
	var to := Vector2(launch_x, floor_y + 34.0)
	lob(_launch_point(src), to, tex_boulder, _siege_impact.bind(to), 300.0, 1.0, 9.0, 2.0)
	_announce("SIEGE!")


func _siege_impact(at: Vector2) -> void:
	_play_explosion(at, 3.0)
	add_shake(9.0)
	add_sparks(at, 24, Color("ffb347"), 320.0, 7.0)
	var ordered := grid.blocks()
	ordered.sort_custom(func(a, b): return (a.row + a.ch) > (b.row + b.ch))
	var tween := create_tween()
	tween.set_parallel(true)
	var moved := false
	for b in ordered:
		if b.is_vanishing() or (b.ability and b.ability.advance_rows(b, 1) == 0):
			continue
		if grid.fits(b.col, b.row + 1, b.cw, b.ch, b):
			grid.move_to(b, b.col, b.row + 1)
			b.begin_move(ADVANCE_TIME)
			tween.tween_property(b, "position:y", block_center(b.col, b.row, b.cw, b.ch).y, ADVANCE_TIME)
			moved = true
	if not moved:
		tween.kill()
	for b in grid.blocks():
		if b.row + b.ch > death_row:
			_game_over()
			return


## Το βαρέλι χτυπήθηκε: έκρηξη 3x3. Minions πεθαίνουν, οδοφράγματα
## γκρεμίζονται, ο boss χάνει ένα κομμάτι της ζωής του. Άλλο βαρέλι μέσα
## στην έκρηξη σκάει κι αυτό — αλυσίδα.
func keg_blast(col: int, row: int, pos: Vector2, boss_ratio: float) -> void:
	_play_explosion(pos, 2.4)
	add_shake(6.0)
	add_sparks(pos, 18, Color("ff9e2c"), 300.0, 6.0)
	var hit := []
	for dc in range(-1, 2):
		for dr in range(-1, 2):
			var b = grid.at(col + dc, row + dr)
			if b != null and not hit.has(b):
				hit.append(b)
	for b in hit:
		if not is_instance_valid(b) or b.is_vanishing():
			continue
		if b.invulnerable:
			crumble(b)
		elif b.is_final:
			_hurt(b, b.max_hp * boss_ratio)
		else:
			_hurt(b, b.hp + 1.0)


## Το φυτίλι κάηκε χωρίς να το χτυπήσεις: σκάει μόνο του, δεν πειράζει
## κανέναν, και από τα συντρίμμια πετάγονται goblins.
func keg_fizzle(b, minion_id: String, n: int) -> void:
	var pos: Vector2 = b.position
	var col: int = b.col
	var row: int = b.row
	grid.erase(b)
	b.vanish()
	_play_explosion(pos, 1.6)
	add_shake(3.0)
	var type: EnemyType = enemy_by_id.get(minion_id)
	if type == null:
		return
	var near := []
	for c in grid.free_cells(maxi(0, row - 1), mini(death_row - 3, row + 1)):
		if absi(c.x - col) <= 2 and not reserved.has(c):
			near.append(c)
	near.shuffle()
	for c in near.slice(0, n):
		reserved[c] = true
		var hp := maxf(1.0, round(level * type.hp_mult))
		lob(pos, block_center(c.x, c.y, 1, 1), tex_spawn_barrel,
			_land_spawn.bind(c, type, hp, "pop", true), 70.0, 0.45, 9.0)


## Γκρέμισμα οδοφράγματος: συντρίμμια ξύλου και ξεθώριασμα.
func crumble(b) -> void:
	grid.erase(b)
	add_sparks(b.position, 12, Color("8a5a2b"), 200.0, 6.0)
	add_sparks(b.position + Vector2(0, cell * 0.3), 6, Color("a8906a"), 120.0, 5.0)
	b.vanish()


# ---- Ice Wendigo (ο μεγάλος boss του Frost Marches, scripts/abilities/ability_wendigo.gd)
# Δεν ρίχνει τίποτα σε καμπύλη: ό,τι βγάζει ανεβαίνει ΑΠΟ ΤΟ ΠΑΤΩΜΑ (παγόβουνα)
# ή βγαίνει μέσα από την ομίχλη (κύμα). Οι καθυστερήσεις ζουν στο after(), ώστε
# ο παίκτης να περιμένει ως το τέλος τους, όπως με τις ρίψεις του Grukk.

const ICE_COL := Color("bfeaff")
const ICE_DEEP := Color("5fb4ff")
const HEAL_COL := Color("8fffd0")
const BERG_WARN := 0.3         # το πάτωμα ραγίζει και αχνίζει πριν βγει το παγόβουνο
const BERG_GAP := 0.14         # ανάμεσα σε διαδοχικά παγόβουνα
const BERG_ROWS := Vector2i(2, 7)
const WAVE_ROWS := Vector2i(2, 6)
const WAVE_GAP := 0.08         # ανάμεσα στα μέλη του κύματος που βγαίνουν από την ομίχλη
const GLARE_FREEZE := 0.3      # από το άναμμα των ματιών ως το πρώτο πάγωμα
const GLARE_SPEED := 2000.0    # px/s: το κύμα κρύου που απλώνεται από τα μάτια
const GLARE_SHATTER := 0.6     # πόσο μένουν παγωμένες οι τελευταίες μπάλες πριν σπάσουν
const HEAL_FLY := 0.55         # οι σταγόνες ζωής ως την καρδιά του
var glare_t := -1.0            # >=0: η λάμψη από τα μάτια του (fx.gd)
var glare_eyes := Vector2.ZERO
var heal_motes: Array = []     # {from, to, t, dur, d}: σταγόνες ζωής προς τον Wendigo
var heal_pops: Array = []      # {pos, t, text}: «+N» που ανεβαίνει


## Χτυπάει τα νύχια στο έδαφος· τα παγόβουνα σκίζουν το πάτωμα ένα-ένα.
func raise_icebergs(src, ab, id: String, n: int) -> void:
	var type: EnemyType = enemy_by_id.get(id)
	if type == null:
		return
	var slam := 0.0
	if not ab.slam_frames.is_empty():
		src.play_act(ab.slam_frames, ab.act_fps)
		# τα νύχια βρίσκουν το έδαφος περίπου στα 2/3 της κίνησης
		slam = ab.slam_frames.size() / ab.act_fps * 0.62
	after(slam, _slam_impact.bind(src))
	var hp := maxf(1.0, round(level * type.hp_mult))
	var cells := _throw_cells(BERG_ROWS.x, BERG_ROWS.y, n)
	for i in cells.size():
		var c: Vector2i = cells[i]
		reserved[c] = true
		after(slam + i * BERG_GAP, _berg_warn.bind(c))
		after(slam + i * BERG_GAP + BERG_WARN, _berg_rise.bind(c, type, hp))


func _slam_impact(src) -> void:
	if src == null or not is_instance_valid(src):
		return
	add_shake(5.0)
	var base: Vector2 = src.position + Vector2(0, src.box.y * 0.45)
	for i in 10:
		var p := base + Vector2(randf_range(-src.box.x * 0.4, src.box.x * 0.4), 0)
		add_sparks(p, 2, ICE_COL, 190.0, 5.0)


## Προειδοποίηση: ρωγμή στο κελί και αχνός παγωμένος ατμός — ο παίκτης βλέπει
## πού θα βγει, μια στιγμή πριν βγει.
func _berg_warn(c: Vector2i) -> void:
	var cr := Rect2(pf_left + c.x * cell, PF_TOP + c.y * cell, cell, cell)
	_floor_cracks(cr, cr.get_center(), 1.6, 0.8)
	add_sparks(cr.get_center() + Vector2(0, cell * 0.25), 6, ICE_COL, 70.0, 4.0)
	add_shake(1.0)


## Το παγόβουνο ξεπετάγεται: υψώνεται από τη βάση του, με πίδακα από
## θραύσματα πάγου προς τα πάνω και χιόνι γύρω από τη βάση.
func _berg_rise(c: Vector2i, type: EnemyType, hp: float) -> void:
	reserved.erase(c)
	if phase == "over" or not grid.is_free(c.x, c.y):
		return
	var b = _make_block(c.x, c.y, type, hp, 1, 1, false)
	b.appear("rise")
	var at := block_center(c.x, c.y, 1, 1)
	var base := at + Vector2(0, cell * 0.38)
	add_shake(2.5)
	for i in 14:
		var dir := Vector2(randf_range(-0.55, 0.55), -1.0).normalized()
		_spark_dir(base, dir * randf_range(180.0, 340.0), ICE_COL if i % 3 else Color.WHITE, 5.0)
	add_sparks(base, 10, Color("e8f6ff"), 110.0, 6.0)
	add_sparks(at, 6, ICE_DEEP, 160.0, 4.0)


## Σπίθα με δοσμένη ταχύτητα (το add_sparks τις σκορπάει προς όλες τις μεριές).
func _spark_dir(p: Vector2, v: Vector2, col: Color, size: float) -> void:
	if sparks.size() >= MAX_SPARKS:
		return
	var life := randf_range(0.35, 0.6)
	sparks.append({"p": p, "v": v, "life": life, "max": life, "c": col, "r": size})


func iceberg_cracked(b) -> void:
	add_sparks(b.position, 8, ICE_COL, 200.0, 5.0)
	add_shake(1.2)


## Έμεινε αχτύπητο ως το τέλος: λιώνει, χωρίς να βγάλει τίποτα.
func iceberg_melt(b) -> void:
	grid.erase(b)
	add_sparks(b.position + Vector2(0, cell * 0.3), 10, Color("7fc8ff"), 70.0, 5.0)
	add_sparks(b.position, 6, Color("e8f6ff"), 50.0, 4.0)
	b.vanish()


## Το παγόβουνο έσπασε: θραύσματα παντού και τα τέρατα που κρατούσε
## πετάγονται έξω — στο κελί του πρώτα, μετά στα διπλανά.
func iceberg_burst(col: int, row: int, pos: Vector2, ids: Array) -> void:
	add_shake(4.0)
	for i in 16:
		var ang := randf() * TAU
		_spark_dir(pos, Vector2(cos(ang), sin(ang)) * randf_range(160.0, 380.0),
			Color.WHITE if i % 4 == 0 else ICE_COL, 6.0)
	add_sparks(pos, 8, ICE_DEEP, 200.0, 5.0)
	if phase == "over":
		return
	var spots: Array[Vector2i] = [Vector2i(col, row)]
	for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		spots.append(Vector2i(col, row) + d)
	var made := 0
	for s in spots:
		if made >= ids.size():
			break
		if s.x < 0 or s.x >= COLS or s.y < 0 or s.y >= death_row - 1:
			continue
		if not grid.is_free(s.x, s.y) or reserved.has(s):
			continue
		var type: EnemyType = enemy_by_id.get(ids[made])
		made += 1
		if type == null:
			continue
		var b = _make_block(s.x, s.y, type, maxf(1.0, round(level * type.hp_mult)), 1, 1, false)
		b.appear("pop")


## Μισή ζωή: κέλυφος πάγου, χιονοθύελλα. Το κύμα βγαίνει στο τέλος του γύρου.
func wendigo_freeze(b, ab) -> void:
	add_shake(8.0)
	b.shield_on = true
	b.shield_color = ICE_COL
	b.set_idle(ab.frozen_idle, 6.0)
	if not ab.freeze_frames.is_empty():
		b.play_act(ab.freeze_frames, ab.act_fps)
	for i in 24:
		var ang := randf() * TAU
		_spark_dir(b.position, Vector2(cos(ang), sin(ang)) * randf_range(120.0, 320.0), ICE_COL, 6.0)
	if weather:
		weather.set_storm(true)
	_announce("THE WENDIGO FREEZES!")


## Από την ομίχλη βγαίνει ο στρατός του, ένας-ένας.
func wendigo_wave(_b, ab) -> void:
	var cells := _throw_cells(WAVE_ROWS.x, WAVE_ROWS.y, ab.wave_count)
	for i in cells.size():
		var c: Vector2i = cells[i]
		var type: EnemyType = enemy_by_id.get(ab.roll_wave())
		if type == null:
			continue
		reserved[c] = true
		var hp := maxf(1.0, round(level * type.hp_mult * ab.wave_hp))
		after(0.2 + i * WAVE_GAP, _wave_emerge.bind(c, type, hp))
	_announce("BLIZZARD!")


func _wave_emerge(c: Vector2i, type: EnemyType, hp: float) -> void:
	reserved.erase(c)
	if phase == "over" or not grid.is_free(c.x, c.y):
		return
	var at := block_center(c.x, c.y, 1, 1)
	add_sparks(at, 8, Color("e8f0f4"), 60.0, 9.0)       # πούφος ομίχλης
	var b = _make_block(c.x, c.y, type, hp, 1, 1, false)
	b.set_meta("wave", true)
	b.appear("mist")


## Πόσοι από το κύμα της θύελλας ζουν ακόμα.
func wave_left() -> int:
	var n := 0
	for b in grid.blocks():
		if b.has_meta("wave") and not b.is_vanishing():
			n += 1
	return n


## Γιατρειά όσο είναι παγωμένος: σταγόνες ζωής φεύγουν από κάθε μέλος του
## κύματος προς την καρδιά του, και η ζωή ανεβαίνει όταν φτάσουν.
func wendigo_heal(b, amount: float) -> void:
	var heart := wendigo_heart(b)
	var i := 0
	for w in grid.blocks():
		if not w.has_meta("wave") or w.is_vanishing():
			continue
		for k in 3:
			heal_motes.append({"from": w.position + Vector2(randf_range(-14, 14), randf_range(-14, 14)),
				"to": heart, "t": -0.05 * k - 0.02 * i, "dur": HEAL_FLY})
		i += 1
	after(HEAL_FLY + 0.1 + 0.02 * i, _heal_land.bind(b, amount))


func _heal_land(b, amount: float) -> void:
	if b == null or not is_instance_valid(b):
		return
	var before: float = b.hp
	b.heal(amount)
	var got := roundi(b.hp - before)
	var heart := wendigo_heart(b)
	add_sparks(heart, 14, HEAL_COL, 170.0, 5.0)
	if got > 0:
		heal_pops.append({"pos": heart + Vector2(0, -40), "t": 0.0, "text": "+%d" % got})


func wendigo_heart(b) -> Vector2:
	return b.position + Vector2(0, -b.box.y * 0.08)


## Έπεσε και ο τελευταίος της θύελλας: ο πάγος σπάει, ο ουρανός καθαρίζει.
func wendigo_thaw(b, ab) -> void:
	b.shield_on = false
	var type: EnemyType = enemy_by_id.get(b.kind)
	if type:
		b.set_idle(type.frames_idle, type.fps_idle)
	if not ab.freeze_frames.is_empty():
		var back: Array[Texture2D] = ab.freeze_frames.duplicate()
		back.reverse()
		b.play_act(back, ab.act_fps * 1.5)
	add_shake(9.0)
	for i in 30:
		var ang := randf() * TAU
		_spark_dir(b.position, Vector2(cos(ang), sin(ang)) * randf_range(200.0, 420.0),
			Color.WHITE if i % 3 == 0 else ICE_COL, 7.0)
	if weather:
		weather.set_storm(false)
	_announce("THE ICE SHATTERS!")


## Τα μάτια του αστράφτουν: ό,τι πετάει παγώνει — πρώτα ό,τι είναι κοντά του,
## το κύμα κρύου απλώνεται — και μετά σπάει. Η βολή χάνεται.
func wendigo_glare(b, ab) -> void:
	if phase != "shoot":
		return
	if not ab.glare_frames.is_empty():
		b.play_act(ab.glare_frames, ab.act_fps)
	glare_eyes = b.position + (ab.eyes_uv - Vector2(0.5, 0.5)) * (b.box - Vector2(6, 6)) * b.sprite_scale
	glare_t = 0.0
	to_fire = 0                    # ό,τι δεν έχει φύγει ακόμα, δεν φεύγει
	for ball in get_tree().get_nodes_in_group("ball"):
		ball.freeze(GLARE_FREEZE, glare_eyes, GLARE_SPEED)
	add_shake(3.0)
	_announce("FROZEN GAZE!")
	# ως εκεί έχει περάσει όλη την πίστα, ως και τη γωνία του δράκου
	var far := maxf(glare_eyes.distance_to(Vector2(pf_left, floor_y)),
		glare_eyes.distance_to(Vector2(pf_right, floor_y)))
	later(GLARE_FREEZE + far / GLARE_SPEED + GLARE_SHATTER, _shatter_balls)


func _shatter_balls() -> void:
	var balls := get_tree().get_nodes_in_group("ball")
	var each := clampi(60 / maxi(balls.size(), 1), 1, 6)
	for ball in balls:
		if not (ball.frozen or ball.freeze_in >= 0.0) or ball.is_queued_for_deletion():
			continue
		for i in each:
			var ang := randf() * TAU
			_spark_dir(ball.position, Vector2(cos(ang), sin(ang)) * randf_range(90.0, 220.0),
				Color.WHITE if i % 2 else ICE_COL, 4.0)
		ball.remove_from_group("ball")
		ball.queue_free()
		# ο δράκος μένει όπου ήταν: η μπάλα δεν έφτασε ποτέ στο έδαφος
		ball.died.emit(launch_x)
	add_shake(2.5)


func _reset_wendigo_fx() -> void:
	glare_t = -1.0
	heal_motes.clear()
	heal_pops.clear()
	if weather:
		weather.set_storm(false, true)


func _update_wendigo_fx(delta: float) -> void:
	if glare_t >= 0.0:
		glare_t += delta
		if glare_t > 1.2:
			glare_t = -1.0
	var i := heal_motes.size() - 1
	while i >= 0:
		heal_motes[i].t += delta
		if heal_motes[i].t >= heal_motes[i].dur:
			heal_motes.remove_at(i)
		i -= 1
	i = heal_pops.size() - 1
	while i >= 0:
		heal_pops[i].t += delta
		if heal_pops[i].t >= 1.2:
			heal_pops.remove_at(i)
		i -= 1


## Ένδειξη του HUD κάτω από τη ζωή του μεγάλου boss ("" = καμία δική του).
func boss_label() -> String:
	if not boss_alive() or not boss.is_final or boss.ability == null:
		return ""
	var ab = boss.ability
	if ab is WendigoAbility:
		if ab.frozen():
			if not ab.wave_out:
				return "BLIZZARD COMING!"
			return "BLIZZARD - %d LEFT" % wave_left()
		var n: int = ab.icebergs_in()
		return "ICEBERGS IN %d" % n if n > 1 else "ICEBERGS NEXT!"
	return ""


func _play_explosion(pos: Vector2, scale: float) -> void:
	if explosion_frames.is_empty():
		add_sparks(pos, 20, Color("ff9e2c"), 280.0, 7.0)
		return
	play_fx(explosion_frames, pos, scale, 16.0)


## Εφέ σε σημείο της οθόνης. `frames` παίζουν μία φορά στα `fps`· αν δοθεί
## `life`, το τελευταίο καρέ κρατάει ως τότε. `fade`: σβήσιμο στο τέλος.
## `floor`: ζωγραφίζεται στο πάτωμα, ΚΑΤΩ από τους εχθρούς (ρωγμές, μαγικός
## κύκλος)· αλλιώς από πάνω τους. `pop`: μπαίνει με μικρό φούσκωμα (emote).
func play_fx(frames: Array, pos: Vector2, scale: float, fps: float, life := -1.0,
		fade := 0.0, on_floor := false, pop := false) -> void:
	if frames.is_empty():
		return
	var span := float(frames.size()) / fps
	fx_anims.append({"frames": frames, "pos": pos, "t": 0.0, "fps": fps, "scale": scale,
		"life": maxf(life, span), "fade": fade, "floor": on_floor, "pop": pop})


func _update_fx_anims(delta: float) -> void:
	var i := fx_anims.size() - 1
	while i >= 0:
		var a: Dictionary = fx_anims[i]
		a.t += delta
		if a.t >= a.life:
			fx_anims.remove_at(i)
		i -= 1


## Το καρέ, η κλίμακα και η διαφάνεια ενός εφέ αυτή τη στιγμή.
static func fx_state(a: Dictionary) -> Array:
	var frames: Array = a.frames
	var i := clampi(int(a.t * a.fps), 0, frames.size() - 1)
	var s: float = a.scale
	if a.pop:
		var k := clampf(a.t / 0.18, 0.0, 1.0)
		s *= lerpf(0.2, 1.0, k) + sin(k * PI) * 0.25
	var alpha := 1.0
	if a.fade > 0.0:
		alpha = clampf((a.life - a.t) / a.fade, 0.0, 1.0)
	return [frames[i], s, alpha]


func _draw_floor_fx() -> void:
	for a in fx_anims:
		if not a.floor:
			continue
		var st := fx_state(a)
		var tex: Texture2D = st[0]
		var sc: float = st[1]
		var sz: Vector2 = tex.get_size() * sc
		var dst := Rect2((a.pos as Vector2) - sz * 0.5, sz)
		var col := Color(1, 1, 1, st[2])
		if a.has("clip"):
			# κομμένο σε ένα κελί: σκούρο χώμα από κάτω, και μόνο το κομμάτι
			# της εικόνας που πέφτει μέσα στο κελί
			var clip: Rect2 = a.clip
			var under: Color = a.get("under", Color(0.08, 0.05, 0.03, 0.22))
			draw_rect(clip, Color(under, under.a * float(st[2])))
			var inter := dst.intersection(clip)
			if inter.has_area():
				var src := Rect2((inter.position - dst.position) / sc, inter.size / sc)
				draw_texture_rect_region(tex, inter, src, col)
			continue
		draw_texture_rect(tex, dst, false, col)


## Τρέχει ως το τέλος ό,τι περιμένει στη ροή του γύρου (ρίψεις, καλέσματα,
## charges) — και όσα γεννάει το ένα για το άλλο. Για tests.
func flush_actions() -> void:
	for i in 30:
		if lobs.is_empty():
			return
		_update_lobs(5.0)


## Καθυστέρηση μέσα στη ροή του γύρου: όσο περιμένει, ο παίκτης περιμένει
## κι αυτός (όπως με τις ρίψεις). Ζει στην ίδια λίστα με τα βλήματα, αόρατο.
func after(delay: float, cb: Callable) -> void:
	lobs.append({"from": Vector2.ZERO, "to": Vector2.ZERO, "tex": null, "t": 0.0,
		"dur": maxf(delay, 0.01), "h": 0.0, "spin": 0.0, "scale": 1.0, "cb": cb, "hidden": true})
	if phase == "aim":
		phase = "boss_act"


# ---------------------------------------------------------------- αλλαγή περιοχής
# Μικρό cinematic: σβήνει σε μαύρο, στο μαύρο καθαρίζει το ταμπλό και αλλάζει
# σκηνικό, μουσική και καιρό, δείχνει το όνομα της νέας περιοχής και ξανανοίγει.

const TRANS_OUT := 0.7
const TRANS_HOLD := 0.7
const TRANS_IN := 0.7


func in_transition() -> bool:
	return transition_t >= 0.0


## Η περιοχή που ΦΑΙΝΕΤΑΙ: μένει η παλιά ως τη μέση του cinematic.
func visual_area() -> AreaDef:
	if areas.is_empty():
		return null
	return areas[clampi(visual_area_index, 0, areas.size() - 1)]


## Πόσο μαύρη είναι η οθόνη, 0..1.
func transition_alpha() -> float:
	if transition_t < 0.0:
		return 0.0
	if transition_t < TRANS_OUT:
		return transition_t / TRANS_OUT
	if transition_t < TRANS_OUT + TRANS_HOLD:
		return 1.0
	return clampf(1.0 - (transition_t - TRANS_OUT - TRANS_HOLD) / TRANS_IN, 0.0, 1.0)


func _begin_area_transition() -> void:
	transition_t = 0.0
	_trans_swapped = false
	phase = "transition"
	aiming = false
	aim_cancel = false
	banner = ""          # η ανακοίνωση της παλιάς περιοχής δεν μπαίνει στο μαύρο


func _update_transition(delta: float) -> void:
	transition_t += delta
	if not _trans_swapped and transition_t >= TRANS_OUT:
		_area_swap()
	if transition_t >= TRANS_OUT + TRANS_HOLD + TRANS_IN:
		transition_t = -1.0
		phase = "aim"
		var area := current_area()
		_announce("%s - ROUND %d" % [area.display_name if area else "", area_round()])


## Ολοκληρώνει αμέσως το cinematic (tests, ή όποιος δεν θέλει να περιμένει).
func finish_transition() -> void:
	if in_transition():
		_update_transition(TRANS_OUT + TRANS_HOLD + TRANS_IN)


## Στο μαύρο: άδειο ταμπλό, νέο σκηνικό, πρώτη σειρά της νέας περιοχής.
func _area_swap() -> void:
	_trans_swapped = true
	for b in get_tree().get_nodes_in_group("block"):
		if is_instance_valid(b):
			grid.erase(b)
			b.queue_free()
	for o in get_tree().get_nodes_in_group("orb"):
		o.queue_free()
	boss = null
	freeze_rounds = 0
	lobs.clear()
	reserved.clear()
	visual_area_index = area_index
	_apply_theme()
	_add_row()


func _paint_frozen() -> void:
	for b in grid.blocks():
		if is_instance_valid(b):
			b.self_modulate = FROZEN_TINT if freeze_rounds > 0 else Color.WHITE
			b.set_frozen(freeze_rounds > 0)


func _game_over() -> void:
	phase = "over"
	add_shake(9.0)
	paused = false
	get_tree().paused = false
	var dirty := false
	if score > int(save.get("best_score", 0)):
		save["best_score"] = score
		dirty = true
	if level > int(save.get("best_round", 0)):
		save["best_round"] = level
		dirty = true
	if dirty:
		SaveManager.save_data(save)


# ---------------------------------------------------------------- σχεδίαση

func _draw() -> void:
	_draw_field()
	# ρωγμές, μαγικοί κύκλοι: πάνω στο πάτωμα, κάτω από τους εχθρούς (που
	# είναι παιδιά του main και ζωγραφίζονται μετά από αυτό)
	_draw_floor_fx()
	_draw_frame()
	_draw_torches()
	_draw_ground()
	_draw_hud_base()
	_draw_dragon()
	_draw_aim()
	# το HUD σχεδιάζεται σε CanvasLayer, δες scripts/hud.gd


func _draw_field() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(W, H)), Color("141024"))
	var area := current_area()
	var bg: Texture2D = area.background if area else null
	# η πίστα απλώνεται ΚΑΤΩ από τη γραμμή θανάτου, μέχρι το HUD: η ζώνη του
	# δράκου είναι κομμάτι του εδάφους, όχι ξεχωριστό πέτρινο ταμπλό
	if bg:
		# Μονάδα είναι ΤΟ ΚΕΛΙ, όχι το διαθέσιμο ύψος. Το φόντο είναι πλακίδια
		# 64x64 σε COLS στήλες, οπότε ένα πλακίδιο πρέπει να βγαίνει ακριβώς
		# ένα κελί και στις δύο διαστάσεις. Τεντωμένο στο ui_top έβγαινε
		# 85.7 x 94.8: οι ραφές ξέφευγαν από το πλέγμα κατά 9px τη σειρά και
		# η διαφορά μάζευε προς τα κάτω. Ό,τι περισσεύει το κρύβει το HUD.
		#
		# Το φόντο ΕΠΑΝΑΛΑΜΒΑΝΕΤΑΙ προς τα κάτω μέχρι να φτάσει το HUD. Τα
		# κινητά είναι πιο στενόμακρα από το 720x1280 και το stretch "expand"
		# μακραίνει την οθόνη, οπότε ένα αντίγραφο σταματούσε πριν από το
		# κάστρο και άφηνε μαύρη λωρίδα. Κάθε αντίγραφο είναι ακέραιος αριθμός
		# κελιών, άρα η επανάληψη πέφτει πάνω στο πλέγμα χωρίς ραφή.
		var bg_rows := float(bg.get_height()) * COLS / float(bg.get_width())
		var bg_h := cell * bg_rows
		var y0 := PF_TOP
		while y0 < ui_top:
			draw_texture_rect(bg, Rect2(pf_left, y0, PF_W, bg_h), false, area.tint)
			y0 += bg_h
	else:
		var steps := 14
		for i in steps:
			var f := float(i) / float(steps)
			draw_rect(Rect2(0, H * f * 0.75, W, H * 0.75 / steps + 1.0),
				Color("1a1b3a").lerp(Color("3d2a4f"), f))
		draw_rect(Rect2(0, floor_y - 170, W, ui_top - floor_y + 170), Color("23402f"))
	for c in range(1, COLS):
		var gx := pf_left + c * cell
		draw_line(Vector2(gx, PF_TOP), Vector2(gx, floor_y), Color(1, 1, 1, 0.045), 1.0)


func _draw_frame() -> void:
	var top := PF_TOP - 36.0

	# ζωγραφισμένο πλαίσιο, όταν υπάρχουν τα γραφικά
	if tex_frame_left and tex_frame_right and tex_frame_top:
		draw_texture_rect(tex_frame_left,
			Rect2(frame_left(), top, BORDER, H - top), false)
		draw_texture_rect(tex_frame_right,
			Rect2(pf_right, top, BORDER, H - top), false)
		draw_texture_rect(tex_frame_top,
			Rect2(frame_left(), top, frame_right() - frame_left(), 40.0), false)
		return

	var stone := Color("58596e")
	var dark := Color("3a3b4e")
	var bh := 30.0
	for side in 2:
		var x0 := frame_left() if side == 0 else pf_right
		draw_rect(Rect2(x0, top, BORDER, H - top), dark)
		var row := 0
		var y := top
		while y < H:
			var off := 0.0 if row % 2 == 0 else 8.0
			draw_rect(Rect2(x0 + 4.0 + off * 0.3, y + 3.0, BORDER - 10.0, bh - 6.0), stone)
			y += bh
			row += 1
	draw_rect(Rect2(frame_left(), top, frame_right() - frame_left(), 36.0), dark)
	var x2 := frame_left()
	while x2 < frame_right():
		draw_rect(Rect2(x2 + 5.0, top + 4.0, 44.0, 28.0), stone)
		x2 += 58.0


## Δείκτης καρέ σε βρόχο ping-pong (0,1,..,n-1,n-2,..,1). Τα καρέ που έρχονται
## από το PixelLab δεν κλείνουν κύκλο — το τελευταίο είναι πιο φωτεινό από το
## πρώτο — οπότε ευθύς βρόχος θα πηδούσε στο γύρισμα. Με το `off` οι δύο
## πλευρές της οθόνης τρέχουν εκτός φάσης, να μην τρεμοπαίζουν μαζί.
func _pingpong(n: int, fps: float, off := 0.0) -> int:
	if n < 2:
		return 0
	var span := (n - 1) * 2
	var i := int(floor((t + off) * fps)) % span
	return i if i < n else span - i


## Καθρεφτίζει ένα rect οριζόντια. Το draw_texture_rect ΔΕΝ έχει όρισμα flip:
## το πέμπτο του είναι `transpose`, που γυρίζει την εικόνα 90° — περασμένο
## κατά λάθος ως flip έστριβε τις δεξιές δάδες και το λάβαρο στο πλάι.
## Το αρνητικό πλάτος είναι ο σωστός τρόπος. Το Godot κρατάει το rect στην
## ίδια θέση (position .. position+|size|) και απλώς γυρίζει την εικόνα —
## με μετατόπιση κατά size.x οι δεξιές δάδες έβγαιναν ένα BORDER έξω από το ξύλο.
func _mirror(r: Rect2, flip: bool) -> Rect2:
	if not flip:
		return r
	return Rect2(r.position.x, r.position.y, -r.size.x, r.size.y)


## Δάδες και λάβαρα. Ήταν ψημένα μέσα στο frame_left.png· βγήκαν από εκεί ώστε
## να κινούνται, και ξαναμπαίνουν εδώ στην ίδια θέση. Ο υπολογισμός ακολουθεί
## τη γεωμετρία με την οποία το _draw_frame() τεντώνει τη λωρίδα του πλαισίου.
func _draw_torches() -> void:
	if tex_frame_left == null:
		return
	var top := PF_TOP - 36.0
	var sy := (H - top) / (DECO_ROWS * DECO_TILE)
	for side in 2:
		var x := frame_left() if side == 0 else pf_right
		for r in DECO_TORCH_ROWS:
			if torch_frames.is_empty():
				continue
			# δεξιά μισό βήμα πίσω, ώστε οι τέσσερις δάδες να μη χτυπάνε μαζί
			var tt: Texture2D = torch_frames[_pingpong(
				torch_frames.size(), TORCH_FPS, 0.0 if side == 0 else 0.37)]
			var th := float(tt.get_height()) * sy
			draw_texture_rect(tt, _mirror(
				Rect2(x, top + r * DECO_TILE * sy, BORDER, th), side == 1), false)
		if tex_banner:
			_draw_banner(x, top + DECO_BANNER_ROW * DECO_TILE * sy, sy, side == 1)


## Το λάβαρο κυματίζει. Σχεδιάζεται σε οριζόντιες λωρίδες με ημιτονοειδή
## μετατόπιση που μεγαλώνει προς τα κάτω: η κορυφή είναι δεμένη στο κοντάρι,
## το ελεύθερο άκρο ταξιδεύει πιο πολύ. Προτιμήθηκε από καρέ γιατί το κύμα
## πρέπει να κυλάει συνεχόμενα, και δεν κοστίζει τίποτα σε γραφικά.
func _draw_banner(x: float, y: float, sy: float, flip: bool) -> void:
	var tw := float(tex_banner.get_width())
	var th := float(tex_banner.get_height())
	var rows := 16
	var step := th / float(rows)
	for i in rows:
		var f := float(i) / float(rows)
		var dx := sin(t * 2.0 - f * 3.4) * (f * f * 4.0)
		draw_texture_rect_region(tex_banner, _mirror(
			Rect2(x + dx, y + i * step * sy, BORDER, step * sy + 1.0), flip),
			Rect2(0, i * step, tw, step))


## Η ζώνη του δράκου δεν έχει δικό της ταμπλό — το έδαφος της πίστας συνεχίζει
## εκεί, και από πάνω κάθεται η ηφαιστειακή φωλιά (art/lair.png, βλ.
## tools/build_lair.gd). Τρέχει ΠΡΙΝ τον δράκο, ώστε αυτός να πατάει μπροστά
## της. Το texture είναι σε art pixels και δείχνεται στο x2, ακέραια.
func _draw_ground() -> void:
	draw_line(Vector2(pf_left, floor_y), Vector2(pf_right, floor_y),
		Color(1, 0.4, 0.3, 0.22), 2.0)
	if not lair_frames.is_empty():
		var lt: Texture2D = lair_frames[_pingpong(lair_frames.size(), LAIR_FPS)]
		var lw := float(lt.get_width()) * LAIR_SCALE
		var lh := float(lt.get_height()) * LAIR_SCALE
		# κεντραρισμένη, όχι δεμένη στο pf_left: η φωλιά είναι πλατύτερη από
		# την πίστα και τα ηφαίστεια πατάνε πάνω στα ξύλινα πλαϊνά
		draw_texture_rect(lt, Rect2((W - lw) * 0.5, ui_top - lh, lw, lh), false)


## Λωρίδα σε x2 που πιάνει από x0 ως x1: η αριστερή άκρη του texture μένει
## ως έχει, η δεξιά είναι το καθρέφτισμά της, και η μέση επαναλαμβάνεται με
## το τελευταίο κομμάτι κομμένο — ποτέ τεντωμένο. Τα κομμάτια του HUD είναι
## ΜΙΣΑ πάνελ (η δεξιά τους άκρη ήταν το κέντρο), γι' αυτό η δεξιά άκρη δεν
## παίρνεται από το ίδιο το texture. `src` είναι το κομμάτι που χρησιμοποιείται.
## Static με τον καμβά ως όρισμα, ώστε να τη μοιράζεται και το hud.gd.
static func strip2(ci: CanvasItem, t: Texture2D, src: Rect2, x0: float, x1: float, y: float) -> void:
	var cap := int(src.size.x * 0.12)
	var h := src.size.y
	# η μέση πρώτα: το τελευταίο κομμάτι στρογγυλεύει ΠΡΟΣ ΤΑ ΠΑΝΩ και χώνεται
	# κάτω από την άκρη — με int() έμενε κενό μισού pixel όταν το πλάτος
	# δεν ήταν ακέραιο, και φαινόταν το φόντο σαν λεπτή γραμμή
	var body := int(src.size.x) - cap * 2
	var x := x0 + cap * 2
	var end := x1 - cap * 2
	while x < end:
		var bw := mini(body, ceili((end - x) / 2.0))
		ci.draw_texture_rect_region(t, Rect2(x, y, bw * 2, h * 2),
			Rect2(src.position.x + cap, src.position.y, bw, h))
		x += bw * 2
	ci.draw_texture_rect_region(t, Rect2(x0, y, cap * 2, h * 2),
		Rect2(src.position.x, src.position.y, cap, h))
	# αρνητικό πλάτος = καθρέφτισμα στην ΙΔΙΑ θέση (x1-2cap .. x1)
	ci.draw_texture_rect_region(t, Rect2(x1 - cap * 2, y, -cap * 2, h * 2),
		Rect2(src.position.x, src.position.y, cap, h))


## Το φόντο της κάτω μπάρας: η κορυφή του τείχους ως σκηνικό, και πάνω της
## τα δύο πάνελ όπου κάθονται τα κουμπιά. Ζωγραφίζεται εδώ και όχι στο HUD
## ώστε ο δράκος, που κάθεται ανάμεσα στα πάνελ, να μένει ΜΠΡΟΣΤΑ τους.
## Τα κουμπιά και τα κείμενα από πάνω τα βάζει το hud.gd.
func _draw_hud_base() -> void:
	if tex_hud_wall == null or tex_hud_panel == null:
		return
	var ws := tex_hud_wall.get_size()
	var by := ui_top - 48.0
	draw_rect(Rect2(0, by + 16.0, W, H - by), Color("232226"))
	strip2(self, tex_hud_wall, Rect2(Vector2.ZERO, ws), 0.0, W, by)
	# ψηλές οθόνες: το τείχος συνεχίζει με τις κάτω σειρές του, επαναλαμβανόμενες
	var band := int(ws.y * 0.28)
	var src := Rect2(0, ws.y - band, ws.x, band)
	var y := by + ws.y * 2.0
	while y < H:
		strip2(self, tex_hud_wall, src, 0.0, W, y)
		y += band * 2.0
	# δεξί πάνελ = καθρέφτισμα του αριστερού (αρνητικό πλάτος, ίδια θέση)
	var lr := hud_panel_rect(false)
	var rr := hud_panel_rect(true)
	draw_texture_rect(tex_hud_panel, lr, false)
	draw_texture_rect(tex_hud_panel, Rect2(rr.position, Vector2(-rr.size.x, rr.size.y)), false)


## Ποια κατάσταση δείχνει ο δράκος τώρα. Η φλόγα ανάβει ΜΟΝΟ όσο φεύγουν
## μπάλες από το στόμα — όχι όσο τριγυρνάνε στην πίστα, που κρατάει πολύ
## περισσότερο και θα την άφηνε αναμμένη σχεδόν μόνιμα.
func dragon_phase() -> String:
	if phase == "shoot" and to_fire <= 0:
		return "aim"
	return phase


## Η φλόγα της εναλλαγής, πάνω από τον δράκο. Παίζει μία φορά προς τα εμπρός
## και σβήνει στο τέλος, ώστε να μη «γδέρνει» το καρέ όπου αλλάζει η μορφή.
func _draw_awaken(base: Vector2, dragon_w: float) -> void:
	if awaken_t <= 0.0:
		return
	if dragon and dragon.awaken_style == "skull":
		_draw_awaken_skull(base, dragon_w)
		return
	if awaken_frames.is_empty():
		return
	var f := 1.0 - awaken_t / AWAKEN_TIME          # 0 στην αρχή, 1 στο τέλος
	var i := clampi(int(f * awaken_frames.size()), 0, awaken_frames.size() - 1)
	var tex := awaken_frames[i]
	var w := dragon_w * 1.5                        # ξεπερνάει το κεφάλι, να το τυλίγει
	var h := w * float(tex.get_height()) / float(tex.get_width())
	# Τα καρέ είναι ζωγραφισμένα σε φωτιά, οπότε ο ember τα δείχνει ατόφια
	# (awaken_tint λευκό) και ο death τα βάφει πράσινα. Δεν χρησιμοποιείται το
	# accent εδώ: είναι πολλαπλασιασμός, και πορτοκαλί πάνω σε πορτοκαλί θα
	# σκούραινε τη φλόγα του ember χωρίς λόγο.
	var tint: Color = dragon.awaken_tint if dragon else Color.WHITE
	tint.a = clampf(awaken_t / (AWAKEN_TIME * 0.4), 0.0, 1.0)
	draw_texture_rect(tex, Rect2(base.x - w * 0.5, base.y - h, w, h), false, tint)


## Καπνός σκότους που βγαίνει αδιάκοπα από τις άδειες κόγχες. Τρέχει με τον
## χρόνο, οπότε δίνει κίνηση σε μια μορφή που έχει ένα μόνο καρέ: τα μάτια
## πάλλονται, και τολύπες ανεβαίνουν και σβήνουν σε ανεξάρτητους ρυθμούς ώστε
## να μην πάλλονται οι δύο πλευρές συγχρονισμένα.
func _draw_eye_smoke(w: float, h: float, open_eyes := false) -> void:
	var pulse := 0.72 + sin(t * 2.6) * 0.28
	for side in 2:
		# ρητός float: από λίστα το στοιχείο βγαίνει Variant και το := δεν
		# μπορεί να συμπεράνει τύπο στους υπολογισμούς παρακάτω
		var sx := -1.0 if side == 0 else 1.0
		var e := Vector2(sx * w * 0.16, -h * 0.55)
		# η ίδια η κόγχη: βαθύ μαύρο που ανασαίνει. ΟΧΙ όταν βαράει: τότε τα
		# καρέ έχουν άσπρες ίριδες μέσα στις κόγχες, και ο συμπαγής μαύρος
		# πυρήνας θα τις σκέπαζε — μένει μόνο η αραιή άλω γύρω τους.
		if not open_eyes:
			draw_circle(e, (7.0 + pulse * 3.0), Color(0, 0, 0, 0.55 + pulse * 0.25))
		draw_circle(e, (13.0 + pulse * 5.0), Color(0.03, 0.0, 0.06, 0.20 * pulse))
		# τρεις τολύπες, η καθεμία με δική της φάση
		# ανεβαίνουν αρκετά ψηλά ώστε να βγουν πάνω από το κεφάλι: μέσα στο
		# περίγραμμά του, που είναι ήδη σχεδόν μαύρο, δεν φαίνονταν καθόλου
		for k in 4:
			var ph := fmod(t * 0.42 + float(k) * 0.27 + (0.14 if sx > 0.0 else 0.0), 1.0)
			var rise := ph * h * 0.62
			var drift := sx * ph * w * 0.12 + sin(ph * 4.4 + float(k)) * w * 0.05
			var fade := (1.0 - ph) * 0.42 * minf(ph * 4.0, 1.0)
			draw_circle(e + Vector2(drift, -rise), 5.0 + ph * 15.0,
				Color(0.05, 0.0, 0.09, fade))


## Αύρα μεταμόρφωσης για τον θάνατο: μια μαύρη νεκροκεφαλή που ανοίγει προς τα
## έξω μέσα σε σκοτεινή δίνη, αντί για φλόγα. Δεν χρειάζεται δικά της καρέ —
## είναι το ίδιο το κεφάλι του δράκου, βαμμένο μαύρο, σε μεγέθυνση που τρέχει
## με τον χρόνο. Γι' αυτό δούλεψε χωρίς νέα γραφικά.
func _draw_awaken_skull(base: Vector2, dragon_w: float) -> void:
	var f := 1.0 - awaken_t / AWAKEN_TIME          # 0 στην αρχή, 1 στο τέλος
	var fade := clampf(awaken_t / (AWAKEN_TIME * 0.5), 0.0, 1.0)
	var c := base + Vector2(0, -dragon_w * 0.42)

	# η δίνη: δαχτυλίδια σκότους που ανοίγουν και αραιώνουν
	for i in 4:
		var r := dragon_w * (0.30 + 0.48 * f) + i * 9.0
		draw_circle(c, r, Color(0.03, 0.0, 0.05, fade * 0.16 / float(i + 1)))
	# λίγη πράσινη ανταύγεια στο χείλος, ώστε να δένει με τον δράκο
	draw_arc(c, dragon_w * (0.30 + 0.48 * f), 0.0, TAU, 48,
		Color(0.35, 0.75, 0.2, fade * 0.22), 2.0)

	# η νεκροκεφαλή: το κεφάλι του δράκου σε μαύρη σιλουέτα, να μεγαλώνει
	var tex: Texture2D = dragon.sprite_idle if dragon else null
	if tex == null:
		return
	var w := dragon_w * (0.72 + 0.62 * f)
	var h := w * float(tex.get_height()) / float(tex.get_width())
	draw_texture_rect(tex, Rect2(c.x - w * 0.5, c.y - h * 0.5, w, h), false,
		Color(0.0, 0.0, 0.0, fade * 0.85))


func _draw_dragon() -> void:
	var base := dragon_base()
	var dg := active_dragon()
	var dt: Texture2D = dg.frame_for(dragon_phase(), aiming, t) if dg else null
	if dt:
		var w: float = dg.draw_width
		var h := w * float(dt.get_height()) / float(dt.get_width())

		var dph := dragon_phase()
		var bob := 0.0
		var breathe := 1.0
		if dph == "aim" and not aiming:
			bob = sin(t * 2.1) * 2.5                      # ήρεμη ανάσα
			breathe = 1.0 + sin(t * 2.1) * 0.018
		elif dph == "aim" and aiming:
			bob = 3.0 + sin(t * 26.0) * 0.9               # τρέμουλο έντασης

		# η κλωτσιά σπρώχνει το κεφάλι αντίθετα από τη βολή
		var kick := -aim_dir * recoil * 9.0
		var pivot := base + Vector2(0, bob) + kick

		draw_set_transform(pivot, tilt, Vector2(1.0, breathe))
		draw_texture_rect(dt, Rect2(-w * 0.5, -h, w, h), false, dg.tint)
		# Οι άδειες κόγχες καπνίζουν ΣΥΝΕΧΩΣ, όχι μόνο στη βολή. Η μορφή χωρίς
		# μάσκα έχει ένα μόνο καρέ όσο λείπουν τα generations, οπότε χωρίς αυτό
		# στεκόταν εντελώς ακίνητη· ο καπνός της δίνει την κίνηση που θα είχε.
		if dg.dark_eyes:
			_draw_eye_smoke(w, h, dph == "shoot")
		# λάμψη στο στόμα την ώρα που φεύγει η μπάλα — ή, για όσους έχουν άδειες
		# κόγχες, σκοτάδι που χύνεται από τα μάτια αντί για φως από το στόμα
		if recoil > 0.05:
			var g := recoil
			if dg.dark_eyes:
				# Το σκοτάδι ΧΥΝΕΤΑΙ προς τα έξω και κάτω, πέρα από το
				# περίγραμμα του κεφαλιού. Μέσα στο ίδιο το πρόσωπο δεν
				# διαβαζόταν: η μορφή χωρίς μάσκα είναι ήδη σχεδόν μαύρη,
				# οπότε μαύρο πάνω σε μαύρο χανόταν.
				for sx in [-1.0, 1.0]:
					var e := Vector2(sx * w * 0.16, -h * 0.55)
					for k in range(2, 9):     # από λίγο κάτω από την κόγχη, όχι πάνω της
						var t2 := float(k) / 8.0
						# κυλάει προς τα κάτω-έξω, μεγαλώνοντας και αραιώνοντας
						var p := e + Vector2(sx * t2 * w * 0.46, t2 * h * 0.50)
						var r := (7.0 + t2 * 26.0) * g
						draw_circle(p, r, Color(0.04, 0.0, 0.07, (0.60 - t2 * 0.44) * g))
					# χωρίς συμπαγή μαύρο πυρήνα: στη βολή τα μάτια έχουν άσπρες ίριδες
			else:
				draw_circle(Vector2(0, -h * 0.45), 26.0 * g, Color(_accent(1.0), 0.30 * g))
				draw_circle(Vector2(0, -h * 0.45), 12.0 * g, Color(1.0, 0.92, 0.70, 0.55 * g))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_awaken(base, w)
		return

	var px := 7.0
	var map := [
		"......RR....", ".WW..RRRR...", ".WWW.RRERR..", ".WWWWRRRRRR.",
		"..WWRRRRRR..", "...RRRRRR...", "..T.RR.RR...", "....RR.RR..."
	]
	var o := base + Vector2(-map[0].length() * px * 0.5, -map.size() * px)
	for r in map.size():
		var line: String = map[r]
		for c in line.length():
			var ch_ := line[c]
			if ch_ == ".":
				continue
			var col := Color("d4453a")
			if ch_ == "W":
				col = Color("a33028")
			elif ch_ == "E":
				col = Color.WHITE
			elif ch_ == "T":
				col = Color("8e2a22")
			draw_rect(Rect2(o + Vector2(c * px, r * px), Vector2(px, px)), col)


func _draw_aim() -> void:
	if phase != "aim" or not aiming or aim_cancel:
		return
	# ξεκινάει από εκεί που γεννιούνται πραγματικά οι μπάλες, όχι από το
	# σχεδιασμένο στόμα — τα δύο απέχουν ελάχιστα, αλλά η γραμμή πρέπει να
	# λέει την αλήθεια για την τροχιά
	var p := Vector2(launch_x, floor_y - 18.0)
	var v := aim_dir
	for i in 64:
		p += v * 16.0
		if p.x < pf_left + 8.0 or p.x > pf_right - 8.0:
			v.x = -v.x
			p.x = clampf(p.x, pf_left + 8.0, pf_right - 8.0)
		if p.y < PF_TOP:
			break
		if i % 2 == 0:
			draw_circle(p, 3.0, Color(1.0, 0.75, 0.35, 0.7))


