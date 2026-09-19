extends SceneTree
## Τραβάει screenshot του παιχνιδιού σε κάθε κατάσταση του δράκου.
## Πρέπει να τρέξει ΜΕ rendering (χωρίς --headless), αλλιώς δεν καλείται _draw().
##
##   godot --path . --script tools/shoot.gd

const OUT := "user://shots"


func _grab(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_root().get_texture().get_image()
	img.save_png(path)
	print("  ", path, "  ", img.get_width(), "x", img.get_height())


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var m = load("res://scenes/main.tscn").instantiate()
	root.add_child(m)
	for i in 30:
		await process_frame

	var dir := ProjectSettings.globalize_path(OUT)
	print("γράφω στο ", dir)

	# ολόκληρη η οθόνη, όπως ξεκινάει το παιχνίδι
	await _grab(dir + "/game.png")

	# κάθε κατάσταση, σε δύο σημεία του ping-pong βρόχου
	var shots := [
		["idle",  "aim",   false, 0.0],
		["idle2", "aim",   false, 1.0],   # fps_idle 2 -> βήμα 2, μάτια κλειστά
		["ready", "aim",   true,  0.0],
		["ready2","aim",   true,  0.334], # fps_ready 6 -> βήμα 2, μάτια αναμμένα
		["fire",  "shoot", false, 0.0],
		["fire2", "shoot", false, 0.167], # fps_fire 12 -> βήμα 2, φλόγα στο φουλ
	]
	for s in shots:
		m.phase = s[1]
		m.aiming = s[2]
		m.t = s[3]
		m.queue_redraw()
		await process_frame
		await _grab("%s/%s.png" % [dir, s[0]])

	quit(0)
