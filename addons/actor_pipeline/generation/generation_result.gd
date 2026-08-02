class_name ActorGenerationResult
extends RefCounted

var success := false
var created_paths := PackedStringArray()
var warnings := PackedStringArray()
var errors := PackedStringArray()
var actor_definition: ActorDefinition
var actor_scene: PackedScene
