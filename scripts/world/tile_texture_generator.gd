class_name TileTextureGenerator
extends RefCounted
## Generates isometric diamond tile textures at runtime

const TILE_WIDTH := 128
const TILE_HEIGHT := 64


static func create_isometric_tile(color: Color, outline_color: Color = Color.TRANSPARENT) -> ImageTexture:
	var image := Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var center_x := int(TILE_WIDTH / 2)
	var center_y := int(TILE_HEIGHT / 2)

	for y in range(TILE_HEIGHT):
		for x in range(TILE_WIDTH):
			if _is_inside_diamond(x, y, center_x, center_y):
				if outline_color.a > 0 and _is_on_edge(x, y, center_x, center_y):
					image.set_pixel(x, y, outline_color)
				else:
					image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


static func _is_inside_diamond(x: int, y: int, cx: int, cy: int) -> bool:
	var dx := absf(x - cx) / float(cx)
	var dy := absf(y - cy) / float(cy)
	return (dx + dy) <= 1.0


static func _is_on_edge(x: int, y: int, cx: int, cy: int, thickness: float = 0.05) -> bool:
	var dx := absf(x - cx) / float(cx)
	var dy := absf(y - cy) / float(cy)
	var dist := dx + dy
	return dist > (1.0 - thickness) and dist <= 1.0


static func create_tile_atlas(tile_colors: Array[Color], outline_colors: Array[Color] = []) -> ImageTexture:
	var tile_count := tile_colors.size()
	var atlas_width := TILE_WIDTH * tile_count
	var atlas_height := TILE_HEIGHT

	var atlas_image := Image.create(atlas_width, atlas_height, false, Image.FORMAT_RGBA8)
	atlas_image.fill(Color.TRANSPARENT)

	for i in range(tile_count):
		var outline := outline_colors[i] if i < outline_colors.size() else Color(0, 0, 0, 0.3)
		var tile_image := _create_tile_image(tile_colors[i], outline)
		var dest_rect := Rect2i(i * TILE_WIDTH, 0, TILE_WIDTH, TILE_HEIGHT)
		atlas_image.blit_rect(tile_image, Rect2i(0, 0, TILE_WIDTH, TILE_HEIGHT), dest_rect.position)

	return ImageTexture.create_from_image(atlas_image)


static func _create_tile_image(color: Color, outline_color: Color) -> Image:
	var image := Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var center_x := int(TILE_WIDTH / 2)
	var center_y := int(TILE_HEIGHT / 2)

	for y in range(TILE_HEIGHT):
		for x in range(TILE_WIDTH):
			if _is_inside_diamond(x, y, center_x, center_y):
				if outline_color.a > 0 and _is_on_edge(x, y, center_x, center_y):
					image.set_pixel(x, y, outline_color)
				else:
					image.set_pixel(x, y, color)

	return image
