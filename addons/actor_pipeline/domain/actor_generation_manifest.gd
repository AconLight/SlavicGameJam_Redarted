@tool
class_name ActorGenerationManifest
extends Resource

@export var generator_version := "0.1.0"
@export var actor_id: StringName
@export var source_resource_path := ""
@export var source_fingerprint := ""
@export var generated_at_unix := 0
@export var discovered_animations: Array[StringName] = []
@export var discovered_frame_counts: Dictionary = {}
@export var discovered_looping: Dictionary = {}

@export_group("Rendering Sources")
@export var lighting_mode: ActorLightingMode.Type = ActorLightingMode.Type.NONE
@export var lighting_reference_path := ""
@export var lighting_reference_fingerprint := ""
@export var normal_map_path := ""
@export var specular_map_path := ""
@export var occlusion_map_path := ""
@export var emission_map_path := ""
