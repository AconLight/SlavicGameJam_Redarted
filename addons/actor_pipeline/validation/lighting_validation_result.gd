@tool
class_name ActorLightingValidationResult
extends RefCounted

var errors := PackedStringArray()
var warnings := PackedStringArray()
var rendering_profile: ActorRenderingProfile
var reference_path := ""
var reference_fingerprint := ""

func is_valid() -> bool:
	return errors.is_empty()
