class_name Ball
extends CharacterBody2D
## Σφαίρα φωτιάς. Η ανάκλαση γίνεται με move_and_collide + bounce(normal).
##
## Η μπάλα δεν αποφασίζει ζημιά — αναφέρει το χτύπημα και το παιχνίδι
## εφαρμόζει τους κανόνες (splash, passive, special).

signal died(x: float)
signal struck(block, ball)

var speed := 950.0
var floor_y := 0.0
var damage := 1.0
var sprite: Texture2D = null
var trail: Array[Vector2] = []

## Μεγέθυνση ΜΟΝΟ της σχεδίασης — το σχήμα σύγκρουσης δεν το πειράζει, ώστε
## το INFERNO να μη γίνεται κρυφά και ευκολότερο στο σημάδι.
var draw_scale := 1.0

## Στροφές ανά δευτερόλεπτο του σχεδίου. Στο 0 το βλήμα απλώς κοιτάει προς την
## πορεία του, που είναι το σωστό για μπάλα φωτιάς με ουρά. Τα δρεπάνια του
## death στριφογυρίζουν, οπότε παίρνουν δική τους ταχύτητα από τον δράκο.
var spin := 0.0
## Προς τα πού «κοιτάει» το σχέδιο του βλήματος, σε ακτίνια (PI = αριστερά,
## όπως η φωτιά με την ουρά δεξιά). Το βλήμα γυρνάει ώστε αυτή η κατεύθυνση
## να πέφτει πάνω στην πορεία του.
var heading := PI
var spin_t := 0.0

## Το χρώμα της ουράς. Ήταν σταθερά πορτοκαλί, που πίσω από ένα δρεπάνι
## έμοιαζε με φλόγα.
var trail_color := Color(1.0, 0.5, 0.1)

## HARPOON: το βλήμα περνάει μέσα από τους εχθρούς αντί να αναπηδά. Χτυπάει
## τον καθένα μία φορά (μετά μπαίνει στις εξαιρέσεις σύγκρουσης) και συνεχίζει
## ίσια. Τοίχοι και άτρωτα (οδοφράγματα) το γυρίζουν πίσω κανονικά.
var pierce := false

## Ποια blocks έχει ήδη πιτσιλίσει αυτή η μπάλα — το splash μετράει μία φορά ανά μπάλα.
var splashed := {}

## Παγωμένη από το βλέμμα του Wendigo: στέκεται στον αέρα μέσα σε κρύσταλλο
## που ραγίζει, ώσπου το main τη σπάει (shatter). Δεν χτυπάει τίποτα πια.
var frozen := false
var frozen_t := 0.0
## Το κύμα κρύου: ξεκινάει από τα μάτια του (`ring_at`) μετά από `freeze_in`
## δευτερόλεπτα και ανοίγει με `ring_speed`. Η μπάλα παγώνει τη στιγμή που
## το κύμα φτάνει εκεί όπου βρίσκεται ΤΟΤΕ — όχι εκεί που ήταν στο βλέμμα,
## αλλιώς όσες πετούσαν προς τα πάνω πρόφταιναν το κύμα και πάγωναν αργότερα.
var freeze_in := -1.0
const CHILL := 0.12
var ring_at := Vector2.ZERO
var ring_speed := 0.0
var _ring_t := 0.0


func freeze(start: float, from: Vector2, speed: float) -> void:
	if frozen or freeze_in >= 0.0:
		return
	freeze_in = maxf(start, 0.0)
	ring_at = from
	ring_speed = speed
	_ring_t = 0.0


func _physics_process(delta: float) -> void:
	if freeze_in >= 0.0 and not frozen:
		_ring_t += delta
		var reach := (_ring_t - freeze_in) * ring_speed
		if reach >= 0.0 and reach >= global_position.distance_to(ring_at):
			frozen = true
			trail.clear()
	if frozen:
		frozen_t += delta
		queue_redraw()
		return
	spin_t += delta
	# Από τη στιγμή που ανάβουν τα μάτια, το κρύο την πιάνει: σέρνεται στο
	# CHILL της ταχύτητας ώσπου να τη βρει το κύμα. Αλλιώς όσες κατέβαιναν
	# προς το δάπεδο προλάβαιναν να «προσγειωθούν» και γλίτωναν. Και δεν
	# χτυπάει τίποτα πια: η βολή έχει ήδη χαθεί.
	var chilled := freeze_in >= 0.0
	var motion := velocity * delta * (CHILL if chilled else 1.0)

	for i in 4:
		var col := move_and_collide(motion)
		if col == null:
			break
		var other := col.get_collider()
		if pierce and not chilled and other and other.is_in_group("block") \
				and not other.invulnerable:
			struck.emit(other, self)
			add_collision_exception_with(other)
			motion = col.get_remainder()
			continue
		velocity = velocity.bounce(col.get_normal())
		if other and other.is_in_group("block") and not chilled:
			struck.emit(other, self)
		motion = velocity.normalized() * col.get_remainder().length()

	# anti-stuck: ποτέ σχεδόν οριζόντια τροχιά
	if absf(velocity.y) < speed * 0.15:
		var sy := -1.0 if velocity.y == 0.0 else signf(velocity.y)
		velocity.y = sy * speed * 0.15
		velocity = velocity.normalized() * speed

	trail.push_back(global_position)
	if trail.size() > 6:
		trail.remove_at(0)
	queue_redraw()

	if global_position.y > floor_y:
		died.emit(global_position.x)
		queue_free()


