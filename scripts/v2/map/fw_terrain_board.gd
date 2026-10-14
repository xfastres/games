class_name FwTerrainBoard
extends RefCounted

## 方格 TileSet。道路用四边地形连接选图，草地是普通图块。
## Godot 4.7 的等距瓦片在两种地形模式下都缺少左右邻接位，不能连接东西向道路。
## 因此 TileMapLayer 使用方格投影。地形种类不写入逻辑阻挡。
const GRASS := "grass"
const ROAD := "road"
const TILE_W := 64
const TILE_H := 64
const SOURCE_ID := 0
const TERRAIN_SET := 0
const ROAD_TERRAIN := 0
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

const UNUSABLE_ART: PackedStringArray = [
	"res://assets/sprites/terrain/grass_tile_01.png",
	"res://assets/sprites/terrain/grass_tile_02.png",
	"res://assets/sprites/terrain/grass_tile_03.png",
	"res://assets/sprites/terrain/grass_tile_04.png",
]

var columns: int
var rows: int
var _kinds: Dictionary = {}
var _tileset: TileSet
var _source: TileSetAtlasSource


func _init(map_columns: int, map_rows: int) -> void:
	columns = map_columns
	rows = map_rows


func set_kind(cell: Vector2i, kind: String) -> String:
	if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
		return "地形超出地图 (%d, %d)" % [cell.x, cell.y]
	if kind != GRASS and kind != ROAD:
		return "未知地形：%s" % kind
	_kinds[cell] = kind
	return ""


func kind_at(cell: Vector2i) -> String:
	return str(_kinds.get(cell, GRASS))


func tileset() -> TileSet:
	if _tileset == null:
		_build_tileset()
	return _tileset


func source() -> TileSetAtlasSource:
	if _source == null:
		_build_tileset()
	return _source


func apply(layer: TileMapLayer) -> void:
	layer.tile_set = tileset()
	layer.clear()
	var roads: Array[Vector2i] = []
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			if kind_at(cell) == ROAD:
				roads.append(cell)
			else:
				layer.set_cell(cell, SOURCE_ID, _grass_coords(cell))
	if roads.is_empty():
		return
	layer.set_cells_terrain_connect(roads, TERRAIN_SET, ROAD_TERRAIN, true)
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			if kind_at(cell) != ROAD:
				layer.set_cell(cell, SOURCE_ID, _grass_coords(cell))


func _grass_coords(cell: Vector2i) -> Vector2i:
	var variant := absi(cell.x * 73856093 ^ cell.y * 19349663) % 4
	return Vector2i(variant, 0)


func _build_tileset() -> void:
	var image := Image.create(TILE_W * 8, TILE_H * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var grasses: Array[Color] = [
		Color("3f6b3a"),
		Color("4d7a42"),
		Color("3a6238"),
		Color("587848"),
	]
	for index in grasses.size():
		_paint_square(image, Vector2i(index, 0), grasses[index], index, -1)
	for mask in 16:
		var coords := Vector2i(mask % 8, 1 + int(mask / 8.0))
		_paint_square(image, coords, grasses[mask % 4], mask, mask)
	_source = TileSetAtlasSource.new()
	_source.texture = ImageTexture.create_from_image(image)
	_source.texture_region_size = Vector2i(TILE_W, TILE_H)
	for y in 4:
		for x in 8:
			if y == 0 and x > 3:
				continue
			_source.create_tile(Vector2i(x, y))
	_tileset = TileSet.new()
	_tileset.tile_shape = TileSet.TILE_SHAPE_SQUARE
	_tileset.tile_size = Vector2i(TILE_W, TILE_H)
	_tileset.add_source(_source, SOURCE_ID)
	_tileset.add_terrain_set(TERRAIN_SET)
	_tileset.set_terrain_set_mode(TERRAIN_SET, TileSet.TERRAIN_MODE_MATCH_SIDES)
	_tileset.add_terrain(TERRAIN_SET, ROAD_TERRAIN)
	_tileset.set_terrain_name(TERRAIN_SET, ROAD_TERRAIN, "road")
	for mask in 16:
		var coords := Vector2i(mask % 8, 1 + int(mask / 8.0))
		var data := _source.get_tile_data(coords, 0)
		data.set_terrain_set(TERRAIN_SET)
		data.set_terrain(ROAD_TERRAIN)
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_TOP_SIDE, _peering(mask, NORTH))
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_RIGHT_SIDE, _peering(mask, EAST))
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_BOTTOM_SIDE, _peering(mask, SOUTH))
		data.set_terrain_peering_bit(TileSet.CELL_NEIGHBOR_LEFT_SIDE, _peering(mask, WEST))


func _peering(mask: int, flag: int) -> int:
	if (mask & flag) != 0:
		return ROAD_TERRAIN
	return -1


func _paint_square(image: Image, coords: Vector2i, grass: Color, salt: int, road_mask: int) -> void:
	var origin := coords * TILE_W
	image.fill_rect(Rect2i(origin, Vector2i(TILE_W, TILE_H)), grass)
	var speck := grass.lightened(0.18)
	for index in 6:
		var px := (salt * 17 + index * 29) % (TILE_W - 4)
		var py := (salt * 13 + index * 19) % (TILE_H - 4)
		image.set_pixel(origin.x + 2 + px, origin.y + 2 + py, speck)
	if road_mask < 0:
		return
	var road := Color("c4a06a")
	var edge := Color("8d6840")
	image.fill_rect(Rect2i(origin + Vector2i(22, 22), Vector2i(20, 20)), road)
	if (road_mask & NORTH) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(22, 0), Vector2i(20, 32)), road)
	if (road_mask & SOUTH) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(22, 32), Vector2i(20, 32)), road)
	if (road_mask & WEST) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(0, 22), Vector2i(32, 20)), road)
	if (road_mask & EAST) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(32, 22), Vector2i(32, 20)), road)
	image.fill_rect(Rect2i(origin + Vector2i(22, 22), Vector2i(20, 20)), road)
	if (road_mask & NORTH) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(22, 22), Vector2i(20, 2)), edge)
	if (road_mask & SOUTH) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(22, 40), Vector2i(20, 2)), edge)
	if (road_mask & WEST) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(22, 22), Vector2i(2, 20)), edge)
	if (road_mask & EAST) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(40, 22), Vector2i(2, 20)), edge)
