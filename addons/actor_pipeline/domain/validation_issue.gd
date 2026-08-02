@tool
class_name ActorValidationIssue
extends Resource

enum Severity { INFO, WARNING, ERROR }

@export var severity := Severity.ERROR
@export var code: StringName
@export_multiline var message := ""
@export var affected_resource_path := ""
@export var property_path := ""
@export var suggested_action := ""
