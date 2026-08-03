@tool
class_name ActorPipelineDock
extends VBoxContainer

const ActorFactoryScript := preload("res://addons/actor_pipeline/generation/actor_factory.gd")
const ActorCreationRequestScript := preload("res://addons/actor_pipeline/generation/actor_creation_request.gd")
const LightingReferenceExporterScript := preload("res://addons/actor_pipeline/generation/lighting_reference_exporter.gd")
const LightingMapLocatorScript := preload("res://addons/actor_pipeline/generation/lighting_map_locator.gd")
const LAIGTER_COMMAND_SETTING := "actor_pipeline/lighting/laigter_command"

var _aseprite_path: LineEdit
var _actor_id: LineEdit
var _display_name: LineEdit
var _output_directory: LineEdit
var _lighting_mode: OptionButton
var _lighting_options_container: VBoxContainer
var _lighting_details: Label
var _laigter_command: LineEdit
var _status: RichTextLabel
var _pending_aseprite_path := ""
var _create_after_import := false
var _import_load_attempts := 0
var _export_reference_after_import := false
var _auto_pending_sprite_frames: SpriteFrames
var _auto_pending_maps := {}

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
	var export_reference_button := Button.new()
	export_reference_button.text = "Export Lighting Reference Sheet"
	export_reference_button.tooltip_text = "Exports the exact imported atlas sheet used by SpriteFrames, plus reference metadata."
	export_reference_button.pressed.connect(_export_lighting_reference)
	add_child(export_reference_button)

	_actor_id = LineEdit.new()
	_actor_id.placeholder_text = "slime"
	add_child(_field("Actor ID", _actor_id))
	_display_name = LineEdit.new()
	_display_name.placeholder_text = "Slime"
	add_child(_field("Display name", _display_name))
	_output_directory = LineEdit.new()
	_output_directory.text = "res://actors"
	add_child(_field("Output directory", _output_directory))

	add_child(_label("Lighting Maps", 16))
	_lighting_mode = OptionButton.new()
	_lighting_mode.add_item("None", ActorLightingMode.Type.NONE)
	_lighting_mode.add_item("From Lighting Folder", ActorLightingMode.Type.FROM_LIGHTING_DIRECTORY)
	_lighting_mode.add_item("Auto (Laigter Defaults)", ActorLightingMode.Type.AUTO_LAIGTER)
	_lighting_mode.item_selected.connect(_on_lighting_mode_selected)
	add_child(_field("Map source", _lighting_mode))
	_lighting_options_container = VBoxContainer.new()
	_lighting_details = _label("")
	_lighting_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lighting_options_container.add_child(_lighting_details)
	_laigter_command = LineEdit.new()
	_laigter_command.placeholder_text = "C:/tools/Laigter/laigter.exe"
	_laigter_command.text = _saved_laigter_command()
	_laigter_command.text_changed.connect(_save_laigter_command)
	var laigter_row := HBoxContainer.new()
	laigter_row.add_child(_laigter_command)
	var laigter_browse := Button.new()
	laigter_browse.text = "Browse"
	laigter_browse.pressed.connect(_browse_laigter_command)
	laigter_row.add_child(laigter_browse)
	_lighting_options_container.add_child(_field("Laigter executable", laigter_row))
	add_child(_lighting_options_container)
	_set_lighting_options_visibility()

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


func _export_lighting_reference() -> void:
	var source_path := _normalize_resource_path(_aseprite_path.text.strip_edges())
	if source_path.is_empty() or not FileAccess.file_exists(source_path):
		_status.text = "[color=red]Choose an existing .aseprite file first.[/color]"
		return
	_aseprite_path.text = source_path
	var sprite_frames := _load_aseprite_sprite_frames(source_path)
	if sprite_frames == null:
		_export_reference_after_import = true
		_reimport_source()
		return
	_export_lighting_reference_with_sprite_frames(sprite_frames)


func _export_lighting_reference_with_sprite_frames(sprite_frames: SpriteFrames) -> void:
	var export_result := LightingReferenceExporterScript.new().export_reference(_aseprite_path.text.strip_edges(), sprite_frames)
	if export_result.has("error"):
		_status.text = "[color=red]Lighting reference not exported:[/color]\n" + str(export_result.error)
		return
	EditorInterface.get_resource_filesystem().scan()
	_status.text = "[color=green]Lighting reference exported:[/color]\n" + str(export_result.png_path) + "\n" + str(export_result.metadata_path)


func _on_lighting_mode_selected(_index: int) -> void:
	_set_lighting_options_visibility()


func _set_lighting_options_visibility() -> void:
	if _lighting_options_container == null or _lighting_mode == null:
		return
	var mode := _lighting_mode.get_selected_id()
	_lighting_options_container.visible = mode != ActorLightingMode.Type.NONE
	if mode == ActorLightingMode.Type.FROM_LIGHTING_DIRECTORY:
		_lighting_details.text = "Uses the source file's lighting folder automatically: _n normal, _s specular, _o occlusion, _e emission."
		_laigter_command.get_parent().get_parent().visible = false
	elif mode == ActorLightingMode.Type.AUTO_LAIGTER:
		_lighting_details.text = "Exports the reference sheet, then Laigter generates _n, _s, and _o with its default settings."
		_laigter_command.get_parent().get_parent().visible = true


