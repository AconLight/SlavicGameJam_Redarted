@tool
class_name ActorLightingMapLocator
extends RefCounted

const MAP_SUFFIXES := {
	"normal": "n",
	"specular": "s",
	"occlusion": "o",
	"emission": "e",
}


func find_maps(source_aseprite_path: String) -> Dictionary:
	var basename := source_aseprite_path.get_file().get_basename()
	var directory := source_aseprite_path.get_base_dir().path_join("lighting")
	var maps := {}
	for map_id in MAP_SUFFIXES:
		var path := directory.path_join("%s_lighting_reference_%s.png" % [basename, MAP_SUFFIXES[map_id]])
		if FileAccess.file_exists(path):
			maps[map_id] = path
	return maps


func reference_paths(source_aseprite_path: String) -> Dictionary:
	var basename := source_aseprite_path.get_file().get_basename()
	var directory := source_aseprite_path.get_base_dir().path_join("lighting")
	return {
		"directory": directory,
		"png": directory.path_join("%s_lighting_reference.png" % basename),
		"metadata": directory.path_join("%s_lighting_reference.json" % basename),
	}
