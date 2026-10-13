class_name TerrainField
extends RefCounted

## 方格地形。逻辑种类和寻路阻挡分开。
## 素材包里的草地是菱形，道路裁图只有几像素，不能拿来拼接，所以图块在运行时画成 64 像素方块。

const GRASS := "grass"
const DIRT := "dirt"
const ROAD := "road"
const STONE := "stone"
const KINDS: PackedStringArray = [GRASS, DIRT, ROAD, STONE]
const TILE_SIZE := 64
const SOURCE_ID := 0
const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8

const UNUSABLE_ART: PackedStringArray = [
	"res://assets/sprites/terrain/grass_tile_01.png",
	"res://assets/sprites/terrain/grass_tile_02.png",
	"res://assets/sprites/terrain/grass_tile_03.png",
	"res://assets/sprites/terrain/grass_tile_04.png",
	"res://assets/source/art_pack_a/terrain/dirt_tile.png",
	"res://assets/source/art_pack_a/terrain/stone_tile.png",
	"res://assets/source/art_pack_a/terrain/road_straight.png",
	"res://assets/source/art_pack_a/terrain/road_corner.png",
	"res://assets/source/art_pack_a/terrain/road_t_junction.png",
	"res://assets/source/art_pack_a/terrain/road_crossroad.png",
]

var columns: int
var rows: int
var _kinds: Dictionary = {}
var _tileset: TileSet


func _init(map_columns: int, map_rows: int) -> void:
	columns = map_columns
	rows = map_rows


func set_kind(cell: Vector2i, kind: String) -> String:
	if not _inside(cell):
		return "地形超出地图 (%d, %d)" % [cell.x, cell.y]
	if kind not in KINDS:
		return "未知地形：%s" % kind
	_kinds[cell] = kind
	return ""


func kind_at(cell: Vector2i) -> String:
	return str(_kinds.get(cell, GRASS))


## 道路与上下左右道路的连接。不是道路时返回 0。
func road_mask(cell: Vector2i) -> int:
	if kind_at(cell) != ROAD:
		return 0
	var mask := 0
	if kind_at(cell + Vector2i(0, -1)) == ROAD:
		mask |= NORTH
	if kind_at(cell + Vector2i(1, 0)) == ROAD:
		mask |= EAST
	if kind_at(cell + Vector2i(0, 1)) == ROAD:
		mask |= SOUTH
	if kind_at(cell + Vector2i(-1, 0)) == ROAD:
		mask |= WEST
	return mask


func atlas_coords(cell: Vector2i) -> Vector2i:
	var kind := kind_at(cell)
	if kind == DIRT:
		return Vector2i(4, 0)
	if kind == STONE:
		return Vector2i(5, 0)
	if kind == ROAD:
		var mask := road_mask(cell)
		return Vector2i(mask % 8, 1 + int(mask / 8.0))
	var variant := absi(cell.x * 73856093 ^ cell.y * 19349663) % 4
	return Vector2i(variant, 0)


func tileset() -> TileSet:
	if _tileset == null:
		_tileset = _build_tileset()
	return _tileset


func apply(layer: TileMapLayer) -> void:
	layer.tile_set = tileset()
	layer.clear()
	for y in rows:
		for x in columns:
			var cell := Vector2i(x, y)
			layer.set_cell(cell, SOURCE_ID, atlas_coords(cell))


func refresh(layer: TileMapLayer, cell: Vector2i) -> void:
	if layer.tile_set == null:
		layer.tile_set = tileset()
	_paint_cell(layer, cell)
	for direction in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]:
		_paint_cell(layer, cell + direction)


func _paint_cell(layer: TileMapLayer, cell: Vector2i) -> void:
	if not _inside(cell):
		return
	layer.set_cell(cell, SOURCE_ID, atlas_coords(cell))


func _build_tileset() -> TileSet:
	var image := Image.create(TILE_SIZE * 8, TILE_SIZE * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var grasses: Array[Color] = [
		Color("3f6b3a"),
		Color("4d7a42"),
		Color("3a6238"),
		Color("587848"),
	]
	for index in grasses.size():
		_paint_ground(image, Vector2i(index, 0), grasses[index], index)
	_paint_ground(image, Vector2i(4, 0), Color("8a6240"), 2)
	_paint_ground(image, Vector2i(5, 0), Color("7d807c"), 5)
	for mask in 16:
		var coords := Vector2i(mask % 8, 1 + int(mask / 8.0))
		_paint_ground(image, coords, Color("4d7a42"), mask % 4)
		_paint_road(image, coords, mask)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for y in 4:
		for x in 8:
			if y == 0 and x > 5:
				continue
			source.create_tile(Vector2i(x, y))
	var set := TileSet.new()
	set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	set.add_source(source, SOURCE_ID)
	return set


func _paint_ground(image: Image, coords: Vector2i, base: Color, salt: int) -> void:
	var origin := coords * TILE_SIZE
	image.fill_rect(Rect2i(origin, Vector2i(TILE_SIZE, TILE_SIZE)), base)
	var speck := base.lightened(0.18)
	for index in 6:
		var px := (salt * 17 + index * 29) % (TILE_SIZE - 4)
		var py := (salt * 13 + index * 19) % (TILE_SIZE - 4)
		image.set_pixel(origin.x + 2 + px, origin.y + 2 + py, speck)


func _paint_road(image: Image, coords: Vector2i, mask: int) -> void:
	var origin := coords * TILE_SIZE
	var road := Color("b08958")
	var edge := Color("8d6840")
	image.fill_rect(Rect2i(origin + Vector2i(18, 18), Vector2i(28, 28)), road)
	if (mask & NORTH) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(18, 0), Vector2i(28, 32)), road)
	if (mask & SOUTH) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(18, 32), Vector2i(28, 32)), road)
	if (mask & WEST) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(0, 18), Vector2i(32, 28)), road)
	if (mask & EAST) != 0:
		image.fill_rect(Rect2i(origin + Vector2i(32, 18), Vector2i(32, 28)), road)
	image.fill_rect(Rect2i(origin + Vector2i(18, 18), Vector2i(28, 28)), road)
	if (mask & NORTH) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(18, 18), Vector2i(28, 2)), edge)
	if (mask & SOUTH) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(18, 44), Vector2i(28, 2)), edge)
	if (mask & WEST) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(18, 18), Vector2i(2, 28)), edge)
	if (mask & EAST) == 0:
		image.fill_rect(Rect2i(origin + Vector2i(44, 18), Vector2i(2, 28)), edge)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < columns and cell.y < rows
