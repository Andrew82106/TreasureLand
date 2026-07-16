class_name WorldLayout
extends RefCounted

## Single source of truth for the large ground map, interaction nodes, NPCs,
## fast-travel destinations and collision blockers.  Coordinates are measured
## directly against island_ground_map_v2.png (3442x1254).

const WORLD_SIZE := Vector2(3442, 1254)
const WORLD_RECT := Rect2(Vector2.ZERO, WORLD_SIZE)
const TILE_SIZE := Vector2(1254, 1254)
const TILE_OVERLAP := 160.0
const TILE_ORIGINS := [Vector2(0, 0), Vector2(1094, 0), Vector2(2188, 0)]

const AREA_ORDER := ["漂流湾", "椰影街", "逐风海岸"]
const REGIONS := {
	"漂流湾": {
		"rect": Rect2(0, 0, 1094, 1254),
		"spawn": Vector2(430, 560),
		"subtitle": "采集 · 合成 · 起居",
	},
	"椰影街": {
		"rect": Rect2(1094, 0, 1094, 1254),
		"spawn": Vector2(1744, 690),
		"subtitle": "交易 · 社交 · 牌会",
	},
	"逐风海岸": {
		"rect": Rect2(2188, 0, 1254, 1254),
		"spawn": Vector2(2680, 790),
		"subtitle": "赛事 · 委托",
	},
}

const MARKERS := [
	{"id": "bed", "label": "漂流小屋", "position": Vector2(255, 445), "color": Color("9ecae1"), "area": "漂流湾"},
	{"id": "fish", "label": "海岸潜捕点", "position": Vector2(470, 800), "color": Color("6bd6e8"), "area": "漂流湾"},
	{"id": "basin", "label": "造化盆", "position": Vector2(820, 520), "color": Color("e7c85d"), "area": "漂流湾"},
	{"id": "granny", "label": "榕奶奶", "position": Vector2(940, 535), "color": Color("f3a6b9"), "area": "漂流湾"},
	{"id": "shop", "label": "椰影杂货铺", "position": Vector2(1404, 735), "color": Color("f2b366"), "area": "椰影街"},
	{"id": "shopkeeper", "label": "铺主阿拓", "position": Vector2(1474, 720), "color": Color("e49f5a"), "area": "椰影街"},
	{"id": "fish_market", "label": "蓝鳍鱼铺", "position": Vector2(1585, 742), "color": Color("69c4c9"), "area": "椰影街"},
	{"id": "tower", "label": "万象塔", "position": Vector2(1744, 490), "color": Color("d9eef2"), "area": "椰影街"},
	{"id": "news", "label": "岛报栏", "position": Vector2(2014, 680), "color": Color("f4e1a1"), "area": "椰影街"},
	{"id": "mia", "label": "米娅", "position": Vector2(2090, 710), "color": Color("ffcf70"), "area": "椰影街"},
	{"id": "tea", "label": "命运牌会", "position": Vector2(1914, 1040), "color": Color("b38ee6"), "area": "椰影街"},
	{"id": "old_joe", "label": "老乔", "position": Vector2(1994, 1008), "color": Color("c3a3ed"), "area": "椰影街"},
	{"id": "race", "label": "逐风竞速", "position": Vector2(2488, 555), "color": Color("7ee0a2"), "area": "逐风海岸"},
	{"id": "aqiu", "label": "阿葵", "position": Vector2(2708, 735), "color": Color("93e0ba"), "area": "逐风海岸"},
	{"id": "milo", "label": "米洛", "position": Vector2(3158, 900), "color": Color("95b9ff"), "area": "逐风海岸"},
]

const CORE_NPC_IDS := ["granny", "shopkeeper", "mia", "old_joe", "aqiu", "milo"]

const NPC_VISUALS := [
	{"id": "granny", "position": Vector2(918, 555), "atlas": "res://assets/art/characters/rong_granny/world/rong_granny_world_atlas_v1.png", "facing": 0},
	{"id": "shopkeeper", "position": Vector2(1455, 742), "atlas": "res://assets/art/characters/a_tuo/world/a_tuo_world_atlas_v1.png", "facing": 0},
	{"id": "mia", "position": Vector2(2070, 735), "atlas": "res://assets/art/characters/mia/world/mia_world_atlas_v1.png", "facing": 1},
	{"id": "old_joe", "position": Vector2(1974, 1032), "atlas": "res://assets/art/characters/old_qiao/world/old_qiao_world_atlas_v1.png", "facing": 0},
	{"id": "aqiu", "position": Vector2(2685, 760), "atlas": "res://assets/art/characters/aqiu/world/aqiu_world_atlas_v1.png", "facing": 2},
	{"id": "milo", "position": Vector2(3135, 922), "atlas": "res://assets/art/characters/milo/world/milo_world_atlas_v1.png", "facing": 1},
	{"id": "luosha", "position": Vector2(1848, 1035), "atlas": "res://assets/art/characters/luosha/world/luosha_world_atlas_v1.png", "facing": 2},
]

# Conservative blockers cover the major painted structures and deep water.  The
# paths and landmark entrances remain open and match the marker coordinates.
const BLOCKERS := [
	Rect2(0, 0, 82, 1254),
	Rect2(0, 885, 690, 369),
	Rect2(105, 190, 285, 225),
	Rect2(650, 255, 330, 205),
	Rect2(1160, 360, 390, 330),
	Rect2(1588, 30, 315, 365),
	Rect2(2060, 115, 270, 255),
	Rect2(1900, 470, 235, 170),
	Rect2(1400, 825, 620, 195),
	Rect2(2240, 180, 410, 330),
	Rect2(2700, 155, 285, 230),
	Rect2(3010, 135, 360, 240),
	Rect2(2980, 650, 330, 245),
	Rect2(3335, 0, 107, 1254),
	Rect2(2820, 1130, 622, 124),
]

const LANTERNS := [
	Vector2(270, 390),
	Vector2(790, 410),
	Vector2(1430, 650),
	Vector2(1744, 410),
	Vector2(2010, 640),
	Vector2(1914, 980),
	Vector2(2470, 490),
	Vector2(2800, 350),
	Vector2(3160, 840),
]

const MAP_LABEL_OFFSETS := {
	"basin": Vector2(-42, -7),
	"granny": Vector2(6, 12),
	"shop": Vector2(-50, 12),
	"shopkeeper": Vector2(6, -7),
	"fish_market": Vector2(-42, 14),
	"news": Vector2(-40, -7),
	"mia": Vector2(6, 12),
	"tea": Vector2(-48, 12),
	"old_joe": Vector2(6, -7),
}


static func area_for_position(position_value: Vector2) -> String:
	if position_value.x >= 2188.0:
		return "逐风海岸"
	if position_value.x >= 1094.0:
		return "椰影街"
	return "漂流湾"


static func spawn_for_area(area_name: String) -> Vector2:
	if not REGIONS.has(area_name):
		return REGIONS["漂流湾"]["spawn"]
	return REGIONS[area_name]["spawn"]


static func marker_definition(marker_id: String) -> Dictionary:
	for definition in MARKERS:
		if str(definition["id"]) == marker_id:
			return definition
	return {}