func _browse_laigter_command() -> void:
	var dialog := EditorFileDialog.new()
	dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.exe ; Laigter executable"])
	dialog.file_selected.connect(func(path: String) -> void: _laigter_command.text = path)
	add_child(dialog)
	dialog.popup_centered_ratio(0.7)


func _saved_laigter_command() -> String:
	var settings := EditorInterface.get_editor_settings()
	return str(settings.get_setting(LAIGTER_COMMAND_SETTING)) if settings.has_setting(LAIGTER_COMMAND_SETTING) else ""


func _save_laigter_command(command: String) -> void:
	EditorInterface.get_editor_settings().set_setting(LAIGTER_COMMAND_SETTING, command.strip_edges())


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
	if not _auto_pending_maps.is_empty():
		call_deferred("_continue_auto_actor_creation")
		return
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
	if _export_reference_after_import:
		_export_reference_after_import = false
		_export_lighting_reference_with_sprite_frames(sprite_frames)
		return true
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
	import_config.set_value("params", "layer/only_visible_layers", true)
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
	var mode := _lighting_mode.get_selected_id()
	var maps := {}
	if mode == ActorLightingMode.Type.FROM_LIGHTING_DIRECTORY:
		maps = LightingMapLocatorScript.new().find_maps(_aseprite_path.text.strip_edges())
	elif mode == ActorLightingMode.Type.AUTO_LAIGTER:
		var auto_result := _generate_laigter_maps(sprite_frames)
		if auto_result.has("error"):
			_status.text = "[color=red]Auto lighting not generated:[/color]\n" + str(auto_result.error)
			return
		_auto_pending_sprite_frames = sprite_frames
		_auto_pending_maps = auto_result.maps
		var filesystem := EditorInterface.get_resource_filesystem()
		if not filesystem.resources_reimported.is_connected(_on_resources_reimported):
			filesystem.resources_reimported.connect(_on_resources_reimported)
		# Laigter replaces the PNG files and removes their .import sidecars. A scan
		# is required before reimporting so Godot discovers them as new textures.
		filesystem.scan()
		_status.text = "[color=gray]Discovering and importing Laigter mapsâ€¦[/color]"
		return
	_create_actor_from_maps(sprite_frames, mode, maps)


func _continue_auto_actor_creation() -> void:
	var normal_path := str(_auto_pending_maps.get("normal", ""))
	if normal_path.is_empty() or (ResourceLoader.load(normal_path, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D) == null:
		_status.text = "[color=red]Auto lighting was not imported:[/color]\nGodot did not create a texture resource for " + normal_path
		_auto_pending_sprite_frames = null
		_auto_pending_maps = {}
		return
	_create_actor_from_maps(_auto_pending_sprite_frames, ActorLightingMode.Type.AUTO_LAIGTER, _auto_pending_maps)
	_auto_pending_sprite_frames = null
	_auto_pending_maps = {}


func _create_actor_from_maps(sprite_frames: SpriteFrames, mode: int, maps: Dictionary) -> void:
	var request := ActorCreationRequestScript.new()
	request.sprite_frames = sprite_frames
	request.source_aseprite_path = _aseprite_path.text.strip_edges()
	request.actor_id = StringName(_actor_id.text.strip_edges())
	request.display_name = _display_name.text.strip_edges()
	request.output_directory = _output_directory.text.strip_edges().trim_suffix("/")
	request.archetype = ActorArchetype.Type.CHARACTER
	request.lighting_mode = mode
	request.normal_map_path = str(maps.get("normal", ""))
	request.specular_map_path = str(maps.get("specular", ""))
	request.occlusion_map_path = str(maps.get("occlusion", ""))
	request.emission_map_path = str(maps.get("emission", ""))
	var result := ActorFactoryScript.new().create_actor(request)
	if result.success:
		EditorInterface.get_resource_filesystem().scan()
		_status.text = "[color=green]Created:[/color]\n" + "\n".join(result.created_paths)
		if not result.warnings.is_empty():
			_status.text += "\n[color=yellow]Warnings:[/color]\n" + "\n".join(result.warnings)
	else:
		_status.text = "[color=red]Not created:[/color]\n" + "\n".join(result.errors)

func _generate_laigter_maps(sprite_frames: SpriteFrames) -> Dictionary:
	var command := _laigter_command.text.strip_edges()
	if command.is_empty() or not FileAccess.file_exists(command):
		return {"error": "Set the path to laigter.exe once in the Auto mode section."}
	var reference_result := LightingReferenceExporterScript.new().export_reference(_aseprite_path.text.strip_edges(), sprite_frames)
	if reference_result.has("error"):
		return {"error": str(reference_result.error)}
	var output := []
	var exit_code := OS.execute(command, [
		"--no-gui",
		"--diffuse", ProjectSettings.globalize_path(str(reference_result.png_path)),
		"--normal",
		"--specular",
		"--occlusion",
	], output, true, true)
	var maps := LightingMapLocatorScript.new().find_maps(_aseprite_path.text.strip_edges())
	if not maps.has("normal"):
		return {"error": "Laigter did not generate the required _n normal map.\n" + "\n".join(output)}
	if exit_code != 0:
		push_warning("[Actor Pipeline] Laigter returned exit code %s after generating maps." % exit_code)
	return {"maps": maps}


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
