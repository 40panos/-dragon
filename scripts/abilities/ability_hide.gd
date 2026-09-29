class_name ThickHideAbility
extends EnemyAbility
## Χοντρό τομάρι: κόβει σταθερό ποσό από ΚΑΘΕ χτύπημα, όχι ποσοστό.
##
## Έτσι οι πολλές αδύναμες μπάλες γδέρνουν μόνο, ενώ το INFERNO — που χτυπάει
## τριπλά — περνάει σχεδόν ακέραιο. Η ασπίδα (ShieldAbility) έχει δική της ζωή
## και σπάει· αυτό εδώ δεν σπάει ποτέ.

@export var reduce := 0.4        # πόση ζημιά τρώει το τομάρι σε κάθε χτύπημα
@export var min_through := 0.2   # πάντα περνάει κάτι, αλλιώς κολλάει η μάχη


func absorb(_block, amount: float) -> float:
	if amount <= 0.0:
		return amount
	# το δάπεδο δεν επιτρέπεται να περάσει παραπάνω απ' όσα ήρθαν
	return minf(amount, maxf(amount - reduce, min_through))


func badge() -> String:
	return "##"


func describe() -> String:
	return "Thick hide: every hit does %s less damage" % str(reduce)
