@tool
class_name ActorFactory
extends RefCounted

const GENERATOR_VERSION := "0.1.0"
const CHARACTER_TEMPLATE_PATH := "res://addons/actor_pipeline/templates/character_actor.tscn"
const SpriteFramesBundlerScript := preload("res://addons/actor_pipeline/generation/sprite_frames_bundler.gd")

func create_actor(request: ActorCreationRequest) -> ActorGenerationResult:
	var result := ActorGenerationResult.new()
	_validate_request(request, result)
	if not result.errors.is_empty():
		return result
	var lighting_validation := ActorLightingMapValidator.new().validate(request)
	result.errors.append_array(lighting_validation.errors)
	result.warnings.append_array(lighting_validation.warnings)
	if not result.errors.is_empty():
		return result

	var paths := ActorPathPolicy.build_paths(request.output_directory, request.actor_id, request.lighting_mode != ActorLightingMode.Type.NONE)
	for path in paths.values():
		if ResourceLoader.exists(path):
			result.errors.append("Target already exists: %s" % path)
	if not result.errors.is_empty():
		return result

	var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(request.output_directory))
	if directory_error != OK:
		result.errors.append("Could not create output directory: %s" % request.output_directory)
		return result

	var contract := _build_contract(request.sprite_frames)
	var events := AnimationEventSet.new()
	var sounds := ActorSoundSet.new()
	var manifest := _build_manifest(request, lighting_validation)
	# Bundle the imported atlas with the generated actor. This makes the actor
	# playable on a fresh clone without Aseprite or the Aseprite Wizard importer.
	var standalone_sprite_frames := SpriteFramesBundlerScript.new().bundle(request.sprite_frames)
	if standalone_sprite_frames == null or ResourceSaver.save(standalone_sprite_frames, paths.sprite_frames, ResourceSaver.FLAG_BUNDLE_RESOURCES) != OK:
		result.errors.append("Could not save standalone SpriteFrames: %s" % paths.sprite_frames)
		_cleanup_created_files(result.created_paths)
		return result
	result.created_paths.append(paths.sprite_frames)
	var saved_sprite_frames := ResourceLoader.load(paths.sprite_frames, "SpriteFrames", ResourceLoader.CACHE_MODE_REPLACE) as SpriteFrames
	if saved_sprite_frames == null:
		result.errors.append("Could not reload standalone SpriteFrames: %s" % paths.sprite_frames)
		_cleanup_created_files(result.created_paths)
		return result
	var definition := ActorDefinition.new()
	definition.actor_id = request.actor_id
	definition.display_name = request.display_name
	definition.archetype = request.archetype
	definition.sprite_frames = saved_sprite_frames
	definition.source_aseprite_path = request.source_aseprite_path
	definition.animation_contract = contract
	definition.animation_events = events
	definition.sound_set = sounds
	definition.generation_manifest = manifest
	definition.editable_scene_path = paths.scene
	if lighting_validation.rendering_profile != null:
		if ResourceSaver.save(lighting_validation.rendering_profile, paths.rendering_profile) != OK:
			result.errors.append("Could not save rendering profile: %s" % paths.rendering_profile)
			return result
		result.created_paths.append(paths.rendering_profile)
		definition.rendering_profile = load(paths.rendering_profile) as ActorRenderingProfile
		if definition.rendering_profile == null:
			result.errors.append("Could not reload rendering profile: %s" % paths.rendering_profile)
			_cleanup_created_files(result.created_paths)
			return result

	var resources_to_save := {
		paths.contract: contract,
		paths.events: events,
		paths.sounds: sounds,
		paths.manifest: manifest,
		paths.definition: definition,
	}
	for path in resources_to_save:
		if ResourceSaver.save(resources_to_save[path], path) != OK:
			result.errors.append("Could not save resource: %s" % path)
			_cleanup_created_files(result.created_paths)
			return result
		result.created_paths.append(path)

	# Reload the saved definition so PackedScene stores an external resource
	# reference instead of embedding a stale in-memory copy in the actor scene.
	var saved_definition := load(paths.definition) as ActorDefinition
	if saved_definition == null:
		result.errors.append("Could not reload saved actor definition: %s" % paths.definition)
		_cleanup_created_files(result.created_paths)
		return result
	var scene := _build_character_scene(saved_definition)
	if scene == null:
		result.errors.append("Could not build the character scene from the template. Check the Output panel for the specific Actor Pipeline error.")
		_cleanup_created_files(result.created_paths)
		return result
	if ResourceSaver.save(scene, paths.scene) != OK:
		result.errors.append("Could not save actor scene: %s" % paths.scene)
		_cleanup_created_files(result.created_paths)
		return result
	result.created_paths.append(paths.scene)
	result.actor_definition = saved_definition
	result.actor_scene = scene
	result.success = true
	return result


