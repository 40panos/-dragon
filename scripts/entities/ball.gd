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
var spin_t := 0.0

## Το χρώμα της ουράς. Ήταν σταθερά πορτοκαλί, που πίσω από ένα δρεπάνι
## έμοιαζε με φλόγα.
var trail_color := Color(1.0, 0.5, 0.1)

## Ποια blocks έχει ήδη πιτσιλίσει αυτή η μπάλα — το splash μετράει μία φορά ανά μπάλα.
var splashed := {}


func _physics_process(delta: float) -> void:
	spin_t += delta
	var motion := velocity * delta

	for i in 4:
		var col := move_and_collide(motion)
		if col == null:
			break
		velocity = velocity.bounce(col.get_normal())
		var other := col.get_collider()
		if other and other.is_in_group("block"):
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


func _draw() -> void:
	for i in trail.size():
		var p := to_local(trail[i])
		var f := float(i + 1) / float(trail.size())
		draw_circle(p, 5.0 * f * draw_scale, Color(trail_color, 0.22 * f))

	if sprite:
		var w := 30.0 * draw_scale
		# το σχέδιο κοιτάει αριστερά (η ουρά πίσω από τον πυρήνα), οπότε
		# γυρνάει να δείχνει προς την πορεία — αλλιώς η φλόγα δείχνει
		# πάντα στο ίδιο σημείο όπου κι αν πάει η μπάλα
		var ang := velocity.angle() + PI if velocity.length_squared() > 0.01 else 0.0
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
