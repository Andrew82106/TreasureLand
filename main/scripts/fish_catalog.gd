class_name FishCatalog
extends RefCounted

const AREAS := {
	"sand_shallows": {
		"name": "白沙浅湾",
		"description": "距离短、能见度高、洋流弱，适合稳定取得日常食用鱼。",
		"visibility": 1.0,
		"current": "弱",
		"unlock": "开局开放"
	},
	"coral_shelf": {
		"name": "珊瑚礁棚",
		"description": "礁石和海草形成岔路，藏礁鱼与精品食用鱼更常见。",
		"visibility": 0.78,
		"current": "中",
		"unlock": "完成首次潜捕后开放"
	},
	"wreck_edge": {
		"name": "沉船外缘",
		"description": "距离远、局部暗流明显，夜行与稀有鱼可能在残骸附近活动。",
		"visibility": 0.52,
		"current": "强",
		"unlock": "海生图鉴记录5种后开放"
	}
}

const SPECIES := {
	"bubble_sardine": {
		"name": "泡尾沙丁", "rarity": "普通", "habitats": ["sand_shallows"],
		"periods": ["清晨", "白天", "傍晚"], "weather": ["晴", "阵雨"],
		"behavior": "群游", "base_value": 8, "tags": ["日常食用", "加工"], "shelf_life": 2,
		"color": Color("7fc7d2")
	},
	"silverfin": {
		"name": "银鳍鱼", "rarity": "普通", "habitats": ["sand_shallows", "coral_shelf"],
		"periods": ["清晨", "白天"], "weather": ["晴"],
		"behavior": "群游", "base_value": 14, "tags": ["日常食用", "餐厅"], "shelf_life": 2,
		"color": Color("b8dce0")
	},
	"blue_reef_bream": {
		"name": "青纹礁鲷", "rarity": "普通", "habitats": ["coral_shelf"],
		"periods": ["清晨", "白天", "傍晚"], "weather": ["晴", "阵雨"],
		"behavior": "藏礁", "base_value": 16, "tags": ["日常食用"], "shelf_life": 2,
		"color": Color("59aeb0")
	},
	"coconut_needle": {
		"name": "椰影针鱼", "rarity": "普通", "habitats": ["sand_shallows"],
		"periods": ["白天", "傍晚"], "weather": ["晴", "强风"],
		"behavior": "疾游", "base_value": 18, "tags": ["日常食用", "节庆"], "shelf_life": 2,
		"color": Color("7bd0a7")
	},
	"red_spot_grouper": {
		"name": "赤斑石鲈", "rarity": "普通", "habitats": ["coral_shelf"],
		"periods": ["白天", "傍晚", "夜晚"], "weather": ["晴", "阵雨"],
		"behavior": "藏礁", "base_value": 22, "tags": ["餐厅"], "shelf_life": 2,
		"color": Color("db8068")
	},
	"rain_flying_fish": {
		"name": "雨幕飞鱼", "rarity": "普通", "habitats": ["sand_shallows"],
		"periods": ["清晨", "白天", "傍晚"], "weather": ["阵雨", "强风"],
		"behavior": "群游", "base_value": 24, "tags": ["餐厅", "节庆"], "shelf_life": 2,
		"color": Color("8da8e0")
	},
	"coral_lantern": {
		"name": "珊瑚灯鱼", "rarity": "少见", "habitats": ["coral_shelf"],
		"periods": ["傍晚", "夜晚"], "weather": ["晴", "阵雨"],
		"behavior": "藏礁", "base_value": 34, "tags": ["观赏", "收藏"], "shelf_life": 2,
		"color": Color("f0b66d")
	},
	"cloud_puffer": {
		"name": "云斑河豚", "rarity": "少见", "habitats": ["coral_shelf"],
		"periods": ["白天", "傍晚"], "weather": ["阵雨"],
		"behavior": "疾游", "base_value": 40, "tags": ["餐厅", "研究"], "shelf_life": 2,
		"color": Color("c4b77d")
	},
	"windtail_barracuda": {
		"name": "风尾梭鱼", "rarity": "少见", "habitats": ["wreck_edge"],
		"periods": ["白天", "傍晚", "夜晚"], "weather": ["强风"],
		"behavior": "疾游", "base_value": 48, "tags": ["餐厅", "节庆"], "shelf_life": 2,
		"color": Color("6da5b8")
	},
	"moon_ray": {
		"name": "月纹鳐", "rarity": "少见", "habitats": ["wreck_edge"],
		"periods": ["傍晚", "夜晚"], "weather": ["晴", "阵雨"],
		"behavior": "藏礁", "base_value": 60, "tags": ["观赏", "收藏"], "shelf_life": 3,
		"color": Color("a49fdb")
	},
	"star_tide": {
		"name": "星潮鱼", "rarity": "稀有", "habitats": ["wreck_edge"],
		"periods": ["夜晚"], "weather": ["晴"],
		"behavior": "疾游", "base_value": 110, "tags": ["收藏", "节庆"], "shelf_life": 3,
		"color": Color("e7d37d")
	},
	"crowned_goldscale": {
		"name": "冠潮金鳞", "rarity": "稀有", "habitats": ["wreck_edge"],
		"periods": ["清晨", "夜晚"], "weather": ["阵雨", "强风"],
		"behavior": "疾游", "base_value": 150, "tags": ["收藏", "名流订单"], "shelf_life": 3,
		"color": Color("f2c451")
	}
}

const SIZE_MULTIPLIERS := {"小型": 0.85, "标准": 1.0, "大型": 1.25, "纪录级": 1.60}
const FRESHNESS_MULTIPLIERS := {"鲜活": 1.0, "尚鲜": 0.65, "加工级": 0.40}
const RARITY_WEIGHTS := {"普通": 1.0, "少见": 0.32, "稀有": 0.075}


static func species_name(species_id: String) -> String:
	return str(SPECIES.get(species_id, {}).get("name", species_id))


static func area_name(area_id: String) -> String:
	return str(AREAS.get(area_id, {}).get("name", area_id))


static func candidate_weight(species_id: String, area_id: String, phase: String, weather_name: String) -> float:
	if not SPECIES.has(species_id):
		return 0.0
	var fish: Dictionary = SPECIES[species_id]
	if not fish["habitats"].has(area_id):
		return 0.0
	var weight := float(RARITY_WEIGHTS.get(str(fish["rarity"]), 1.0))
	if fish["periods"].has(phase):
		weight *= 1.65
	else:
		weight *= 0.42
	if fish["weather"].has(weather_name):
		weight *= 1.45
	if area_id == "wreck_edge" and str(fish["rarity"]) == "普通":
		weight *= 0.72
	return weight


static func size_from_roll(roll: float) -> String:
	if roll < 0.45:
		return "小型"
	if roll < 0.80:
		return "标准"
	if roll < 0.96:
		return "大型"
	return "纪录级"
