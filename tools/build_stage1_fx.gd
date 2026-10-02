extends SceneTree
## Περνάει στο art/ τα εφέ των ικανοτήτων του Goblin Land. Τα αρχικά του
## PixelLab μένουν στο bbdragon-art-proposals/stage1fx/raw.
##
##   godot --headless --path . --script tools/build_stage1_fx.gd
##   godot --headless --path . --script tools/write_stage1_fx.gd
##
##   fx_charge_1..N      βελάκια ταχύτητας με άνεμο (διπλό βήμα του καβαλάρη)
##   fx_summon_1..N      μαγικός κύκλος στο κελί όπου θα βγει minion
##   fx_cracks           ρωγμές στο έδαφος όταν προσγειώνεται boss
##   fx_emote_angry      συννεφάκι θυμού του mini-boss
##   warlock_cast_1..N   ο warlock σηκώνει το ραβδί και καλεί
## Τα εφέ δεν είναι βρόχοι: παίζουν μία φορά, οπότε κρατιούνται όλα τα καρέ.
## Το cast του warlock έχει το τελευταίο καρέ καρφωμένο στο πρώτο — αυτό δεν
## μπαίνει.

const RAW := "C:/Users/panos/Documents/bbdragon-art-proposals/stage1fx/raw/"

## όνομα στο art/ -> [πρόθεμα στο raw/anim, πετάει το τελευταίο]
const SEQS := {
	"fx_charge": ["charge", false],
	"fx_summon": ["summon", false],
	"warlock_cast": ["warlock_cast", true],
}
const SINGLES := {"fx_cracks": "cracks", "fx_emote_angry": "emote"}


func _load(path: String) -> Image:
	var im := Image.load_from_file(path)
	if im == null:
		push_error("λείπει: " + path)
		quit(1)
		return null
	im.convert(Image.FORMAT_RGBA8)
	return im


func _save(im: Image, name_: String) -> void:
	im.save_png(ProjectSettings.globalize_path("res://art/%s.png" % name_))


func _initialize() -> void:
	for name_ in SINGLES:
		_save(_load(RAW + SINGLES[name_] + ".png"), name_)
	for name_ in SEQS:
		var prefix: String = SEQS[name_][0]
		var frames: Array[Image] = []
		var i := 0
		while FileAccess.file_exists(RAW + "anim/%s_%d.png" % [prefix, i]):
			frames.append(_load(RAW + "anim/%s_%d.png" % [prefix, i]))
			i += 1
		if frames.is_empty() and FileAccess.file_exists(RAW + prefix + ".png"):
			frames.append(_load(RAW + prefix + ".png"))
		if SEQS[name_][1] and frames.size() > 1:
			frames.pop_back()
		for k in frames.size():
			_save(frames[k], "%s_%d" % [name_, k + 1])
		print("%s: %d καρέ" % [name_, frames.size()])
	quit(0)
