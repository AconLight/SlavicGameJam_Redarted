@tool
class_name AnimationContractEntry
extends Resource

enum LoopPolicy { FROM_SOURCE, FORCE_LOOP, FORCE_NO_LOOP }
enum InterruptionPolicy { INTERRUPTIBLE, LOCK_UNTIL_FINISHED, NEVER_INTERRUPT }

@export var animation_name: StringName
@export var required := false
@export var semantic_role: StringName
@export var loop_policy := LoopPolicy.FROM_SOURCE
@export var interruption_policy := InterruptionPolicy.INTERRUPTIBLE

@export_group("Generated Metadata")
@export var last_seen_frame_count := 0
@export var last_seen_speed_fps := 0.0
@export var last_seen_loop := false
