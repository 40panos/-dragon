class_name MusicPlayer
extends Node
## Soundtrack με ομαλό loop. Δύο AudioStreamPlayer εναλλάξ: λίγο πριν τελειώσει
## το κομμάτι, ο δεύτερος ξεκινάει από την αρχή και τα δύο κάνουν crossfade.
##
## Το απλό loop του mp3 ακουγόταν σαν κόψιμο: το κομμάτι του Goblin Land
## τελειώνει στο φουλ και σβήνει μέσα σε ~0.15s, ενώ ξεκινάει αρκετά πιο
## ήσυχα. Με το crossfade το τέλος σβήνει μέσα στην αρχή.

const XFADE := 2.5          # δευτερόλεπτα που επικαλύπτονται τέλος και αρχή

var stream: AudioStream = null
var volume := 1.0           # γραμμική ένταση, 0..1
var paused := false

var _cur: AudioStreamPlayer
var _next: AudioStreamPlayer
var _fade := -1.0           # πρόοδος του crossfade 0..1· αρνητικό = κανένα


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_cur = AudioStreamPlayer.new()
	_next = AudioStreamPlayer.new()
	add_child(_cur)
	add_child(_next)


## Βάζει κομμάτι. Αν είναι ήδη αυτό, δεν το ξεκινάει από την αρχή.
func play_stream(s: AudioStream) -> void:
	if s == stream:
		if s and not _cur.playing and not paused:
			_cur.play()
		return
	stream = s
	_fade = -1.0
	_cur.stop()
	_next.stop()
	if s == null:
		return
	# το loop το κάνουμε εμείς· αλλιώς το mp3 θα ξαναρχίζε μόνο του, με κόψιμο
	if s is AudioStreamMP3:
		s.loop = false
	elif s is AudioStreamOggVorbis:
		s.loop = false
	_cur.stream = s
	_next.stream = s
	_apply()
	if is_inside_tree():
		_cur.play()


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	_apply()


func set_paused(p: bool) -> void:
	paused = p
	_cur.stream_paused = p
	_next.stream_paused = p


func is_crossfading() -> bool:
	return _fade >= 0.0


func _process(delta: float) -> void:
	if stream == null or paused:
		return
	tick(delta, _cur.get_playback_position(), _cur.playing)


## Η λογική του loop με ρητή θέση, ώστε να ελέγχεται χωρίς ήχο (tests).
func tick(delta: float, pos: float, playing: bool) -> void:
	var length := stream.get_length()
	if _fade < 0.0:
		if length > XFADE * 2.0 and pos >= length - XFADE:
			_fade = 0.0
			if is_inside_tree():
				_next.play(0.0)
		elif not playing and is_inside_tree():
			_cur.play(0.0)       # κομμάτι πιο κοντό από το crossfade, ή κόπηκε
	if _fade >= 0.0:
		_fade += delta / XFADE
		if _fade >= 1.0:
			_cur.stop()
			var t := _cur
			_cur = _next
			_next = t
			_fade = -1.0
	_apply()


## Ίσης ισχύος crossfade (cos/sin), ώστε στη μέση να μη βουλιάζει η ένταση.
func _apply() -> void:
	var a := 1.0
	var b := 0.0
	if _fade >= 0.0:
		var f := clampf(_fade, 0.0, 1.0)
		a = cos(f * PI * 0.5)
		b = sin(f * PI * 0.5)
	_cur.volume_db = linear_to_db(maxf(volume * a, 0.0001))
	_next.volume_db = linear_to_db(maxf(volume * b, 0.0001))


## Η τελική ένταση του κύριου player — για τα tests.
func current_volume() -> float:
	return db_to_linear(_cur.volume_db)
