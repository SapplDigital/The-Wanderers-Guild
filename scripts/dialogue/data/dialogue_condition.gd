class_name DialogueCondition
extends Resource
## One flag test. Flag-only by design: no expressions, no dice (see DECISIONS, M8).

enum Test { IS_SET, NOT_SET, EQUALS }

@export var flag := ""
@export var test := Test.IS_SET
@export var value := "" ## EQUALS compares the flag's value as a string


## True when every condition passes (an empty list passes). Dialogue, quests and events all
## evaluate condition lists through here, so a new test type only needs `passes`.
static func all_pass(conditions: Array[DialogueCondition], flags: Object) -> bool:
	return conditions.all(func(c: DialogueCondition) -> bool: return c.passes(flags))


## `flags` is any object with `get_flag(key, default)` (GameState in the game).
func passes(flags: Object) -> bool:
	var current: Variant = flags.get_flag(flag)
	match test:
		Test.IS_SET:
			return current is bool and current
		Test.NOT_SET:
			return not (current is bool and current)
		_:
			return current != null and str(current) == value
