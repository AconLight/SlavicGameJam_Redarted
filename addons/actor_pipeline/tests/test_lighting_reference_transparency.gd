extends SceneTree

const ExporterScript := preload("res://addons/actor_pipeline/generation/lighting_reference_exporter.gd")
const FIXTURE_PNG := "res://.godot/actor_pipeline_fixtures/lighting/alpha_fixture_lighting_reference.png"


func _init() -> void:
	var failures := PackedStringArray()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_PNG.get_base_dir()))
	var image := Image.create(4, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	image.set_pixel(1, 0, Color(1.0, 0.0, 0.0, 1.0))
	image.set_pixel(2, 0, Color(0.0, 1.0, 0.0, 0.5))
	if image.save_png(ProjectSettings.globalize_path(FIXTURE_PNG)) != OK:
		failures.append("Could not save alpha fixture PNG.")
	var verification_error := ExporterScript.new()._verify_transparent_png(FIXTURE_PNG)
	if not verification_error.is_empty():
		failures.append(verification_error)
	var exported := Image.load_from_file(ProjectSettings.globalize_path(FIXTURE_PNG))
	if exported == null or exported.is_empty():
		failures.append("Fixture reference PNG did not load.")
	else:
		if exported.get_format() != Image.FORMAT_RGBA8:
			failures.append("Fixture reference PNG is not RGBA8.")
		if exported.get_size() != Vector2i(4, 2):
			failures.append("Fixture reference PNG dimensions changed.")
		if exported.get_pixel(0, 0) != Color(0.0, 0.0, 0.0, 0.0):
			failures.append("Transparent background pixel was not transparent black.")
		if not is_equal_approx(exported.get_pixel(1, 0).a, 1.0):
			failures.append("Opaque fixture pixel alpha was not preserved.")
		if not is_equal_approx(exported.get_pixel(2, 0).a, image.get_pixel(2, 0).a):
			failures.append("Semi-transparent fixture pixel alpha was not preserved.")
	for failure in failures:
		push_error(failure)
		print("LIGHTING_REFERENCE_TRANSPARENCY_FAILURE=", failure)
	print("LIGHTING_REFERENCE_TRANSPARENCY_FAILURES=", failures.size())
	quit(0 if failures.is_empty() else 1)
