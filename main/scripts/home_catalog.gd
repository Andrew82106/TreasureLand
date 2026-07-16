class_name HomeCatalog
extends RefCounted

const LEVELS := [
	{
		"level": 0,
		"name": "漂流小屋",
		"description": "一张能挡潮风的床和一个临时陈列角。",
		"cost": 0,
		"wealth_required": 0,
		"discoveries_required": 3,
		"display_slots": 1,
		"aquarium_slots": 0,
		"guest_slots": 0,
	},
	{
		"level": 1,
		"name": "潮木居所",
		"description": "修好墙板与屋顶，添置一只小水族箱。",
		"cost": 400,
		"wealth_required": 500,
		"discoveries_required": 10,
		"display_slots": 3,
		"aquarium_slots": 1,
		"guest_slots": 0,
	},
	{
		"level": 2,
		"name": "风灯庭院",
		"description": "有了可以待客的庭院、六处陈列和三格水族空间。",
		"cost": 2500,
		"wealth_required": 3000,
		"discoveries_required": 30,
		"display_slots": 6,
		"aquarium_slots": 3,
		"guest_slots": 1,
	},
	{
		"level": 3,
		"name": "四象宅邸",
		"description": "塔影与潮灯环绕的长期居所，容纳完整的个人收藏。",
		"cost": 12000,
		"wealth_required": 20000,
		"discoveries_required": 55,
		"display_slots": 10,
		"aquarium_slots": 6,
		"guest_slots": 1,
	},
]

const GUEST_COST := 30
const GUEST_TIME_COST := 0.5
const FINALE_TIME_COST := 1.0


static func level_data(level: int) -> Dictionary:
	return LEVELS[clampi(level, 0, LEVELS.size() - 1)].duplicate(true)


static func max_level() -> int:
	return LEVELS.size() - 1
