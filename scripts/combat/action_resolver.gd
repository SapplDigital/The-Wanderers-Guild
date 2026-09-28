class_name ActionResolver
extends RefCounted
## The d20 layer: roll d20 + attack modifier against a defense value.
## A natural 20 always hits and rolls the damage die twice; a natural 1 always misses.
## hit_chance() uses the same rule, so UI predictions match what actually happens.


static func hit_chance(attack_mod: int, defense: int) -> float:
	var needed := clampi(defense - attack_mod, 2, 20) # nat 1 never hits, nat 20 always does
	return (21 - needed) / 20.0


static func attack(rng: RandomNumberGenerator, attack_mod: int, defense: int, die: int, bonus: int) -> Dictionary:
	var roll := rng.randi_range(1, 20)
	var crit := roll == 20
	var hit := crit or (roll != 1 and roll + attack_mod >= defense)
	var damage := 0
	if hit:
		damage = rng.randi_range(1, die) + bonus
		if crit:
			damage += rng.randi_range(1, die)
	return {"roll": roll, "total": roll + attack_mod, "defense": defense, "hit": hit, "crit": crit, "damage": damage}


static func damage_range(die: int, bonus: int) -> Vector2i:
	return Vector2i(1 + bonus, die + bonus)
