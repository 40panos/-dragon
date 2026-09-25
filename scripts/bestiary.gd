extends Node2D
## Το Book (bestiary) και οι ειδοποιήσεις «νέος εχθρός», με τη λογική του
## Kingdom Rush: την πρώτη φορά που εμφανίζεται ένας τύπος εχθρού βγαίνει στην
## άκρη ένα μετάλλιο με «!». Πάτημα = παγώνει το παιχνίδι και ανοίγει την κάρτα
## του, από όπου πας και στο Book. Το Book έχει μια καρτέλα ανά περιοχή· όσοι
## δεν έχουν φανεί ακόμα δείχνονται σκοτεινές σιλουέτες.
##
## Ζει στο ίδιο CanvasLayer με το HUD, από πάνω του. Τα πατήματα τα προωθεί το
## main (press), και όσο είναι ανοιχτό κάτι εδώ το main μένει παγωμένο.
## Κάθε κείμενο είναι ASCII, όπως παντού στην οθόνη.

const PAGE := preload("res://art/book_page.png")        # 9-slice: δέρμα, μπρούντζος, περγαμηνή
const MEDALLION := preload("res://art/book_medallion.png")  # δαχτυλίδι, διάφανη μέση
const ALERT := preload("res://art/book_alert.png")      # το «!»
const TAB := preload("res://art/book_tab.png")          # σελιδοδείκτης καρτέλας, 3-slice
const CLOSE := preload("res://art/book_close.png")
const ICON := preload("res://art/book_icon.png")
const BTN := preload("res://art/hud_btn.png")
const PLATE := preload("res://art/hud_plate.png")

const INK := Color("3b2a1c")        # κείμενο πάνω στην περγαμηνή
const RED := Color("7a2216")        # τίτλοι
const FADED := Color("8a7458")      # δευτερεύον κείμενο
const BONE := Color("eadfc4")       # κείμενο πάνω σε σκούρο
const HOLE := Color("16121a")       # φόντο πίσω από τον εχθρό στο μετάλλιο
const HOLE_UNSEEN := Color("6b5a47")  # ...και πίσω από σιλουέτα: αλλιώς μαύρο σε μαύρο

const NOTICE_MAX := 3               # όσα φαίνονται μαζί· τα υπόλοιπα περιμένουν σειρά
const PAGE_CORNER := 12             # art pixels της γωνίας στο book_page
const BOOK_COLS := 3

var m
## Ειδοποιήσεις που περιμένουν πάτημα, με τη σειρά που εμφανίστηκαν οι εχθροί.
var notices: Array[EnemyType] = []
var _born: Array[float] = []
## "" κλειστό · "card" κάρτα από ειδοποίηση · "book" η λίστα · "entry" κάρτα μέσα από το Book
var view := ""
var card: EnemyType
var book_area := 0
var _parchment := Color("f1dcb4")


func _ready() -> void:
	var im := PAGE.get_image()
	_parchment = im.get_pixel(im.get_width() / 2, im.get_height() / 2)


func _process(_delta: float) -> void:
	queue_redraw()


func is_open() -> bool:
	return view != ""


# ---------------------------------------------------------------- δεδομένα

func is_seen(id: String) -> bool:
	return id in m.save.get("seen_enemies", [])


## Το καλεί το main για κάθε εχθρό που μπαίνει στο ταμπλό. Την πρώτη φορά
## που φαίνεται ένας τύπος, τον γράφει στο save και βγάζει ειδοποίηση.
func saw(type: EnemyType) -> void:
	if type == null or is_seen(type.id):
		return
	var ids: Array = m.save.get("seen_enemies", []).duplicate()
	ids.append(type.id)
	m.save["seen_enemies"] = ids
	SaveManager.save_data(m.save)
	notices.append(type)
	_born.append(m.t)


## Σε ποια περιοχή «ανήκει» ένας εχθρός: στην πρώτη όπου εμφανίζεται. Οι
## περιοχές μοιράζονται εχθρούς, και χωρίς αυτό το Book θα τους έδειχνε δύο φορές.
func area_of(id: String) -> int:
	for i in m.areas.size():
		for e in _area_all(m.areas[i]):
			if e.id == id:
				return i
	return -1


func _area_all(a: AreaDef) -> Array[EnemyType]:
	var out: Array[EnemyType] = []
	var pool := a.enemies.duplicate()
	pool.sort_custom(func(x, y): return x.min_round < y.min_round)
	out.append_array(pool)
	out.append_array(a.minions)
	if a.boss:
		out.append(a.boss)
	return out


