extends SceneTree

const RequestScript := preload("res://addons/actor_pipeline/generation/actor_creation_request.gd")
const ValidatorScript := preload("res://addons/actor_pipeline/validation/actor_lighting_map_validator.gd")
const RenderingProfileScript := preload("res://addons/actor_pipeline/domain/actor_rendering_profile.gd")
const DefinitionScript := preload("res://addons/actor_pipeline/domain/actor_definition.gd")
const PathPolicyScript := preload("res://addons/actor_pipeline/generation/path_policy.gd")


func _init() -> void:
	var failures := PackedStringArray()
	var none_request := RequestScript.new()
	none_request.lighting_mode = ActorLightingMode.Type.NONE
	var none_result := ValidatorScript.new().validate(none_request)
	if not none_result.is_valid() or none_result.rendering_profile != null:
		failures.append("None lighting mode should pass with no profile.")

	var folder_request := RequestScript.new()
	folder_request.actor_id = &"test_actor"
	folder_request.lighting_mode = ActorLightingMode.Type.FROM_LIGHTING_DIRECTORY
	var folder_result := ValidatorScript.new().validate(folder_request)
	if folder_result.is_valid():
		failures.append("Folder lighting mode without a lighting reference/normal map should fail.")

	var profile := RenderingProfileScript.new()
	var definition := DefinitionScript.new()
	definition.rendering_profile = profile
	if definition.rendering_profile != profile or profile.normal_map != null:
		failures.append("Rendering profile should be assignable with optional maps empty.")

	var paths := PathPolicyScript.build_paths("res://actors/test_actor", "test_actor", true)
	if not paths.has("rendering_profile") or not str(paths.rendering_profile).ends_with("test_actor_rendering_profile.tres"):
		failures.append("Lighting path policy should include a rendering-profile path.")

	for failure in failures:
		push_error(failure)
	print("LIGHTING_TEST_FAILURES=", failures.size())
	quit(0 if failures.is_empty() else 1)
