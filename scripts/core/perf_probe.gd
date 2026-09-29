class_name PerfProbe
extends RefCounted
## Debug-only performance baseline (M15), driven by the shot harness:
##   godot --path . -- --shot=<png> --pos=x,y,z --perf[=frames] [--stress=3]
## Waits for the view to settle, then averages wall-clock frame time and the 3D view's render CPU/GPU time over
## `frames` frames with vsync off, and prints draw calls / objects / primitives. `--stress=N`
## adds N-1 extra copies of every mesh under `Forest` (shared mesh + material, offset a few
## metres) as a controlled "N× Near Wood density" case. Nothing here runs in normal play.

const FOREST_OFFSETS: Array[Vector3] = [Vector3(2.7, 0, 1.9), Vector3(-2.3, 0, -2.6), Vector3(1.1, 0, -3.4)]


## Adds (copies - 1) visual duplicates of every MeshInstance3D under `forest`. Returns how many.
static func stress(forest: Node3D, copies: int) -> int:
	var meshes := forest.find_children("*", "MeshInstance3D", true, false)
	var added := 0
	for c in range(1, copies):
		var offset := FOREST_OFFSETS[(c - 1) % FOREST_OFFSETS.size()]
		for m: MeshInstance3D in meshes:
			var copy := MeshInstance3D.new()
			copy.mesh = m.mesh
			copy.material_override = m.material_override
			for s in m.get_surface_override_material_count():
				copy.set_surface_override_material(s, m.get_surface_override_material(s))
			copy.cast_shadow = m.cast_shadow
			forest.add_child(copy)
			copy.global_transform = Transform3D(m.global_transform.basis, m.global_transform.origin + offset)
			added += 1
	return added


## Measures `frames` frames and returns a one-line summary.
static func measure(tree: SceneTree, viewport: Viewport, frames: int) -> String:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(viewport.get_viewport_rid(), true)
	for i in 30: # let the vsync change and shader compiles settle
		await tree.process_frame
	var rid := viewport.get_viewport_rid()
	var t0 := Time.get_ticks_usec()
	var cpu := 0.0
	var gpu := 0.0
	var worst := 0.0
	var last := t0
	for i in frames:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
	var frame_ms := (Time.get_ticks_usec() - t0) / 1000.0 / frames
	return "perf: %s | %s | window %s, 3D view %s | frames=%d avg_frame=%.2fms (%.0f fps) worst=%.2fms render_cpu=%.2fms render_gpu=%.2fms (3D view) draw_calls=%d objects=%d primitives=%d nodes=%d video_mem=%.0fMB" % [
		OS.get_processor_name(), RenderingServer.get_video_adapter_name(), DisplayServer.window_get_size(), viewport.get_visible_rect().size,
		frames, frame_ms, 1000.0 / frame_ms, worst, cpu / frames, gpu / frames,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0]
