@tool
class_name ActorValidator
extends RefCounted

func validate_definition(definition: ActorDefinition) -> ActorValidationReport:
	var report := ActorValidationReport.new()
	if definition == null:
		report.add_issue(ActorValidationIssue.Severity.ERROR, &"actor.missing_definition", "Actor definition is missing.")
		return report
	if definition.actor_id == &"":
		report.add_issue(ActorValidationIssue.Severity.ERROR, &"actor.empty_id", "Actor ID is empty.", "Set a stable snake_case actor ID.")
	if definition.sprite_frames == null:
		report.add_issue(ActorValidationIssue.Severity.ERROR, &"actor.missing_sprite_frames", "SpriteFrames is missing.", "Assign an imported SpriteFrames resource.")
	if definition.animation_contract == null:
		report.add_issue(ActorValidationIssue.Severity.ERROR, &"actor.missing_contract", "Animation contract is missing.")
		return report
	_validate_contract(definition, report)
	_validate_events(definition, report)
	return report


func _validate_contract(definition: ActorDefinition, report: ActorValidationReport) -> void:
	var seen_roles := {}
	for entry in definition.animation_contract.entries:
		if entry == null:
			continue
		if entry.semantic_role != &"":
			if seen_roles.has(entry.semantic_role):
				report.add_issue(ActorValidationIssue.Severity.ERROR, &"contract.duplicate_role", "Duplicate semantic role: %s" % entry.semantic_role)
			seen_roles[entry.semantic_role] = true
		if definition.sprite_frames != null and not definition.sprite_frames.has_animation(entry.animation_name):
			report.add_issue(ActorValidationIssue.Severity.ERROR, &"contract.missing_animation", "Mapped animation is missing: %s" % entry.animation_name)


func _validate_events(definition: ActorDefinition, report: ActorValidationReport) -> void:
	if definition.animation_events == null:
		return
	var seen_ids := {}
	for event in definition.animation_events.events:
		if event == null:
			continue
		if seen_ids.has(event.event_id):
			report.add_issue(ActorValidationIssue.Severity.ERROR, &"event.duplicate_id", "Duplicate event ID: %s" % event.event_id)
		seen_ids[event.event_id] = true
		var entry := definition.animation_contract.get_entry_for_role(event.animation_role)
		if event.animation_name_override == &"" and entry == null:
			report.add_issue(ActorValidationIssue.Severity.ERROR, &"event.missing_role", "Event %s refers to a missing role." % event.event_id)
			continue
		var animation_name := event.animation_name_override if event.animation_name_override != &"" else entry.animation_name
		if definition.sprite_frames != null and definition.sprite_frames.has_animation(animation_name) and event.frame >= definition.sprite_frames.get_frame_count(animation_name):
			report.add_issue(ActorValidationIssue.Severity.ERROR, &"event.frame_out_of_range", "Event %s targets frame %d outside %s." % [event.event_id, event.frame, animation_name])
