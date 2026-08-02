@tool
class_name ActorPipelineDock
extends VBoxContainer

const ActorFactoryScript := preload("res://addons/actor_pipeline/generation/actor_factory.gd")
const ActorCreationRequestScript := preload("res://addons/actor_pipeline/generation/actor_creation_request.gd")

var _aseprite_path: LineEdit
var _actor_id: LineEdit
var _display_name: LineEdit
var _output_directory: LineEdit
var _status: RichTextLabel
var _pending_aseprite_path := ""
var _create_after_import := false
var _import_load_attempts := 0

func _ready() -> void:
	custom_minimum_size.x = 280.0
	add_child(_label("Actor Pipeline", 18))
	add_child(_label("Create an editable CHARACTER actor from one Aseprite source file."))
	_aseprite_path = LineEdit.new()
	_aseprite_path.placeholder_text = "res://assets/source/aseprite/actors/knight/knight.aseprite"
	var source_row := HBoxContainer.new()
	source_row.add_child(_aseprite_path)
	var browse_button := Button.new()
	browse_button.text = "Browse"
	browse_button.pressed.connect(_browse_aseprite_file)
	source_row.add_child(browse_button)
	add_child(_field("Source Aseprite file", source_row))

	_actor_id = LineEdit.new()
	_actor_id.placeholder_text = "slime"
	add_child(_field("Actor ID", _actor_id))
	_display_name = LineEdit.new()
	_display_name.placeholder_text = "Slime"
	add_child(_field("Display name", _display_name))
	_output_directory = LineEdit.new()
	_output_directory.text = "res://actors"
	add_child(_field("Output directory", _output_directory))

	var create_button := Button.new()
	create_button.text = "Create Character Actor"
	create_button.pressed.connect(_create_actor)
	add_child(create_button)

	_status = RichTextLabel.new()
	_status.fit_content = true
	_status.custom_minimum_size.y = 100.0
	_status.bbcode_enabled = true
	_status.text = "[color=gray]Choose an Aseprite file, enter an ID and name, then create. Existing actor files are never overwritten.[/color]"
	add_child(_status)


func _browse_aseprite_file() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_RESOURCES
	dialog.filters = PackedStringArray(["*.aseprite, *.ase ; Aseprite files"])
	dialog.file_selected.connect(_on_aseprite_file_selected)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _on_aseprite_file_selected(path: String) -> void:
	_aseprite_path.text = path


func _reimport_source() -> void:
	var path := _normalize_resource_path(_aseprite_path.text.strip_edges())
	if path.is_empty() or not FileAccess.file_exists(path):
		_status.text = "[color=red]Choose an existing .aseprite file first.[/color]"
		return
	_aseprite_path.text = path
	_pending_aseprite_path = path
	_import_load_attempts = 0
	if _select_imported_sprite_frames():
		return
	if not _configure_sprite_frames_importer(path):
		_status.text = "[color=red]Could not configure Aseprite Wizard's SpriteFrames importer.[/color]"
		_create_after_import = false
		return
	var filesystem := EditorInterface.get_resource_filesystem()
	if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
		filesystem.resources_reimported.connect(_on_resources_reimported)
	filesystem.reimport_files(PackedStringArray([path]))
	_status.text = "[color=gray]Importing Aseprite source…[/color]"


func _on_resources_reimported(_resources: PackedStringArray) -> void:
	if _pending_aseprite_path.is_empty():
		return
	call_deferred("_load_imported_sprite_frames")


func _load_imported_sprite_frames() -> void:
	if not _select_imported_sprite_frames():
		if _import_load_attempts < 5:
			_import_load_attempts += 1
			call_deferred("_load_imported_sprite_frames")
			return
		_status.text = "[color=red]Aseprite import did not produce SpriteFrames.[/color]\nCheck the Godot Output panel for Aseprite Wizard errors."
		_create_after_import = false
		return


func _select_imported_sprite_frames() -> bool:
	var sprite_frames := _load_aseprite_sprite_frames(_pending_aseprite_path)
	if sprite_frames == null:
		return false
	_pending_aseprite_path = ""
	if _create_after_import:
		_create_after_import = false
		_create_actor_with_sprite_frames(sprite_frames)
	return true


func _load_aseprite_sprite_frames(source_path: String) -> SpriteFrames:
	var sprite_frames := ResourceLoader.load(source_path) as SpriteFrames
	if sprite_frames != null:
		return sprite_frames
	var import_config := ConfigFile.new()
	if import_config.load(source_path + ".import") != OK:
		return null
	var imported_path := str(import_config.get_value("remap", "path", ""))
	if imported_path.is_empty():
		return null
	return ResourceLoader.load(imported_path, "SpriteFrames") as SpriteFrames


func _configure_sprite_frames_importer(source_path: String) -> bool:
	# Aseprite Wizard initially assigns its no-op importer to newly discovered
	# .aseprite files. Switch the selected file to its SpriteFrames importer,
	# then ask Godot to run the normal import cycle below.
	var import_config := ConfigFile.new()
	var import_path := source_path + ".import"
	if import_config.load(import_path) != OK:
		return false
	import_config.set_value("remap", "importer", "aseprite_wizard.plugin.spriteframes")
	import_config.set_value("remap", "type", "SpriteFrames")
	import_config.set_value("params", "layer/exclude_layers_pattern", "")
	import_config.set_value("params", "layer/only_visible_layers", false)
	import_config.set_value("params", "sheet/sheet_type", "packed")
	import_config.set_value("params", "sheet/sheet_columns", 12)
	import_config.set_value("params", "sheet/frame_padding", 0)
	import_config.set_value("params", "sheet/scale", 1)
	import_config.set_value("params", "animation/round_fps", true)
	return import_config.save(import_path) == OK


func _normalize_resource_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return ProjectSettings.localize_path(path)


func _create_actor() -> void:
	var source_path := _normalize_resource_path(_aseprite_path.text.strip_edges())
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		_status.text = "[color=red]Choose an existing .aseprite file first.[/color]"
		return
	_aseprite_path.text = source_path
	var sprite_frames := _load_aseprite_sprite_frames(source_path)
	if sprite_frames == null:
		_create_after_import = true
		_reimport_source()
		return
	_create_actor_with_sprite_frames(sprite_frames)


func _create_actor_with_sprite_frames(sprite_frames: SpriteFrames) -> void:
	var request := ActorCreationRequestScript.new()
	request.sprite_frames = sprite_frames
	request.source_aseprite_path = _aseprite_path.text.strip_edges()
	request.actor_id = StringName(_actor_id.text.strip_edges())
	request.display_name = _display_name.text.strip_edges()
	request.output_directory = _output_directory.text.strip_edges().trim_suffix("/")
	request.archetype = ActorArchetype.Type.CHARACTER
	var result := ActorFactoryScript.new().create_actor(request)
	if result.success:
		EditorInterface.get_resource_filesystem().scan()
		_status.text = "[color=green]Created:[/color]\n" + "\n".join(result.created_paths)
	else:
		_status.text = "[color=red]Not created:[/color]\n" + "\n".join(result.errors)


func _field(label_text: String, control: Control) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.add_child(_label(label_text))
	container.add_child(control)
	return container


func _label(label_text: String, font_size := 0) -> Label:
	var label := Label.new()
	label.text = label_text
	if font_size > 0:
		label.add_theme_font_size_override(&"font_size", font_size)
	return label
