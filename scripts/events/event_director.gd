class_name EventDirector
extends RefCounted
## WorldEventDirector logic. Pure: flags in (any object with get_flag/set_flag), decision out.
## Decides only whether an event is eligible, which event fires, which variant, and writes the
## start flags + bookkeeping. It never runs dialogue, starts combat or tracks objectives.
##
## An "opportunity" is one chance to evaluate, counted in `event.director.opportunity`. It is
## not game time: whoever calls `evaluate` decides what creates an opportunity (in M10 that's
## EventHost on a region change). Cooldowns are counted in opportunities.
## Randomness is seeded per opportunity from `event.director.seed`, so there is no RNG state to
## save and the same flags always give the same result.

const OPPORTUNITY := "event.director.opportunity"
const SEED := "event.director.seed"
const LAST_FIRED := "event.director.last_fired"
const GAP := 1 ## opportunities after any event during which no new one starts


## Advances the opportunity counter and, unless an event fired too recently, starts one.
## Returns the event that fired, or null.
static func evaluate(events: Array[EventData], flags: Object, region: StringName, ignore_gap := false) -> EventData:
	var opportunity := int(flags.get_flag(OPPORTUNITY, 0)) + 1
	flags.set_flag(OPPORTUNITY, opportunity)
	var last: Variant = flags.get_flag(LAST_FIRED)
	if not ignore_gap and last is int and opportunity - last <= GAP:
		return null
	var seed := int(flags.get_flag(SEED, 0))
	var event := choose(eligible(events, flags, region, opportunity), seed, opportunity, region)
	if event:
		fire(event, choose_variant(event, flags, seed, opportunity), flags, opportunity)
	return event


static func eligible(events: Array[EventData], flags: Object, region: StringName, opportunity: int) -> Array[EventData]:
	var out: Array[EventData] = []
	for e in events:
		if e.region != region or not DialogueCondition.all_pass(e.conditions, flags):
			continue
		var fired: Variant = flags.get_flag(_key(e, "fired"))
		if e.repeat == EventData.Repeat.ONCE and fired is bool and fired:
			continue
		var last: Variant = flags.get_flag(_key(e, "last_opportunity"))
		if e.repeat == EventData.Repeat.COOLDOWN and last is int and opportunity - last < e.cooldown:
			continue
		out.append(e)
	return out


## Weighted pick; null when there's nothing to choose from.
static func choose(candidates: Array[EventData], seed: int, opportunity: int, region: StringName) -> EventData:
	var weights := candidates.map(func(e: EventData) -> int: return e.weight)
	var i := _weighted(weights, hash([seed, opportunity, String(region), "event"]))
	return candidates[i] if i >= 0 else null


## Weighted pick among the variants whose conditions pass; null if the event has none.
static func choose_variant(event: EventData, flags: Object, seed: int, opportunity: int) -> EventVariant:
	var options := event.variants.filter(func(v: EventVariant) -> bool: return DialogueCondition.all_pass(v.conditions, flags))
	var i := _weighted(options.map(func(v: EventVariant) -> int: return v.weight), hash([seed, opportunity, String(event.id), "variant"]))
	return options[i] if i >= 0 else null


static func fire(event: EventData, variant: EventVariant, flags: Object, opportunity: int) -> void:
	var effects := event.start.duplicate()
	if variant:
		effects.append_array(variant.start)
		flags.set_flag(_key(event, "variant"), String(variant.id))
	for effect: DialogueConsequence in effects:
		effect.apply(flags) # validate() guarantees SET_FLAG only
	flags.set_flag(_key(event, "fired"), true)
	flags.set_flag(_key(event, "last_opportunity"), opportunity)
	flags.set_flag(LAST_FIRED, opportunity)


static func _weighted(weights: Array, rng_seed: int) -> int:
	var total := 0
	for w: int in weights:
		total += w
	if total <= 0:
		return -1
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var roll := rng.randi_range(1, total)
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0:
			return i
	return weights.size() - 1


static func _key(event: EventData, fact: String) -> String:
	return "event.%s.%s" % [event.id, fact]
