extends CharacterBody2D
## Σφαίρα φωτιάς. Η ανάκλαση γίνεται με move_and_collide + bounce(normal).

signal died(x: float)

var speed := 950.0
var floor_y := 0.0
var sprite: Texture2D = null
var trail: Array[Vector2] = []


func _physics_process(delta: float) -> void:
	var motion := velocity * delta

	for i in 4:
		var col := move_and_collide(motion)
		if col == null:
			break
		velocity = velocity.bounce(col.get_normal())
		var other := col.get_collider()
		if other and other.has_method("hit"):
			other.hit()
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
	# ουρά
	for i in trail.size():
		var p := to_local(trail[i])
		var f := float(i + 1) / float(trail.size())
		draw_circle(p, 5.0 * f, Color(1.0, 0.5, 0.1, 0.22 * f))

	if sprite:
		var w := 30.0
		draw_texture_rect(sprite, Rect2(-w * 0.5, -w * 0.5, w, w), false)
		return

	draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.45, 0.08, 0.28))
	draw_circle(Vector2.ZERO, 10.0, Color("ff8a1f"))
	draw_circle(Vector2(0, -2.0), 5.0, Color("ffe9a8"))
