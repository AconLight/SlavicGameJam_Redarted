class_name ActorCreationRequest
extends RefCounted

var sprite_frames: SpriteFrames
var source_aseprite_path := ""
var actor_id: StringName
var display_name := ""
var archetype: ActorArchetype.Type = ActorArchetype.Type.CHARACTER
var output_directory := ""