func _validate_request(request: ActorCreationRequest, result: ActorGenerationResult) -> void:
	if request == null:
		result.errors.append("Creation request is missing.")
		return
	if request.sprite_frames == null:
		result.errors.append("An imported SpriteFrames resource is required.")
	if not ActorPathPolicy.is_valid_actor_id(request.actor_id):
		result.errors.append("Actor ID must be lower snake_case and start with a letter.")
	if request.output_directory.is_empty() or not request.output_directory.begins_with("res://"):
		result.errors.append("Output directory must be inside the project (res://).")
	if request.archetype != ActorArchetype.Type.CHARACTER:
		result.errors.append("Only the CHARACTER archetype is implemented in version %s." % GENERATOR_VERSION)


func _build_contract(sprite_frames: SpriteFrames) -> AnimationContract:
	var contract := AnimationContract.new()
	for animation_name in sprite_frames.get_animation_names():
		var entry := AnimationContractEntry.new()
		entry.animation_name = animation_name
		entry.semantic_role = _suggest_role(animation_name)
		entry.required = entry.semantic_role in [&"locomotion.idle", &"combat.attack.primary"]
		entry.last_seen_frame_count = sprite_frames.get_frame_count(animation_name)
		entry.last_seen_speed_fps = sprite_frames.get_animation_speed(animation_name)
		entry.last_seen_loop = sprite_frames.get_animation_loop(animation_name)
		if entry.semantic_role == &"combat.attack.primary":
			entry.interruption_policy = AnimationContractEntry.InterruptionPolicy.LOCK_UNTIL_FINISHED
		contract.entries.append(entry)
	return contract


func _build_manifest(request: ActorCreationRequest, lighting_validation: ActorLightingValidationResult) -> ActorGenerationManifest:
	var manifest := ActorGenerationManifest.new()
	manifest.generator_version = GENERATOR_VERSION
	manifest.actor_id = request.actor_id
	manifest.source_resource_path = request.sprite_frames.resource_path
	manifest.generated_at_unix = Time.get_unix_time_from_system()
	manifest.lighting_mode = request.lighting_mode
	if request.lighting_mode != ActorLightingMode.Type.NONE:
		manifest.lighting_reference_path = lighting_validation.reference_path
		manifest.lighting_reference_fingerprint = lighting_validation.reference_fingerprint
		manifest.normal_map_path = request.normal_map_path
		manifest.specular_map_path = request.specular_map_path
		manifest.occlusion_map_path = request.occlusion_map_path
		manifest.emission_map_path = request.emission_map_path
	for animation_name in request.sprite_frames.get_animation_names():
		manifest.discovered_animations.append(animation_name)
		manifest.discovered_frame_counts[animation_name] = request.sprite_frames.get_frame_count(animation_name)
		manifest.discovered_looping[animation_name] = request.sprite_frames.get_animation_loop(animation_name)
	manifest.source_fingerprint = JSON.stringify(manifest.discovered_frame_counts)
	return manifest


func _build_character_scene(definition: ActorDefinition) -> PackedScene:
	var template := load(CHARACTER_TEMPLATE_PATH) as PackedScene
	if template == null:
		push_error("[Actor Pipeline] Character template could not be loaded: %s" % CHARACTER_TEMPLATE_PATH)
		return null
	var actor := template.instantiate() as ActorBase
	if actor == null:
		push_error("[Actor Pipeline] Character template root is not an ActorBase: %s" % CHARACTER_TEMPLATE_PATH)
		return null
	actor.definition = definition
	# Store the visual resource directly in the editable scene as well as in the
	# definition. This keeps the scene previewable in the editor and prevents an
	# empty AnimatedSprite2D before the runtime component initializes.
	var animated_sprite := actor.get_node_or_null("VisualRoot/AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite == null:
		push_error("[Actor Pipeline] Character template is missing VisualRoot/AnimatedSprite2D.")
		actor.queue_free()
		return null
	animated_sprite.sprite_frames = definition.sprite_frames
	var idle_entry := definition.animation_contract.get_entry_for_role(&"locomotion.idle") if definition.animation_contract != null else null
	if idle_entry != null:
		animated_sprite.animation = idle_entry.animation_name
	actor.set_meta(&"actor_pipeline_id", definition.actor_id)
	actor.set_meta(&"actor_pipeline_version", GENERATOR_VERSION)
	var scene := PackedScene.new()
	if scene.pack(actor) != OK:
		push_error("[Actor Pipeline] Could not pack the generated character scene.")
		actor.queue_free()
		return null
	actor.queue_free()
	return scene


func _suggest_role(animation_name: StringName) -> StringName:
	var normalized := String(animation_name).to_lower()
	var roles := {
		"idle": &"locomotion.idle",
		"walk": &"locomotion.walk",
		"run": &"locomotion.run",
		"hurt": &"damage.hurt",
		"damage": &"damage.hurt",
		"death": &"lifecycle.death",
		"die": &"lifecycle.death",
		"attack": &"combat.attack.primary",
		"attack_1": &"combat.attack.primary",
		"attack_primary": &"combat.attack.primary",
	}
	return roles.get(normalized, &"")


func _cleanup_created_files(paths: PackedStringArray) -> void:
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
