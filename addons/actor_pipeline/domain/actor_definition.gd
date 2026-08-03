@tool
class_name ActorDefinition
extends Resource

@export_group("Identity")
@export var actor_id: StringName
@export var display_name := ""
@export var archetype: ActorArchetype.Type = ActorArchetype.Type.CHARACTER

@export_group("Source")
@export var sprite_frames: SpriteFrames
@export_file("*.ase", "*.aseprite") var source_aseprite_path := ""
@export var generation_manifest: ActorGenerationManifest

@export_group("Animation")
@export var animation_contract: AnimationContract
@export var animation_events: AnimationEventSet

@export_group("Audio")
@export var sound_set: ActorSoundSet

@export_group("Rendering")
@export var rendering_profile: ActorRenderingProfile

@export_group("Gameplay Defaults")
@export var maximum_health := 100.0
@export var movement_speed := 100.0
@export var contact_damage := 0.0

@export_group("Scene")
@export_file("*.tscn") var editable_scene_path := ""