## Μαλακή κουκκίδα για την ουρά, φτιαγμένη μία φορά για όλες τις μπάλες. Το
## draw_circle έφτιαχνε πολύγωνο από την αρχή σε κάθε κλήση, και με εκατοντάδες
## μπάλες x 6 κύκλους η σχεδίαση έτρωγε όλο το καρέ. Η υφή μπαίνει σε batch.
static var _dot: Texture2D


static func dot_tex() -> Texture2D:
	if _dot == null:
		var n := 16
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		var c := Vector2(n, n) * 0.5
		for y in n:
			for x in n:
				var d := (Vector2(x + 0.5, y + 0.5) - c).length() / (n * 0.5)
				img.set_pixel(x, y, Color(1, 1, 1, 1.0 if d <= 0.92 else clampf((1.0 - d) / 0.08, 0.0, 1.0)))
		_dot = ImageTexture.create_from_image(img)
	return _dot


## Κρύσταλλος γύρω από παγωμένη μπάλα: ρόμβος στο πλέγμα των 2px (1 art
## pixel), γαλάζιο σώμα, σκούρο περίγραμμα, λευκή γυαλάδα πάνω αριστερά — και
## ρωγμές που απλώνονται από το κέντρο όσο πλησιάζει το σπάσιμο.
const ICE_EDGE := Color("163a63")
const ICE_BODY := Color(0.62, 0.88, 1.0, 0.78)
const ICE_HI := Color(1, 1, 1, 0.95)
const ICE_R := 10                  # ακτίνα σε κουτάκια των 2px


func _draw_ice() -> void:
	var k := clampf(frozen_t / 0.12, 0.0, 1.0)      # ο πάγος «κλείνει» γρήγορα
	var r := int(ceil(ICE_R * k))
	var px := 2.0
	if sprite:
		var w := 30.0 * draw_scale
		draw_texture_rect(sprite, Rect2(-w * 0.5, -w * 0.5, w, w), false, Color(0.55, 0.8, 1.2, 1.0))
	for gy in range(-r - 1, r + 2):
		for gx in range(-r - 1, r + 2):
			var d := absi(gx) + absi(gy)           # ρόμβος: απόσταση Manhattan
			if d > r + 1:
				continue
			var q := Rect2(gx * px - 1.0, gy * px - 1.0, px, px)
			if d == r + 1:
				draw_rect(q, ICE_EDGE)
			elif d >= r - 1:
				draw_rect(q, Color(0.85, 0.96, 1.0, 0.95))
			else:
				draw_rect(q, ICE_BODY)
	if k < 1.0:
		return
	# γυαλάδα: μικρή διαγώνιος πάνω αριστερά
	for i in 3:
		draw_rect(Rect2((-r + 3 + i) * px - 1.0, (-2 - i) * px - 1.0, px, px), ICE_HI)
	# ρωγμές: τέσσερις ζιγκ-ζαγκ γραμμές από το κέντρο, όλο και πιο μακριές
	var crack := clampf((frozen_t - 0.15) / 0.35, 0.0, 1.0)
	if crack <= 0.0:
		return
	var dirs := [Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-1, 1)]
	for j in dirs.size():
		var dv: Vector2i = dirs[j]
		var steps := int(round(crack * (r - 1)))
		var p := Vector2i.ZERO
		for s in steps:
			# ζιγκ-ζαγκ: εναλλάξ οριζόντιο και κάθετο βήμα
			p += Vector2i(dv.x, 0) if (s + j) % 2 == 0 else Vector2i(0, dv.y)
			draw_rect(Rect2(p.x * px - 1.0, p.y * px - 1.0, px, px), ICE_EDGE)


func _draw() -> void:
	if frozen:
		_draw_ice()
		return
	var dot := dot_tex()
	for i in trail.size():
		var p := to_local(trail[i])
		var f := float(i + 1) / float(trail.size())
		var r := 5.0 * f * draw_scale
		draw_texture_rect(dot, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false,
			Color(trail_color, 0.22 * f))

	if sprite:
		var w := 30.0 * draw_scale
		# γυρνάει ώστε η μύτη του σχεδίου (heading) να δείχνει την πορεία —
		# αλλιώς η φλόγα ή ο κρύσταλλος δείχνουν πάντα στο ίδιο σημείο
		var ang := velocity.angle() - heading if velocity.length_squared() > 0.01 else 0.0
		# ...εκτός αν στριφογυρίζει: τότε η πορεία δεν μετράει, μετράει ο χρόνος
		if spin != 0.0:
			ang = spin_t * spin * TAU
		draw_set_transform(Vector2.ZERO, ang, Vector2.ONE)
		draw_texture_rect(sprite, Rect2(-w * 0.5, -w * 0.5, w, w), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.45, 0.08, 0.28))
	draw_circle(Vector2.ZERO, 10.0, Color("ff8a1f"))
	draw_circle(Vector2(0, -2.0), 5.0, Color("ffe9a8"))
