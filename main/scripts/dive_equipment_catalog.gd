class_name DiveEquipmentCatalog
extends RefCounted

# 潜捕装备只提高单次选择权与保存能力，不增加每日鱼群窗口。
const SLOT_ORDER := ["oxygen", "fins", "basket", "preservation"]

const SLOTS := {
	"oxygen": {
		"name": "呼吸设备",
		"description": "延长单次下水的可操作时间。",
		"value_key": "oxygen",
		"unit": "秒",
		"tiers": [
			{"name": "芦管气囊", "value": 50.0, "cost": 0, "requirement": ""},
			{"name": "密封浮囊", "value": 62.0, "cost": 80, "requirement": ""},
			{"name": "潮息罐", "value": 78.0, "cost": 320, "requirement": "water_jar"}
		]
	},
	"fins": {
		"name": "脚蹼",
		"description": "提高游动效率，帮助玩家主动选择目标。",
		"value_key": "swim_speed",
		"unit": "倍",
		"tiers": [
			{"name": "浅湾脚蹼", "value": 1.0, "cost": 0, "requirement": ""},
			{"name": "分流脚蹼", "value": 1.15, "cost": 70, "requirement": ""},
			{"name": "逐流长蹼", "value": 1.32, "cost": 300, "requirement": "river"}
		]
	},
	"basket": {
		"name": "鱼篓",
		"description": "增加单次可带回的鱼获数量。",
		"value_key": "basket",
		"unit": "格",
		"tiers": [
			{"name": "四格鱼篓", "value": 4, "cost": 0, "requirement": ""},
			{"name": "加固鱼篓", "value": 5, "cost": 85, "requirement": ""},
			{"name": "芦编大篓", "value": 7, "cost": 380, "requirement": "reedbed"}
		]
	},
	"preservation": {
		"name": "保存箱",
		"description": "延后鱼获的新鲜度衰减，便于等待订单与行情。",
		"value_key": "preservation_days",
		"unit": "日",
		"tiers": [
			{"name": "湿布鱼箱", "value": 0, "cost": 0, "requirement": ""},
			{"name": "隔温鱼箱", "value": 1, "cost": 100, "requirement": ""},
			{"name": "釉封冷箱", "value": 2, "cost": 440, "requirement": "glaze"}
		]
	}
}


static func default_levels() -> Dictionary:
	return {"oxygen": 0, "fins": 0, "basket": 0, "preservation": 0}


static func max_level(slot_id: String) -> int:
	if not SLOTS.has(slot_id):
		return 0
	return maxi(0, SLOTS[slot_id]["tiers"].size() - 1)


static func tier(slot_id: String, level: int) -> Dictionary:
	if not SLOTS.has(slot_id):
		return {}
	var tiers: Array = SLOTS[slot_id]["tiers"]
	return tiers[clampi(level, 0, tiers.size() - 1)].duplicate(true)


static func values_for_levels(levels: Dictionary) -> Dictionary:
	var values := {}
	for slot_id in SLOT_ORDER:
		var slot: Dictionary = SLOTS[slot_id]
		var current: Dictionary = tier(slot_id, int(levels.get(slot_id, 0)))
		values[str(slot["value_key"])] = current.get("value", 0)
	return values


static func infer_levels(values: Dictionary) -> Dictionary:
	var levels := default_levels()
	for slot_id in SLOT_ORDER:
		var slot: Dictionary = SLOTS[slot_id]
		var key := str(slot["value_key"])
		var actual := float(values.get(key, tier(slot_id, 0).get("value", 0)))
		var inferred := 0
		for level in range(max_level(slot_id) + 1):
			if actual >= float(tier(slot_id, level).get("value", 0)) - 0.0001:
				inferred = level
		levels[slot_id] = inferred
	return levels