## Οι εχθροί μιας σελίδας του Book: όσοι πρωτοεμφανίζονται σε αυτή την περιοχή.
func entries(area_i: int) -> Array[EnemyType]:
	var out: Array[EnemyType] = []
	if area_i < 0 or area_i >= m.areas.size():
		return out
	var ids := {}
	for e in _area_all(m.areas[area_i]):
		if not ids.has(e.id) and area_of(e.id) == area_i:
			ids[e.id] = true
			out.append(e)
	return out


# ---------------------------------------------------------------- γεωμετρία

func book_button_rect() -> Rect2:
	var mr: Rect2 = m.menu_rect()
	return Rect2(mr.end.x + 8.0, mr.position.y, mr.size.x, mr.size.y)


func notice_rect(i: int) -> Rect2:
	var s := MEDALLION.get_size() * 2.0
	return Rect2(m.frame_left() + 4.0, m.PF_TOP + 14.0 + i * (s.y + 20.0), s.x, s.y)


func card_rect() -> Rect2:
	var w := 580.0
	var h := 560.0
	var cx: float = (m.frame_left() + m.frame_right()) * 0.5
	return Rect2(cx - w * 0.5, m.PF_TOP + 30.0, w, h)


func book_rect() -> Rect2:
	var x: float = m.frame_left() + 16.0
	return Rect2(x, 24.0, m.frame_right() - 16.0 - x, m.ui_top - 32.0)


func close_rect(panel: Rect2) -> Rect2:
	var s := CLOSE.get_size() * 2.0
	return Rect2(panel.end.x - s.x - 18.0, panel.position.y + 18.0, s.x, s.y)


## Τα κουμπιά στο κάτω μέρος της κάρτας: [0] αριστερό, [1] δεξί.
func card_button_rect(i: int) -> Rect2:
	var c := card_rect()
	var s := PLATE.get_size() * 2.0
	var gap := 24.0
	var x := c.get_center().x - s.x - gap * 0.5 + i * (s.x + gap)
	return Rect2(x, c.end.y - s.y - 34.0, s.x, s.y)


func tab_rect(i: int) -> Rect2:
	var b := book_rect()
	var x := b.position.x + 36.0
	for k in i:
		x += _tab_w(k) + 8.0
	return Rect2(x, b.position.y + 100.0, _tab_w(i), TAB.get_height() * 2.0)


