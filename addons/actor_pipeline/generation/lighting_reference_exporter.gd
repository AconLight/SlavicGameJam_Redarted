@tool
class_name ActorLightingReferenceExporter
extends RefCounted

const EXPORT_CONTRACT_VERSION := 1
const AsepriteConfigScript := preload("res://addons/AsepriteWizard/config/config.gd")


func export_reference(source_path: String, sprite_frames: SpriteFrames) -> Dictionary:
	if source_path.is_empty() or sprite_frames == null:
		return {"error": "Choose a source Aseprite file with imported SpriteFrames first."}
	var paths := _paths_for_source(source_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(paths.directory))
	if directory_error != OK:
		return {"error": "Could not create lighting reference directory: %s" % paths.directory}
	# Export straight from Aseprite. Reading the imported atlas back from Godot can
	# lose transparency on some compressed texture paths, while this command keeps
	# Aseprite's RGBA pixels and is the same deterministic packed-sheet contract.
	var command := AsepriteConfigScript.new().get_command()
	var output := []
	var exit_code := OS.execute(command, [
		"-b",
		"--data", ProjectSettings.globalize_path(paths.metadata),
		"--format", "json-array",
		"--sheet", ProjectSettings.globalize_path(paths.png),
		"--sheet-type", "packed",
		"--shape-padding", "0",
		ProjectSettings.globalize_path(source_path),
	], output, true, true)
	if exit_code != 0 and (not FileAccess.file_exists(paths.png) or FileAccess.get_file_as_bytes(paths.png).is_empty()):
		return {"error": "Aseprite could not export the lighting reference sheet. Check the configured Aseprite command and source file.\n" + "\n".join(output)}
	var image := Image.load_from_file(ProjectSettings.globalize_path(paths.png))
	if image == null or image.is_empty():
		return {"error": "Lighting reference sheet export failed. The generated PNG could not be loaded."}
	var normalized_image := _normalize_transparent_pixels(image)
	var save_error := normalized_image.save_png(ProjectSettings.globalize_path(paths.png))
	if save_error != OK:
		return {"error": "Lighting reference sheet export failed. The generated PNG could not be saved."}
	var verification_error := _verify_transparent_png(paths.png)
	if not verification_error.is_empty():
		return {"error": verification_error}
	var metadata := {
		"source": source_path,
		"sheet_width": image.get_width(),
		"sheet_height": image.get_height(),
		"frame_count": _frame_count(sprite_frames),
		"source_fingerprint": FileAccess.get_md5(source_path),
		"export_contract_version": EXPORT_CONTRACT_VERSION,
		"contract": {"format": "PNG", "pixel_format": "RGBA8", "background": "transparent", "alpha_preservation": true, "matte_color": "none", "rotation": false, "trimming": false, "duplicate_merging": false, "spacing": 0, "extrusion": 0, "frame_order": "SpriteFrames animation order, then frame index"},
	}
	var file := FileAccess.open(paths.metadata, FileAccess.WRITE)
	if file == null:
		return {"error": "Could not save lighting reference metadata: %s" % paths.metadata}
	file.store_string(JSON.stringify(metadata, "\t"))
	return {"png_path": paths.png, "metadata_path": paths.metadata}


func _verify_transparent_png(path: String) -> String:
	var exported := Image.load_from_file(ProjectSettings.globalize_path(path))
	if exported == null or exported.is_empty():
		return "Lighting reference sheet export failed. The generated PNG could not be reloaded."
	if exported.get_format() != Image.FORMAT_RGBA8:
		return "Lighting reference sheet export failed. The generated image does not contain an RGBA8 alpha channel. Expected an RGBA PNG with a transparent background."
	var has_transparent_pixel := false
	for y in exported.get_height():
		for x in exported.get_width():
			var pixel := exported.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				has_transparent_pixel = true
				if pixel != Color(0.0, 0.0, 0.0, 0.0):
					return "Lighting reference sheet export failed. Fully transparent pixels must be transparent black."
	if not has_transparent_pixel:
		return "Lighting reference sheet export failed. The generated image has no transparent background pixels. Check the Aseprite source layers."
	return ""


func _normalize_transparent_pixels(source: Image) -> Image:
	var normalized := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	normalized.fill(Color(0, 0, 0, 0))
	normalized.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)
	for y in range(normalized.get_height()):
		for x in range(normalized.get_width()):
			var pixel := normalized.get_pixel(x, y)
			if is_zero_approx(pixel.a):
				normalized.set_pixel(x, y, Color(0, 0, 0, 0))
	return normalized


func _frame_count(sprite_frames: SpriteFrames) -> int:
	var count := 0
	for animation_name in sprite_frames.get_animation_names():
		count += sprite_frames.get_frame_count(animation_name)
	return count


func _paths_for_source(source_path: String) -> Dictionary:
	var basename := source_path.get_file().get_basename()
	var directory := source_path.get_base_dir().path_join("lighting")
	return {"directory": directory, "png": directory.path_join("%s_lighting_reference.png" % basename), "metadata": directory.path_join("%s_lighting_reference.json" % basename)}
