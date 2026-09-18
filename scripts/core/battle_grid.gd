class_name BattleGrid
extends RefCounted
## Η μοναδική πηγή αλήθειας για το ποιος κατέχει ποιο κελί.
##
## Κάθε εχθρός καταλαμβάνει ένα αποτύπωμα cw×ch κελιών, ώστε ο boss να μπορεί
## να πιάνει π.χ. 3×2. Οι κόμβοι ακολουθούν το πλέγμα, όχι το αντίστροφο.

var cols: int
var _cells := {}          # Vector2i -> block


func _init(p_cols: int) -> void:
	cols = p_cols


func place(block) -> void:
	for c in block.cw:
		for r in block.ch:
			_cells[Vector2i(block.col + c, block.row + r)] = block


func erase(block) -> void:
	for key in _cells.keys():
		if _cells[key] == block:
			_cells.erase(key)


func at(col: int, row: int):
	return _cells.get(Vector2i(col, row))


func is_free(col: int, row: int) -> bool:
	if col < 0 or col >= cols or row < 0:
		return false
	return not _cells.has(Vector2i(col, row))


## Χωράει αποτύπωμα cw×ch στη θέση (col,row); Το `ignore` επιτρέπει σε έναν
## εχθρό να «περάσει μέσα από τον εαυτό του» όταν μετακινείται.
func fits(col: int, row: int, cw: int, ch: int, ignore = null) -> bool:
	if col < 0 or col + cw > cols or row < 0:
		return false
	for c in cw:
		for r in ch:
			var occupant = _cells.get(Vector2i(col + c, row + r))
			if occupant != null and occupant != ignore:
				return false
	return true


func move_to(block, col: int, row: int) -> void:
	erase(block)
	block.col = col
	block.row = row
	place(block)


func blocks() -> Array:
	var seen := []
	for key in _cells:
		var b = _cells[key]
		if not seen.has(b):
			seen.append(b)
	return seen


## Όσοι ακουμπάνε το αποτύπωμα οριζόντια ή κάθετα — για το splash του AoE.
func neighbors(block) -> Array:
	var found := []
	for c in block.cw:
		for r in block.ch:
			var cell := Vector2i(block.col + c, block.row + r)
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var other = _cells.get(cell + d)
				if other != null and other != block and not found.has(other):
					found.append(other)
	return found


## Ελεύθερα κελιά σε εύρος σειρών — για τον summoner.
func free_cells(from_row: int, to_row: int) -> Array:
	var out := []
	for r in range(from_row, to_row + 1):
		for c in cols:
			if is_free(c, r):
				out.append(Vector2i(c, r))
	return out


func free_cols_in_row(row: int) -> Array:
	var out := []
	for c in cols:
		if is_free(c, row):
			out.append(c)
	return out


## Η χαμηλότερη σειρά που πιάνει οποιοσδήποτε εχθρός.
func lowest_row() -> int:
	var low := -1
	for b in blocks():
		low = maxi(low, b.row + b.ch - 1)
	return low


func clear() -> void:
	_cells.clear()
