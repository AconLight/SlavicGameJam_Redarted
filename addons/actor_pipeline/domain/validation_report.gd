@tool
class_name ActorValidationReport
extends Resource

@export var issues: Array[ActorValidationIssue] = []

func has_errors() -> bool:
	for issue in issues:
		if issue != null and issue.severity == ActorValidationIssue.Severity.ERROR:
			return true
	return false


func add_issue(
	severity: ActorValidationIssue.Severity,
	code: StringName,
	message: String,
	suggested_action := ""
) -> void:
	var issue := ActorValidationIssue.new()
	issue.severity = severity
	issue.code = code
	issue.message = message
	issue.suggested_action = suggested_action
	issues.append(issue)
