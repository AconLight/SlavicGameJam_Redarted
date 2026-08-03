@tool
class_name ActorSpriteFramesBundler
extends RefCounted


func bundle(source: SpriteFrames) -> SpriteFrames:
	var bundled := SpriteFrames.new()
	bundled.remove_animation(&"default")
	var atlas_cache := {}
	for animation_name in source.get_animation_names():
		bundled.add_animation(animation_name)
		bundled.set_animation_speed(animation_name, source.get_animation_speed(animation_name))
		bundled.set_animation_loop(animation_name, source.get_animation_loop(animation_name))
		for frame_index in range(source.get_frame_count(animation_name)):
			var texture := source.get_frame_texture(animation_name, frame_index)
			var copied_texture := _copy_frame_texture(texture, atlas_cache)
			if copied_texture != null:
				bundled.add_frame(animation_name, copied_texture, source.get_frame_duration(animation_name, frame_index))
	return bundled


func _copy_frame_texture(texture: Texture2D, atlas_cache: Dictionary) -> Texture2D:
	if texture == null:
		return null
	if texture is AtlasTexture:
		var source_atlas := texture as AtlasTexture
		var copied_atlas := AtlasTexture.new()
		copied_atlas.atlas = _copy_atlas_texture(source_atlas.atlas, atlas_cache)
		copied_atlas.region = source_atlas.region
		copied_atlas.filter_clip = source_atlas.filter_clip
		return copied_atlas
	return _copy_atlas_texture(texture, atlas_cache)


func _copy_atlas_texture(source: Texture2D, atlas_cache: Dictionary) -> Texture2D:
	if source == null:
		return null
	var cache_key := source.get_instance_id()
	if atlas_cache.has(cache_key):
		return atlas_cache[cache_key]
	var image := source.get_image()
	if image == null or image.is_empty():
		return null
	var copied := ImageTexture.create_from_image(image)
	atlas_cache[cache_key] = copied
	return copied
