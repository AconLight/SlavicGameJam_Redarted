class_name ActorCreationRequest
extends RefCounted

var sprite_frames: SpriteFrames
var source_aseprite_path := ""
var actor_id: StringName
var display_name := ""
var archetype: ActorArchetype.Type = ActorArchetype.Type.CHARACTER
var output_directory := ""
var lighting_mode: ActorLightingMode.Type = ActorLightingMode.Type.NONE
var normal_map_path := ""
var specular_map_path := ""
var occlusion_map_path := ""
var emission_map_path := ""
