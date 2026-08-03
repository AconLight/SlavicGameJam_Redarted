@tool
class_name ActorLightingMapValidator
extends RefCounted

const SUPPORTED_IMAGE_EXTENSIONS := ["png", "jpg", "jpeg", "webp"]


func validate(request: ActorCreationRequest) -> ActorLightingValidationResult:
	var result := ActorLightingValidationResult.new()
	if request == null or request.lighting_mode == ActorLightingMode.Type.NONE:
		return result
	if request.lighting_mode != ActorLightingMode.Type.FROM_LIGHTING_DIRECTORY and request.lighting_mode != ActorLightingMode.Type.AUTO_LAIGTER:
		result.errors.append("Cannot create actor: unsupported lighting mode.")
		return result

	var actor_label := String(request.actor_id) if request.actor_id != &"" else "<unnamed>"
	var reference := _reference_paths(request.source_aseprite_path)
	result.reference_path = reference.png
	if not FileAccess.file_exists(reference.png) or not FileAccess.file_exists(reference.metadata):
		result.errors.append("Cannot create actor \"%s\": lighting reference sheet or metadata is missing. Export Lighting Reference Sheet for %s." % [actor_label, request.source_aseprite_path])
		return result
	var metadata := _load_metadata(reference.metadata)
	if metadata.is_empty():
		result.errors.append("Cannot create actor \"%s\": lighting reference metadata is invalid: %s." % [actor_label, reference.metadata])
		return result
	var current_fingerprint := FileAccess.get_md5(request.source_aseprite_path)
	result.reference_fingerprint = str(metadata.get("source_fingerprint", ""))
	if result.reference_fingerprint.is_empty() or current_fingerprint != result.reference_fingerprint:
		result.errors.append("Cannot create actor \"%s\": the lighting reference sheet is outdated. Export a new lighting reference sheet and regenerate the authored maps." % actor_label)
		return result
	var expected_size := Vector2i(int(metadata.get("sheet_width", 0)), int(metadata.get("sheet_height", 0)))
	if expected_size.x <= 0 or expected_size.y <= 0:
		result.errors.append("Cannot create actor \"%s\": lighting reference metadata has invalid sheet dimensions." % actor_label)
		return result

	var profile := ActorRenderingProfile.new()
	profile.normal_map = _validate_map(actor_label, "Normal", request.normal_map_path, expected_size, true, result)
	profile.specular_map = _validate_map(actor_label, "Specular", request.specular_map_path, expected_size, false, result)
	profile.occlusion_map = _validate_map(actor_label, "Occlusion", request.occlusion_map_path, expected_size, false, result)
	profile.emission_map = _validate_map(actor_label, "Emission", request.emission_map_path, expected_size, false, result)
	if result.errors.is_empty():
		result.rendering_profile = profile
	return result


func _validate_map(actor_label: String, map_label: String, path: String, expected_size: Vector2i, required: bool, result: ActorLightingValidationResult) -> Texture2D:
	if path.is_empty():
		if required:
			result.errors.append("Cannot create actor \"%s\": %s map is required in Authored lighting mode." % [actor_label, map_label])
		return null
	if not path.begins_with("res://"):
		result.errors.append("Cannot create actor \"%s\": %s map must be a project-local res:// path, received: %s." % [actor_label, map_label, path])
		return null
	if path.get_extension().to_lower() not in SUPPORTED_IMAGE_EXTENSIONS:
		result.errors.append("Cannot create actor \"%s\": %s map has unsupported source extension: %s." % [actor_label, map_label, path])
		return null
	if not FileAccess.file_exists(path):
		result.errors.append("Cannot create actor \"%s\": %s map does not exist: %s." % [actor_label, map_label, path])
		return null
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		result.errors.append("Cannot create actor \"%s\": %s map could not be read as an image: %s." % [actor_label, map_label, path])
		return null
	var received_size := Vector2i(image.get_width(), image.get_height())
	if received_size != expected_size:
		result.errors.append("Cannot create actor \"%s\": %s map dimensions do not match the lighting reference sheet. Map: %s. Expected: %d × %d. Received: %d × %d. Export a new reference sheet and regenerate this map." % [actor_label, map_label, path, expected_size.x, expected_size.y, received_size.x, received_size.y])
		return null
	var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if texture == null:
		result.errors.append("Cannot create actor \"%s\": %s map is not an imported Texture2D: %s." % [actor_label, map_label, path])
		return null
	_warn_about_import_quality(map_label, path, result)
	return texture


func _warn_about_import_quality(map_label: String, path: String, result: ActorLightingValidationResult) -> void:
	var config := ConfigFile.new()
	if config.load(path + ".import") != OK:
		return
	if bool(config.get_value("params", "mipmaps/generate", false)):
		result.warnings.append("%s map enables mipmaps; pixel-art lighting maps normally use no mipmaps: %s." % [map_label, path])


func _reference_paths(source_path: String) -> Dictionary:
	var basename := source_path.get_file().get_basename()
	var directory := source_path.get_base_dir().path_join("lighting")
	return {
		"png": directory.path_join("%s_lighting_reference.png" % basename),
		"metadata": directory.path_join("%s_lighting_reference.json" % basename),
	}


func _load_metadata(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed := JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
