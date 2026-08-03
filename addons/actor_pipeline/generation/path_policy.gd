class_name ActorPathPolicy
extends RefCounted

static func is_valid_actor_id(actor_id: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]*$")
	return expression.search(actor_id) != null


static func build_paths(output_directory: String, actor_id: String, include_rendering_profile := false) -> Dictionary:
	var paths := {
		"scene": output_directory.path_join("%s.tscn" % actor_id),
		"definition": output_directory.path_join("%s_definition.tres" % actor_id),
		"contract": output_directory.path_join("%s_animation_contract.tres" % actor_id),
		"events": output_directory.path_join("%s_animation_events.tres" % actor_id),
		"sounds": output_directory.path_join("%s_sounds.tres" % actor_id),
		"manifest": output_directory.path_join("%s_generation_manifest.tres" % actor_id),
	}
	if include_rendering_profile:
		paths["rendering_profile"] = output_directory.path_join("%s_rendering_profile.tres" % actor_id)
	return paths
