extends Node
class_name TweenCompat

# Godot 3 -> 4 compatibility shim for the removed `Tween` node.
#
# Godot 4 turned Tween into a transient object created via create_tween(); the
# old scene-graph Tween node (with interpolate_property/start and the
# tween_completed/tween_all_completed signals) no longer exists. Cutscene and
# world-map code across this project drives sequencing off those signals, so
# this node reproduces exactly the subset of the old API that is used, on top of
# a Godot 4 SceneTreeTween. Attach it to a plain Node named like the old Tween
# node so existing get_node("Tween") / $"...Tween" lookups keep resolving.

# Old Tween node signals (same argument shapes as Godot 3).
signal tween_completed(object, key)
signal tween_all_completed

# Interpolations queued by interpolate_property(), flushed by start().
var _pending: Array = []
var _tween: Tween = null

# Old API: queue a property interpolation. Trans/ease default to the values the
# callers pass explicitly (TRANS_LINEAR / EASE_IN_OUT); delay is rarely used.
func interpolate_property(object, property, initial_value, final_value, duration, trans_type = Tween.TRANS_LINEAR, ease_type = Tween.EASE_IN_OUT, delay = 0.0) -> void:
	_pending.append({
		"object": object, "property": property, "from": initial_value,
		"to": final_value, "duration": duration, "trans": trans_type,
		"ease": ease_type, "delay": delay,
	})

# Old API: run all queued interpolations together. Re-starting cancels any
# still-running tween, matching the Godot 3 node's reuse behaviour.
func start() -> void:
	if _pending.is_empty():
		return
	if _tween != null and _tween.is_running():
		_tween.kill()
	var steps: Array = _pending.duplicate()
	_pending.clear()
	_tween = create_tween().set_parallel(true)
	for s in steps:
		var pt = _tween.tween_property(s.object, s.property, s.to, s.duration)
		pt.from(s.from).set_trans(s.trans).set_ease(s.ease)
		if s.delay > 0.0:
			pt.set_delay(s.delay)
	_tween.finished.connect(func():
		for s in steps:
			emit_signal("tween_completed", s.object, str(s.property))
		emit_signal("tween_all_completed"), CONNECT_ONE_SHOT)

# Old API: was this tween still animating?
func is_active() -> bool:
	return _tween != null and _tween.is_running()