func _tab_w(i: int) -> float:
	var name_: String = m.areas[i].display_name.to_upper()
	# ζυγό ακέραιο πλάτος, ώστε η καρτέλα να κάθεται πάνω στο πλέγμα των art pixels
	var w: float = m.font.get_string_size(name_, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 56.0
	return ceilf(w / 2.0) * 2.0


func entry_rect(i: int) -> Rect2:
	var b := book_rect()
	var cw := (b.size.x - 72.0) / BOOK_COLS
	var ch := 170.0
	return Rect2(b.position.x + 36.0 + (i % BOOK_COLS) * cw,
		b.position.y + 170.0 + (i / BOOK_COLS) * ch, cw, ch)


# ---------------------------------------------------------------- πατήματα

## Επιστρέφει true αν το πάτημα ήταν δικό του. Όσο είναι ανοιχτό κάτι, όλα.
func press(p: Vector2) -> bool:
	match view:
		"card", "entry":
			if close_rect(card_rect()).has_point(p):
				_back()
			elif card_button_rect(0).has_point(p) and view == "card":
				_open_book(area_of(card.id))
			elif card_button_rect(1).has_point(p):
				_back()
			return true
		"book":
			if close_rect(book_rect()).has_point(p):
				_close()
				return true
			for i in m.areas.size():
				if tab_rect(i).has_point(p):
					book_area = i
					return true
			var list := entries(book_area)
			for i in list.size():
				if entry_rect(i).has_point(p) and is_seen(list[i].id):
					card = list[i]
					view = "entry"
			return true
	for i in mini(notices.size(), NOTICE_MAX):
		if notice_rect(i).has_point(p):
			card = notices[i]
			notices.remove_at(i)
			_born.remove_at(i)
			view = "card"
			get_tree().paused = true
			return true
	if book_button_rect().has_point(p):
		_open_book(m.area_index)
		return true
	return false


func _open_book(area_i: int) -> void:
	book_area = clampi(area_i, 0, maxi(m.areas.size() - 1, 0))
	view = "book"
	get_tree().paused = true


## Πίσω: από κάρτα του Book στη λίστα, αλλιώς κλείσιμο.
func _back() -> void:
	if view == "entry":
		view = "book"
	else:
		_close()


func _close() -> void:
	view = ""
	card = null
	# αν ο παίκτης είχε πατήσει παύση πριν, μένει σε παύση
	get_tree().paused = m.paused


# ---------------------------------------------------------------- σχέδιο

func _draw() -> void:
	if m == null:
		return
	_draw_book_button()
	_draw_notices()
	if view == "":
		return
	draw_rect(Rect2(0, 0, m.W, m.H), Color(0.03, 0.02, 0.05, 0.72))
	if view == "book":
		_draw_book()
	else:
		_draw_card()


func _draw_book_button() -> void:
	var r := book_button_rect()
	draw_texture_rect(BTN, r, false)
	var s := ICON.get_size() * 2.0
	draw_texture_rect(ICON, Rect2(r.get_center() - s * 0.5, s), false)
	if not notices.is_empty():
		# μικρό «!» και πάνω στο Book, όσο υπάρχουν αδιάβαστοι εχθροί
		var a := ALERT.get_size() * 2.0
		draw_texture_rect(ALERT, Rect2(r.end - a * 0.75, a), false)


## Το σχέδιο ενός εχθρού σε x2 (x1 για ό,τι είναι φαρδύτερο από κελί, π.χ. boss),
## κεντραρισμένο. Σιλουέτα όταν δεν έχει φανεί ακόμα.
func _draw_enemy(e: EnemyType, center: Vector2, scale: float, silhouette := false) -> void:
	var tex: Texture2D = e.sprite
	if e.frames_idle.size() > 0:
		tex = e.frames_idle[int(m.t * e.fps_idle) % e.frames_idle.size()]
	if tex == null:
		return
	var s := tex.get_size() * scale
	var tint := Color(0, 0, 0, 0.9) if silhouette else Color.WHITE
	draw_texture_rect(tex, Rect2((center - s * 0.5).round(), s), false, tint)


## Το πρόσωπο του εχθρού για το μετάλλιο, σε x2. Ό,τι είναι φαρδύτερο από
## κελί (boss) δεν χωράει ολόκληρο· κόβεται ένα 26x26 γύρω από το κεφάλι, αντί
## να μικρύνει σε άλλη κλίμακα pixel. 26 και όχι 32: το σχέδιο του boss δεν έχει
## διάφανες γωνίες, και σε x2 οι γωνίες ενός 32x32 βγαίνουν έξω από το δαχτυλίδι.
func _draw_face(e: EnemyType, center: Vector2, silhouette := false) -> void:
	var tex: Texture2D = e.sprite
	if e.frames_idle.size() > 0:
		tex = e.frames_idle[int(m.t * e.fps_idle) % e.frames_idle.size()]
	if tex == null:
		return
	var ts := tex.get_size()
	var src := Rect2(Vector2.ZERO, ts)
	if ts.x > 32.0:
		src = Rect2(floorf((ts.x - 26.0) * 0.5), maxf(0.0, floorf((ts.y - 26.0) * 0.5) - 8.0), 26, 26)
	var s := src.size * 2.0
	var tint := Color(0, 0, 0, 0.9) if silhouette else Color.WHITE
	draw_texture_rect_region(tex, Rect2((center - s * 0.5).round(), s), src, tint)


## Εχθρός μέσα στο μετάλλιο: σκούρα μέση, ο εχθρός, το δαχτυλίδι από πάνω.
func _draw_medallion(e: EnemyType, r: Rect2, silhouette := false) -> void:
	var c := r.get_center()
	draw_circle(c, r.size.x * 0.36, HOLE_UNSEEN if silhouette else HOLE)
	_draw_face(e, c, silhouette)
	draw_texture_rect(MEDALLION, r, false)


func _draw_notices() -> void:
	for i in mini(notices.size(), NOTICE_MAX):
		var r := notice_rect(i)
		var age: float = m.t - _born[i]
		# σκάει προς τα έξω και κάθεται· μετά μια ανεπαίσθητη ανάσα
		var s := 1.0
		if age < 0.35:
			var k := age / 0.35
			s = sin(k * PI * 0.5) * 1.12 - sin(k * PI) * 0.05
		else:
			s = 1.0 + 0.03 * sin((m.t - _born[i]) * 4.0)
		draw_set_transform(r.get_center(), 0.0, Vector2(s, s))
		var local := Rect2(-r.size * 0.5, r.size)
		draw_circle(Vector2.ZERO, r.size.x * 0.36, HOLE)
		_draw_face(notices[i], Vector2.ZERO)
		draw_texture_rect(MEDALLION, local, false)
		var a := ALERT.get_size() * 2.0
		var pulse := 1.0 + 0.08 * sin(m.t * 7.0)
		draw_set_transform(r.get_center() + Vector2(r.size.x * 0.34, -r.size.y * 0.34), 0.0,
			Vector2(s * pulse, s * pulse))
		draw_texture_rect(ALERT, Rect2(-a * 0.5, a), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Σελίδα βιβλίου σε 9-slice x2: γωνίες ως έχουν, πλευρές σε επανάληψη (ποτέ
## τέντωμα), και η μέση γεμίζει με το χρώμα της περγαμηνής.
func _draw_page(r: Rect2) -> void:
	var c := PAGE_CORNER
	var ts := Vector2i(PAGE.get_size())
	var c2 := c * 2.0
	draw_rect(Rect2(r.position + Vector2(c2, c2) * 0.5, r.size - Vector2(c2, c2)), _parchment)
	# πλευρές: ένα κομμάτι λίγο μετά τη γωνία, μακριά από το καρφί της μέσης
	var seg := 12
	var x := r.position.x + c2
	while x < r.end.x - c2:
		var w := minf(seg * 2.0, r.end.x - c2 - x)
		draw_texture_rect_region(PAGE, Rect2(x, r.position.y, w, c2), Rect2(c, 0, w * 0.5, c))
		draw_texture_rect_region(PAGE, Rect2(x, r.end.y - c2, w, c2), Rect2(c, ts.y - c, w * 0.5, c))
		x += w
	var y := r.position.y + c2
	while y < r.end.y - c2:
		var h := minf(seg * 2.0, r.end.y - c2 - y)
		draw_texture_rect_region(PAGE, Rect2(r.position.x, y, c2, h), Rect2(0, c, c, h * 0.5))
		draw_texture_rect_region(PAGE, Rect2(r.end.x - c2, y, c2, h), Rect2(ts.x - c, c, c, h * 0.5))
		y += h
	draw_texture_rect_region(PAGE, Rect2(r.position, Vector2(c2, c2)), Rect2(0, 0, c, c))
	draw_texture_rect_region(PAGE, Rect2(r.end.x - c2, r.position.y, c2, c2), Rect2(ts.x - c, 0, c, c))
	draw_texture_rect_region(PAGE, Rect2(r.position.x, r.end.y - c2, c2, c2), Rect2(0, ts.y - c, c, c))
	draw_texture_rect_region(PAGE, Rect2(r.end - Vector2(c2, c2), Vector2(c2, c2)),
		Rect2(ts.x - c, ts.y - c, c, c))
	draw_texture_rect(CLOSE, close_rect(r), false)


func _plate_button(r: Rect2, label: String) -> void:
	draw_texture_rect(PLATE, r, false)
	draw_string(m.font, Vector2(r.position.x, r.get_center().y + 10.0), label,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, BONE)


func _toughness(e: EnemyType) -> int:
	if e == _boss_of(e):
		return 5
	return clampi(roundi(e.hp_mult * 2.5), 1, 5)


func _boss_of(e: EnemyType) -> EnemyType:
	for a in m.areas:
		if a.boss and a.boss.id == e.id:
			return e
	return null


func _draw_card() -> void:
	var c := card_rect()
	_draw_page(c)
	var font: Font = m.font
	var e := card
	if e == null:
		return
	var x := c.position.x + 44.0
	var w := c.size.x - 88.0
	draw_string(font, Vector2(x, c.position.y + 78.0), e.display_name.to_upper(),
		HORIZONTAL_ALIGNMENT_CENTER, w, 32, RED)
	var boss := _boss_of(e) != null
	var ai := area_of(e.id)
	var where: String = m.areas[ai].display_name.to_upper() if ai >= 0 else ""
	draw_string(font, Vector2(x, c.position.y + 108.0),
		("BOSS OF " + where) if boss else ("%s  -  FROM ROUND %d" % [where, e.min_round]),
		HORIZONTAL_ALIGNMENT_CENTER, w, 18, FADED)

	# το πορτρέτο: ακέραιο x4 για τους μικρούς, x2 για ό,τι είναι φαρδύτερο
	var pbox := Rect2(x, c.position.y + 130.0, 200.0, 170.0)
	draw_rect(pbox, _parchment.darkened(0.12))
	draw_rect(pbox, _parchment.darkened(0.35), false, 2.0)
	var big := e.sprite and e.sprite.get_width() > 32
	_draw_enemy(e, pbox.get_center(), 2.0 if big else 4.0)

	# δεξιά στήλη: αντοχή και ικανότητα
	var rx := pbox.end.x + 26.0
	var rw := c.end.x - 44.0 - rx
	draw_string(font, Vector2(rx, pbox.position.y + 26.0), "TOUGHNESS",
		HORIZONTAL_ALIGNMENT_LEFT, rw, 20, INK)
	var tn := _toughness(e)
	for k in 5:
		var pr := Rect2(rx + k * 30.0, pbox.position.y + 40.0, 22.0, 22.0)
		draw_rect(pr, INK)
		draw_rect(pr.grow(-3.0), Color("b0452c") if k < tn else _parchment.darkened(0.15))
	var ability := e.ability.describe() if e.ability else ""
	draw_string(font, Vector2(rx, pbox.position.y + 100.0), "ABILITY",
		HORIZONTAL_ALIGNMENT_LEFT, rw, 20, INK)
	draw_multiline_string(font, Vector2(rx, pbox.position.y + 128.0),
		ability if ability != "" else "None", HORIZONTAL_ALIGNMENT_LEFT, rw, 18, -1,
		RED if ability != "" else FADED)

	# η περιγραφή, κάτω από το πορτρέτο σε όλο το πλάτος
	draw_rect(Rect2(x, pbox.end.y + 26.0, w, 2.0), _parchment.darkened(0.3))
	draw_multiline_string(font, Vector2(x, pbox.end.y + 66.0), e.description,
		HORIZONTAL_ALIGNMENT_LEFT, w, 20, -1, INK)

	if view == "card":
		_plate_button(card_button_rect(0), "BOOK")
		_plate_button(card_button_rect(1), "OK")
	else:
		_plate_button(card_button_rect(1), "BACK")


func _draw_book() -> void:
	var b := book_rect()
	_draw_page(b)
	var font: Font = m.font
	draw_string(font, Vector2(b.position.x, b.position.y + 76.0), "BESTIARY",
		HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 34, RED)

	# καρτέλες: μία ανά περιοχή, η ανοιχτή φωτεινή
	for i in m.areas.size():
		var tr := tab_rect(i)
		var on: bool = i == book_area
		var tint := Color.WHITE if on else Color(0.55, 0.5, 0.5)
		modulate_strip(tr, tint)
		draw_string(font, Vector2(tr.position.x, tr.get_center().y + 7.0),
			m.areas[i].display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, tr.size.x, 18,
			BONE if on else Color(0.8, 0.74, 0.66))

	var list := entries(book_area)
	for i in list.size():
		var e := list[i]
		var r := entry_rect(i)
		var seen := is_seen(e.id)
		var ms := MEDALLION.get_size() * 2.0
		var mr := Rect2(Vector2(r.get_center().x - ms.x * 0.5, r.position.y + 8.0), ms)
		_draw_medallion(e, mr, not seen)
		draw_string(font, Vector2(r.position.x, mr.end.y + 30.0),
			e.display_name.to_upper() if seen else "???", HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, 18, INK if seen else FADED)
	if list.is_empty():
		draw_string(font, Vector2(b.position.x, b.position.y + 240.0), "NOTHING NEW HERE",
			HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 20, FADED)
	draw_string(font, Vector2(b.position.x, b.end.y - 34.0),
		"%d / %d DISCOVERED" % [_seen_count(), _total_count()],
		HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 18, FADED)


## Καρτέλα σε 3-slice με χρώμα. Το strip2 του main δεν παίρνει tint, οπότε
## εδώ ζωγραφίζεται με ένα modulate γύρω του.
func modulate_strip(r: Rect2, tint: Color) -> void:
	var ts := TAB.get_size()
	var cap := int(ts.x * 0.25)
	# η μέση πρώτα και με ceil, οι άκρες από πάνω (βλ. main.strip2)
	var x := r.position.x + cap * 2
	var end := r.end.x - cap * 2
	var body := int(ts.x) - cap * 2
	while x < end:
		var bw := mini(body, ceili((end - x) / 2.0))
		draw_texture_rect_region(TAB, Rect2(x, r.position.y, bw * 2, r.size.y),
			Rect2(cap, 0, bw, ts.y), tint)
		x += bw * 2
	draw_texture_rect_region(TAB, Rect2(r.position, Vector2(cap * 2, r.size.y)),
		Rect2(0, 0, cap, ts.y), tint)
	draw_texture_rect_region(TAB, Rect2(r.end.x - cap * 2, r.position.y, -cap * 2, r.size.y),
		Rect2(0, 0, cap, ts.y), tint)


func _seen_count() -> int:
	var n := 0
	for i in m.areas.size():
		for e in entries(i):
			if is_seen(e.id):
				n += 1
	return n


func _total_count() -> int:
	var n := 0
	for i in m.areas.size():
		n += entries(i).size()
	return n
