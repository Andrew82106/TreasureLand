extends RefCounted
class_name GameState

signal changed
signal notice(text: String)

const ITEMS := {
	"water": {"name": "水", "tier": 0, "category": "自然", "description": "岛上最常见的流动，也是一切变化的起点。"},
	"earth": {"name": "土", "tier": 0, "category": "自然", "description": "能够承接形状、种子与重量的基础万物。"},
	"fire": {"name": "火", "tier": 0, "category": "自然", "description": "让万物改变形态并留下新性质的热。"},
	"wood": {"name": "木", "tier": 0, "category": "自然", "description": "有纹理、韧性和生长痕迹的岛木。"},
	"wind": {"name": "风", "tier": 0, "category": "自然", "description": "看不见，却会在海面、风帆和铃声中留下方向。"},
	"stone": {"name": "石", "tier": 0, "category": "自然", "description": "稳定、沉默，记录着岛屿长久的形状。"},
	"fish": {"name": "鱼", "tier": 0, "category": "生灵", "description": "随潮水靠近浅滩的海中生灵。"},
	"fruit": {"name": "果实", "tier": 0, "category": "生灵", "description": "植物把阳光和季节保存下来的甜味。"},
	"salt": {"name": "盐", "tier": 0, "category": "生活", "description": "海水退去后留下的晶体，能够改变保存方式。"},
	"metal": {"name": "金", "tier": 0, "category": "工艺", "description": "可被锻打、传声并形成精密边缘的金属。"},
	"cloth": {"name": "布", "tier": 0, "category": "生活", "description": "由纤维交织而成，柔软却能承接风力。"},
	"paper": {"name": "纸", "tier": 0, "category": "生活", "description": "可以保存符号、地图与人物记忆的薄片。"},
	"flower": {"name": "花", "tier": 0, "category": "生灵", "description": "短暂盛开，却能留下气味和颜色。"},
	"mud": {"name": "泥", "tier": 1, "category": "工艺", "description": "水与土安静结合后的第一种稳定造物。"},
	"charcoal": {"name": "炭", "tier": 1, "category": "工艺", "description": "木在火中留下的凝练热量。"},
	"fog": {"name": "雾", "tier": 1, "category": "自然", "description": "被风托住、暂时不肯落下的水。"},
	"pottery": {"name": "陶器", "tier": 2, "category": "生活", "description": "泥经历火之后获得了可以长久保存的形状。"},
	"tool": {"name": "工具", "tier": 2, "category": "工艺", "description": "木提供握持，金提供改变与测量世界的锋面。"},
	"sail": {"name": "风帆", "tier": 2, "category": "工艺", "description": "布接住风，第一次把方向变成力量。"},
	"salted_fish": {"name": "咸鱼", "tier": 2, "category": "生活", "description": "海获与盐共同形成的保存方法。"},
	"calm_incense": {"name": "静心香", "tier": 3, "category": "灵感", "description": "炭托起花香，让纷乱慢慢沉静。"},
	"wind_bell": {"name": "观风铃", "tier": 3, "category": "灵感", "description": "金属替无形的风留下了可以比较的声音。"}
}

const RECIPES := [
	{"inputs": ["water", "earth"], "output": "mud"},
	{"inputs": ["fire", "wood"], "output": "charcoal"},
	{"inputs": ["wind", "water"], "output": "fog"},
	{"inputs": ["mud", "fire"], "output": "pottery"},
	{"inputs": ["wood", "metal"], "output": "tool"},
	{"inputs": ["cloth", "wind"], "output": "sail"},
	{"inputs": ["fish", "salt"], "output": "salted_fish"},
	{"inputs": ["charcoal", "flower"], "output": "calm_incense"},
	{"inputs": ["metal", "wind"], "output": "wind_bell"}
]

const INITIAL_DISCOVERIES := ["water", "earth", "fire", "wind", "wood", "stone"]
const SYNTHESIS_COST_BY_TIER := [2, 5, 12, 30]
const SHOP_OFFERS := [
	{"id": "metal_knowledge", "name": "金工拓片", "type": "knowledge", "price": 35, "art": "metal", "unlock": "metal", "description": "永久发现“金”，开启工具与观风铃的研究关系。"},
	{"id": "cloth_knowledge", "name": "织造样本", "type": "knowledge", "price": 30, "art": "cloth", "unlock": "cloth", "description": "永久发现“布”，开启风帆的研究关系。"},
	{"id": "paper_knowledge", "name": "抄纸手记", "type": "knowledge", "price": 25, "art": "paper", "unlock": "paper", "description": "永久发现“纸”，为地图与记录类造物打开入口。"},
	{"id": "recipe_hint", "name": "配方方向线索", "type": "hint", "price": 12, "art": "paper", "description": "指出一个已知万物可能回应的类别，不公开结果。"},
	{"id": "experiment_discount", "name": "三次实验折扣", "type": "discount", "price": 24, "art": "charcoal", "uses": 3, "cap": 6, "description": "接下来三次新组合实验费减半，向上取整。"}
]
const RACE_AIDS := {
	"tool": {"name": "分段量具", "fee": 4, "description": "测出所选逐风兽四阶段基础表现与场内排名。"},
	"sail": {"name": "风帆读势", "fee": 5, "description": "分析所选逐风兽在当前天气中的修正与适应排名。"},
	"calm_incense": {"name": "静心观测", "fee": 6, "description": "显示所选逐风兽的波动等级、标准差与稳定排名。"},
	"wind_bell": {"name": "全场观风", "fee": 8, "description": "指出当前天气中受益最高的三匹逐风兽。"}
}

const RACE_BEASTS := [
	{"id": "cloudfin", "name": "云鳍", "speed": 78, "stamina": 62, "burst": 74, "stability": 70, "course": 82, "rider": 68, "form": 5},
	{"id": "coralhorn", "name": "珊瑚角", "speed": 68, "stamina": 82, "burst": 58, "stability": 78, "course": 76, "rider": 73, "form": 0},
	{"id": "whitewave", "name": "白浪", "speed": 84, "stamina": 58, "burst": 88, "stability": 48, "course": 66, "rider": 64, "form": 5},
	{"id": "sunmane", "name": "日鬃", "speed": 73, "stamina": 70, "burst": 72, "stability": 76, "course": 69, "rider": 80, "form": 0},
	{"id": "miststep", "name": "雾步", "speed": 69, "stamina": 65, "burst": 80, "stability": 55, "course": 88, "rider": 67, "form": 10},
	{"id": "tidebell", "name": "潮铃", "speed": 72, "stamina": 77, "burst": 65, "stability": 84, "course": 71, "rider": 75, "form": 0},
	{"id": "starwake", "name": "星迹", "speed": 81, "stamina": 67, "burst": 79, "stability": 61, "course": 73, "rider": 77, "form": -8},
	{"id": "sandpearl", "name": "沙珠", "speed": 64, "stamina": 74, "burst": 67, "stability": 88, "course": 79, "rider": 70, "form": 5}
]

# 由当前八兽四段计分公式各模拟100,000场得到。赔率按实际命中率而不是属性均值计算。
const RACE_WIN_PROBABILITIES := {
	"晴": [0.13909, 0.06246, 0.06112, 0.13628, 0.17875, 0.15081, 0.06979, 0.20170],
	"阵雨": [0.18048, 0.05534, 0.03136, 0.07638, 0.28510, 0.09608, 0.05113, 0.22413],
	"强风": [0.08862, 0.06475, 0.00933, 0.12539, 0.05286, 0.23657, 0.02237, 0.40011]
}
const RACE_TOP3_PROBABILITIES := {
	"晴": [0.40554, 0.25960, 0.18621, 0.42289, 0.42265, 0.48818, 0.22878, 0.58615],
	"阵雨": [0.49766, 0.25863, 0.11781, 0.31227, 0.57903, 0.39434, 0.19728, 0.64298],
	"强风": [0.34825, 0.31801, 0.04871, 0.46015, 0.20703, 0.67641, 0.11857, 0.82287]
}
const RACE_TARGET_RETURN := 0.88

const DAILY_FISHING_LIMIT := 3
const POKER_TIERS := [
	{"name": "潮边小桌", "buy_in": 80, "wealth_required": 0, "small_blind": 1, "big_blind": 2, "description": "认识规则与人物，输赢幅度较小"},
	{"name": "椰影常桌", "buy_in": 200, "wealth_required": 500, "small_blind": 2, "big_blind": 4, "description": "学徒开放，开始形成可感知的财富波动"},
	{"name": "风灯高桌", "buy_in": 500, "wealth_required": 3000, "small_blind": 5, "big_blind": 10, "description": "小赢家开放，对手资金与行动压力同步提高"},
	{"name": "塔影名流桌", "buy_in": 2000, "wealth_required": 20000, "small_blind": 20, "big_blind": 40, "description": "富商开放，用于中期的大额财富跃升"}
]

const ORACLE_WATER_NAMES := ["水滴", "雨幕", "溪流", "湖泊", "江河", "海洋"]
const ORACLE_FIRE_NAMES := ["火星", "烛火", "炉火", "篝火", "烈焰", "天火"]
const ORACLE_PATTERN_NAMES := ["微兆", "回响", "双回响", "升势", "双镜", "三叠", "既济", "轮转", "归一"]
const ORACLE_PATTERN_RULES := [
	"未形成其他关系，比较总势阶",
	"两张类别与势阶都相同的牌",
	"两组完全相同的牌",
	"四个不同势阶连续，水火不限",
	"两个不同势阶中，每阶各有一水一火",
	"三张类别与势阶都相同的牌",
	"四阶各异、两水两火，且水势总和等于火势总和",
	"四个势阶连续，并按势阶水火严格交替",
	"四张类别与势阶都完全相同的牌"
]
const ORACLE_OPPONENTS := [
	{"name": "老乔", "style": "礁石型", "color": "b99ad9"},
	{"name": "阿拓", "style": "潮汐型", "color": "e7a55e"},
	{"name": "米娅", "style": "海雾型", "color": "f4cf73"},
	{"name": "榕奶奶", "style": "礁石型", "color": "eaa6ba"},
	{"name": "旅人洛沙", "style": "海雾型", "color": "79b9c8"}
]

var cash: int = 120
var locked_principal: int = 0
var day: int = 1
var tide: int = 1
var weather: String = "晴"
var discovered := {
	"water": true, "earth": true, "fire": true,
	"wind": true, "wood": true, "stone": true
}
var attempted_pairs := {}
var recent_synthesis_pairs: Array[String] = []
var synthesis_discount_uses: int = 0
var last_shop_hint: String = ""
var last_shop_hint_key: String = ""
var relationships := {"granny": 10, "old_joe": 0, "aqiu": 0, "mia": 0, "milo": 0, "shopkeeper": 0}
var memories := {}
var free_race_ticket: int = 1
var fishing_attempts_today: int = 0
var poker_completed: bool = false
var aqiu_request_active: bool = false
var aqiu_request_done: bool = false
var ultimate_created: bool = false
var poker := {}
var poker_session_active: bool = false
var poker_session_id: String = ""
var poker_session_hands: int = 0
var poker_session_buy_in: int = 80
var poker_dealer_index: int = -1
var poker_dealer_seat: int = -1
var poker_session_end_reason: String = ""
var poker_player_brought: int = 0
var poker_session_tutorial: bool = false
var poker_tutorial_balance: int = 0
var poker_tutorial_settled: bool = false
var poker_session_time_charged: bool = false
var poker_session_seed: int = 0
var poker_test_passive_ai: bool = false
var poker_npc_wallets: Array = []
var poker_npc_brought: Array = []
var poker_npc_present: Array = []
var recent_oracle_records: Array = []
var wealth_history: Array = []
var recording_enabled: bool = true
var oracle_record_relative_path: String = "user://play_records/oracle_table.jsonl"
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 20260713
	_load_recent_oracle_records()
	_record_wealth("来到万物之岛", true)


func item_name(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return item_id
	return str(ITEMS[item_id]["name"])


func account_wealth() -> int:
	return cash + locked_principal


func asset_liquidation_value() -> int:
	return 0


func net_worth() -> int:
	return account_wealth()


func wealth_history_for_chart() -> Array:
	var result: Array = wealth_history.duplicate(true)
	var current := _wealth_snapshot("当前")
	if result.is_empty() or not _same_wealth_snapshot(result[result.size() - 1], current):
		result.append(current)
	return result


func next_wealth_milestone() -> Dictionary:
	var current := account_wealth()
	var previous := 0
	var milestones := [
		{"title": "学徒", "target": 500},
		{"title": "小赢家", "target": 3000},
		{"title": "富商", "target": 20000},
		{"title": "大亨", "target": 150000},
		{"title": "岛之名流", "target": 1000000}
	]
	for raw_milestone in milestones:
		var milestone: Dictionary = raw_milestone
		var target := int(milestone["target"])
		if current < target:
			return {
				"complete": false,
				"title": str(milestone["title"]),
				"target": target,
				"remaining": target - current,
				"progress": clampf(float(current - previous) / maxf(1.0, float(target - previous)), 0.0, 1.0)
			}
		previous = target
	return {"complete": true, "title": "岛之名流", "target": 1000000, "remaining": 0, "progress": 1.0}


func _record_wealth(reason: String, force: bool = false) -> void:
	var point := _wealth_snapshot(reason)
	if not force and not wealth_history.is_empty() and _same_wealth_snapshot(wealth_history[wealth_history.size() - 1], point):
		return
	wealth_history.append(point)
	if wealth_history.size() > 200:
		wealth_history.pop_front()


func _wealth_snapshot(reason: String) -> Dictionary:
	return {
		"day": day,
		"tide": tide,
		"cash": cash,
		"locked": locked_principal,
		"assets": asset_liquidation_value(),
		"account_wealth": account_wealth(),
		"net_worth": net_worth(),
		"reason": reason
	}


func _same_wealth_snapshot(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("day", 0)) == int(b.get("day", 0)) \
		and int(a.get("tide", 0)) == int(b.get("tide", 0)) \
		and int(a.get("cash", 0)) == int(b.get("cash", 0)) \
		and int(a.get("locked", 0)) == int(b.get("locked", 0)) \
		and int(a.get("assets", 0)) == int(b.get("assets", 0))


func wealth_title() -> String:
	if ultimate_created:
		return "万象之主"
	var wealth := account_wealth()
	if wealth >= 1000000:
		return "岛之名流"
	if wealth >= 150000:
		return "大亨"
	if wealth >= 20000:
		return "富商"
	if wealth >= 3000:
		return "小赢家"
	if wealth >= 500:
		return "学徒"
	return "漂流者"


func suggested_reserve() -> int:
	var wealth := account_wealth()
	if wealth >= 150000:
		return maxi(5000, int(round(wealth * 0.05)))
	if wealth >= 20000:
		return 5000
	if wealth >= 3000:
		return 1000
	return 200


func fishing_remaining_today() -> int:
	return maxi(0, DAILY_FISHING_LIMIT - fishing_attempts_today)


func poker_tiers() -> Array:
	return POKER_TIERS.duplicate(true)


func poker_tier_for_buy_in(buy_in: int) -> Dictionary:
	for raw_tier in POKER_TIERS:
		var tier: Dictionary = raw_tier
		if int(tier["buy_in"]) == buy_in:
			return tier
	return POKER_TIERS[0]


func can_enter_poker_tier(buy_in: int) -> bool:
	var tier := poker_tier_for_buy_in(buy_in)
	if poker_session_active and poker_session_tutorial:
		return poker_player_available() >= buy_in and account_wealth() >= int(tier["wealth_required"])
	if not poker_completed and buy_in == 80:
		return account_wealth() >= int(tier["wealth_required"])
	return cash >= buy_in and account_wealth() >= int(tier["wealth_required"])


func phase_name() -> String:
	if tide <= 4:
		return "清晨"
	if tide <= 8:
		return "白天"
	if tide <= 12:
		return "傍晚"
	return "夜晚"


func advance_time(amount: int) -> void:
	tide += amount
	while tide > 16:
		tide -= 16
		day += 1
		refresh_day()
	changed.emit()


func sleep_to_next_day() -> void:
	day += 1
	tide = 1
	refresh_day()
	_record_wealth("第%d天开始" % day, true)
	changed.emit()
	_notice("新的一天开始了。商店、天气和赛事已经刷新。")


func refresh_day() -> void:
	fishing_attempts_today = 0
	var weathers := ["晴", "阵雨", "强风"]
	weather = weathers[rng.randi_range(0, weathers.size() - 1)]
	changed.emit()


func is_discovered(item_id: String) -> bool:
	return bool(discovered.get(item_id, false))


func discover_item(item_id: String, _source: String = "world") -> bool:
	if not ITEMS.has(item_id) or is_discovered(item_id):
		return false
	discovered[item_id] = true
	changed.emit()
	return true


func discovered_item_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in discovered.keys():
		var item_id := str(raw_id)
		if is_discovered(item_id) and ITEMS.has(item_id):
			result.append(item_id)
	result.sort_custom(func(a: String, b: String):
		var tier_a := int(ITEMS[a].get("tier", 0))
		var tier_b := int(ITEMS[b].get("tier", 0))
		if tier_a != tier_b:
			return tier_a < tier_b
		return item_name(a) < item_name(b)
	)
	return result


func item_description(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return ""
	return str(ITEMS[item_id].get("description", ""))


func synthesis_pair_key(left_id: String, right_id: String) -> String:
	var ids := [left_id, right_id]
	ids.sort()
	return "%s|%s" % [ids[0], ids[1]]


func synthesis_attempt_record(left_id: String, right_id: String) -> Dictionary:
	return attempted_pairs.get(synthesis_pair_key(left_id, right_id), {})


func synthesis_base_cost(left_id: String, right_id: String) -> int:
	if not ITEMS.has(left_id) or not ITEMS.has(right_id):
		return 0
	var tier := maxi(int(ITEMS[left_id].get("tier", 0)), int(ITEMS[right_id].get("tier", 0)))
	return int(SYNTHESIS_COST_BY_TIER[clampi(tier, 0, SYNTHESIS_COST_BY_TIER.size() - 1)])


func synthesis_cost(left_id: String, right_id: String) -> int:
	if left_id.is_empty() or right_id.is_empty():
		return 0
	if not synthesis_attempt_record(left_id, right_id).is_empty():
		return 0
	var base := synthesis_base_cost(left_id, right_id)
	return int(ceil(float(base) * 0.5)) if synthesis_discount_uses > 0 else base


func synthesize(queue: Array[String]) -> Dictionary:
	if queue.size() != 2:
		return {"ok": false, "success": false, "text": "造化盆需要左、右各选择一个万物。"}
	return synthesize_pair(str(queue[0]), str(queue[1]))


func synthesize_pair(left_id: String, right_id: String) -> Dictionary:
	if not is_discovered(left_id) or not is_discovered(right_id):
		return {"ok": false, "success": false, "text": "只能使用已经发现的万物。"}
	var pair_key := synthesis_pair_key(left_id, right_id)
	var prior: Dictionary = attempted_pairs.get(pair_key, {})
	if not prior.is_empty():
		var repeated := prior.duplicate(true)
		repeated["ok"] = true
		repeated["repeat"] = true
		repeated["first_discovery"] = false
		repeated["cost_paid"] = 0
		repeated["text"] = "这个组合已经记录，不再收取实验费。"
		return repeated

	var cost := synthesis_cost(left_id, right_id)
	if cash < cost:
		return {
			"ok": false,
			"success": false,
			"required": cost,
			"text": "本次实验需要%d金贝，当前只有%d金贝。" % [cost, cash]
		}

	var used_discount := synthesis_discount_uses > 0
	cash -= cost
	if used_discount:
		synthesis_discount_uses -= 1
	var matched := _find_pair_recipe(left_id, right_id)
	var record := {
		"pair_key": pair_key,
		"left_id": left_id,
		"right_id": right_id,
		"success": not matched.is_empty(),
		"result_id": str(matched.get("output", "")),
		"output": str(matched.get("output", "")),
		"cost_paid": cost,
		"used_discount": used_discount,
		"day": day,
		"tide": tide,
		"repeat": false
	}
	if matched.is_empty():
		var feedback := synthesis_failure_feedback([left_id, right_id])
		record["failure_title"] = str(feedback["title"])
		record["failure_reason"] = str(feedback["reason"])
		record["suggestion"] = str(feedback["suggestion"])
	else:
		var output_id := str(matched["output"])
		record["first_discovery"] = discover_item(output_id, "synthesis")
		record["category"] = str(ITEMS[output_id]["category"])
		record["tier"] = int(ITEMS[output_id]["tier"])
		record["collection_count"] = discovered_recipe_count()
		record["collection_total"] = RECIPES.size()
		record["new_opportunities"] = count_untried_visible_pairs()
	attempted_pairs[pair_key] = record.duplicate(true)
	recent_synthesis_pairs.erase(pair_key)
	recent_synthesis_pairs.push_front(pair_key)
	while recent_synthesis_pairs.size() > 8:
		recent_synthesis_pairs.pop_back()
	_record_wealth("万物实验 · %s + %s" % [item_name(left_id), item_name(right_id)])
	changed.emit()
	var result := record.duplicate(true)
	result["ok"] = true
	if bool(record["success"]):
		result["text"] = "发现%s。万物永久保留，本次支付%d金贝。" % [item_name(str(record["output"])), cost]
	else:
		result["text"] = "%s 本次支付%d金贝，双方万物永久保留。" % [str(record["failure_title"]), cost]
	return result


func discovered_recipe_count() -> int:
	var count := 0
	for recipe in RECIPES:
		if discovered.has(str(recipe["output"])):
			count += 1
	return count


func synthesis_failure_feedback(queue: Array[String]) -> Dictionary:
	if queue.size() != 2:
		return {"title": "选择未完成。", "reason": "造化盆只接受左右两个万物。", "suggestion": "从左右图鉴各选择一个万物。"}
	var left_id := str(queue[0])
	var right_id := str(queue[1])
	if left_id == right_id:
		return {
			"title": "同源静默。",
			"reason": "两个相同万物彼此映照，却没有形成新的稳定关系。",
			"suggestion": "保留这个万物，换另一侧为不同类别再试。"
		}
	var left_category := str(ITEMS.get(left_id, {}).get("category", ""))
	var right_category := str(ITEMS.get(right_id, {}).get("category", ""))
	if left_category == right_category:
		return {
			"title": "性质重叠。",
			"reason": "两者的性质过于接近，没有产生足以稳定的新变化。",
			"suggestion": "保留其中一个，尝试来自另一类别的万物。"
		}
	return {
		"title": "尚无稳定关系。",
		"reason": "两者发生了短暂变化，但没有留下可以命名的新万物。",
		"suggestion": "这组关系已经记录；从任意一侧换入另一个已发现万物。"
	}


func _find_pair_recipe(left_id: String, right_id: String) -> Dictionary:
	var target_key := synthesis_pair_key(left_id, right_id)
	for raw_recipe in RECIPES:
		var recipe: Dictionary = raw_recipe
		var inputs: Array = recipe["inputs"]
		if inputs.size() == 2 and synthesis_pair_key(str(inputs[0]), str(inputs[1])) == target_key:
			return recipe
	return {}


func count_untried_visible_pairs() -> int:
	var ids := discovered_item_ids()
	var count := 0
	for left_index in range(ids.size()):
		for right_index in range(left_index, ids.size()):
			if synthesis_attempt_record(ids[left_index], ids[right_index]).is_empty():
				count += 1
	return count


func get_recipe_for_output(output_id: String) -> Dictionary:
	for recipe in RECIPES:
		if str(recipe["output"]) == output_id:
			return recipe
	return {}


func shop_offers() -> Array:
	var result: Array = []
	for raw_offer in SHOP_OFFERS:
		var offer: Dictionary = raw_offer.duplicate(true)
		var offer_type := str(offer["type"])
		var available := true
		var state_text := "可购买"
		if offer_type == "knowledge" and is_discovered(str(offer["unlock"])):
			available = false
			state_text = "已经掌握"
		elif offer_type == "discount" and synthesis_discount_uses + int(offer["uses"]) > int(offer["cap"]):
			available = false
			state_text = "需要留出%d次凭证空间" % int(offer["uses"])
		elif offer_type == "hint" and _next_synthesis_hint().is_empty():
			available = false
			state_text = "暂无新线索"
		offer["available"] = available
		offer["state_text"] = state_text
		result.append(offer)
	return result


func shop_offer(offer_id: String) -> Dictionary:
	for raw_offer in SHOP_OFFERS:
		var offer: Dictionary = raw_offer
		if str(offer["id"]) == offer_id:
			return offer
	return {}


func buy_shop_offer(offer_id: String) -> Dictionary:
	var offer := shop_offer(offer_id)
	if offer.is_empty():
		return {"ok": false, "text": "这项服务不存在。"}
	var offer_type := str(offer["type"])
	var delivery := ""
	var delivery_key := ""
	if offer_type == "knowledge":
		var unlock_id := str(offer["unlock"])
		if is_discovered(unlock_id):
			return {"ok": false, "text": "你已经掌握%s。" % item_name(unlock_id)}
		delivery = "永久发现%s" % item_name(unlock_id)
	elif offer_type == "discount":
		if synthesis_discount_uses + int(offer["uses"]) > int(offer["cap"]):
			return {"ok": false, "text": "这项服务一次交付%d次折扣，账户最多储存%d次。" % [int(offer["uses"]), int(offer["cap"])]}
		delivery = "增加%d次实验折扣" % int(offer["uses"])
	elif offer_type == "hint":
		var hint_record := _next_synthesis_hint_record()
		delivery = str(hint_record.get("text", ""))
		delivery_key = str(hint_record.get("pair_key", ""))
		if delivery.is_empty():
			return {"ok": false, "text": "目前没有可以交付的新线索。"}
	else:
		return {"ok": false, "text": "这项服务尚未开放。"}

	var price := int(offer["price"])
	if cash < price:
		return {"ok": false, "text": "购买%s需要%d金贝。" % [str(offer["name"]), price]}
	cash -= price
	if offer_type == "knowledge":
		discover_item(str(offer["unlock"]), "shop")
	elif offer_type == "discount":
		synthesis_discount_uses += int(offer["uses"])
	elif offer_type == "hint":
		last_shop_hint = delivery
		last_shop_hint_key = delivery_key
	_record_wealth("商店服务 · %s" % str(offer["name"]))
	changed.emit()
	return {
		"ok": true,
		"offer_id": offer_id,
		"price": price,
		"delivery": delivery,
		"text": "%s，支付%d金贝。%s。" % [str(offer["name"]), price, delivery]
	}


func _next_synthesis_hint() -> String:
	return str(_next_synthesis_hint_record().get("text", ""))


func _next_synthesis_hint_record() -> Dictionary:
	for raw_recipe in RECIPES:
		var recipe: Dictionary = raw_recipe
		var output_id := str(recipe["output"])
		if is_discovered(output_id):
			continue
		var inputs: Array = recipe["inputs"]
		var left_id := str(inputs[0])
		var right_id := str(inputs[1])
		var pair_key := synthesis_pair_key(left_id, right_id)
		if pair_key == last_shop_hint_key or not synthesis_attempt_record(left_id, right_id).is_empty():
			continue
		if is_discovered(left_id):
			return {
				"pair_key": pair_key,
				"text": "阿拓的线索：%s似乎会回应一种%s类万物" % [item_name(left_id), str(ITEMS[right_id]["category"])]
			}
		if is_discovered(right_id):
			return {
				"pair_key": pair_key,
				"text": "阿拓的线索：%s似乎会回应一种%s类万物" % [item_name(right_id), str(ITEMS[left_id]["category"])]
			}
	return {}


func fish_once() -> Dictionary:
	if fishing_attempts_today >= DAILY_FISHING_LIMIT:
		return {
			"ok": false,
			"remaining": 0,
			"text": "今天这片浅滩已经被翻找干净。潮水明早会带来新的鱼获与漂流物。"
		}
	fishing_attempts_today += 1
	var catches := ["fish", "salt", "water", "flower", "fruit"]
	var item_id := str(catches[rng.randi_range(0, catches.size() - 1)])
	var coins := rng.randi_range(40, 80)
	var first_discovery := discover_item(item_id, "shore")
	cash += coins
	advance_time(1)
	_record_wealth("浅滩采集")
	var observation := "首次观察%s，永久加入万物图鉴" % item_name(item_id) if first_discovery else "再次观察到%s" % item_name(item_id)
	return {
		"ok": true,
		"item": item_id,
		"first_discovery": first_discovery,
		"coins": coins,
		"remaining": fishing_remaining_today(),
		"text": "%s，并赚到%d金贝。今日浅滩还可观察%d次。" % [observation, coins, fishing_remaining_today()]
	}


func activate_aqiu_request() -> void:
	if aqiu_request_done:
		return
	aqiu_request_active = true
	changed.emit()


func turn_in_aqiu_request() -> Dictionary:
	if aqiu_request_done:
		return {"ok": false, "text": "阿葵已经记下你发现的咸鱼保存方法。"}
	if not is_discovered("salted_fish"):
		activate_aqiu_request()
		return {"ok": false, "text": "阿葵想了解一种海获保存方法。试试让鱼和盐在造化盆中相遇。"}
	aqiu_request_done = true
	aqiu_request_active = false
	cash += 80
	_record_wealth("完成阿葵委托")
	relationships["aqiu"] = int(relationships.get("aqiu", 0)) + 8
	add_memory("aqiu", "你把咸鱼的保存方法告诉了阿葵。")
	changed.emit()
	return {"ok": true, "text": "阿葵记下咸鱼的保存方法，支付80金贝，并告诉你云鳍今天状态不错。咸鱼仍永久保留在图鉴中。"}


func add_memory(npc_id: String, text: String) -> void:
	var list: Array = memories.get(npc_id, [])
	list.push_front(text)
	while list.size() > 5:
		list.pop_back()
	memories[npc_id] = list


func relationship_state(npc_id: String) -> String:
	var score := int(relationships.get(npc_id, 0))
	if score < -19:
		return "疏远"
	if score < 10:
		return "陌生"
	if score < 40:
		return "熟悉"
	return "信任"


func race_aids_available() -> Array[String]:
	var result: Array[String] = []
	for raw_id in RACE_AIDS.keys():
		var item_id := str(raw_id)
		if is_discovered(item_id):
			result.append(item_id)
	result.sort_custom(func(a: String, b: String): return int(RACE_AIDS[a]["fee"]) < int(RACE_AIDS[b]["fee"]))
	return result


func race_aid_info(aid_id: String, beast_index: int) -> Dictionary:
	if aid_id.is_empty():
		return {"ok": true, "id": "", "name": "不使用造物", "fee": 0, "description": "使用公开信息完成判断。", "insight": "本场不部署造物。"}
	if not RACE_AIDS.has(aid_id) or not is_discovered(aid_id):
		return {"ok": false, "text": "这个竞速造物尚未发现。"}
	if beast_index < 0 or beast_index >= RACE_BEASTS.size():
		return {"ok": false, "text": "请选择逐风兽。"}
	var aid: Dictionary = RACE_AIDS[aid_id]
	var beast: Dictionary = RACE_BEASTS[beast_index]
	var insight := ""
	match aid_id:
		"tool":
			var bases := _race_stage_bases(beast)
			var stage_names := ["起步", "巡航", "地形", "冲刺"]
			var parts: Array[String] = []
			for stage in range(4):
				var values: Array[float] = []
				for raw_beast in RACE_BEASTS:
					values.append(float(_race_stage_bases(raw_beast)[stage]))
				parts.append("%s %.1f（第%d）" % [stage_names[stage], float(bases[stage]), _descending_rank(float(bases[stage]), values)])
			insight = "%s：%s。" % [str(beast["name"]), " / ".join(parts)]
		"sail":
			var modifier := _race_weather_modifier(beast)
			var modifiers: Array[float] = []
			for raw_beast in RACE_BEASTS:
				modifiers.append(_race_weather_modifier(raw_beast))
			insight = "%s在%s中的阶段修正为%+.2f，天气适应列第%d。" % [str(beast["name"]), weather, modifier, _descending_rank(modifier, modifiers)]
		"calm_incense":
			var sigma := 12.0 - float(beast["stability"]) * 0.08
			var stabilities: Array[float] = []
			for raw_beast in RACE_BEASTS:
				stabilities.append(float(raw_beast["stability"]))
			var level := "低波动" if sigma <= 6.0 else ("中波动" if sigma <= 7.0 else "高波动")
			insight = "%s为%s，阶段标准差 %.2f，稳定性列第%d。" % [str(beast["name"]), level, sigma, _descending_rank(float(beast["stability"]), stabilities)]
		"wind_bell":
			var field: Array = []
			for raw_beast in RACE_BEASTS:
				field.append({"name": str(raw_beast["name"]), "modifier": _race_weather_modifier(raw_beast)})
			field.sort_custom(func(a, b): return float(a["modifier"]) > float(b["modifier"]))
			var leaders: Array[String] = []
			for index in range(3):
				leaders.append("%s %+.2f" % [str(field[index]["name"]), float(field[index]["modifier"])])
			insight = "%s天气受益前三：%s。" % [weather, " / ".join(leaders)]
	return {
		"ok": true,
		"id": aid_id,
		"name": str(aid["name"]),
		"fee": int(aid["fee"]),
		"description": str(aid["description"]),
		"insight": insight
	}


func _race_stage_bases(beast: Dictionary) -> Array[float]:
	var stability := float(beast["stability"])
	return [
		float(beast["burst"]) * 0.45 + stability * 0.30 + float(beast["rider"]) * 0.25,
		float(beast["speed"]) * 0.50 + float(beast["stamina"]) * 0.25 + float(beast["course"]) * 0.15 + float(beast["rider"]) * 0.10,
		float(beast["course"]) * 0.35 + stability * 0.30 + float(beast["stamina"]) * 0.20 + float(beast["rider"]) * 0.15,
		float(beast["burst"]) * 0.40 + float(beast["stamina"]) * 0.35 + float(beast["speed"]) * 0.15 + float(beast["rider"]) * 0.10
	]


func _race_weather_modifier(beast: Dictionary) -> float:
	if weather == "阵雨":
		return (float(beast["course"]) - 70.0) * 0.12
	if weather == "强风":
		return (float(beast["stability"]) - 70.0) * 0.12
	return 0.0


func _descending_rank(value: float, values: Array[float]) -> int:
	var rank := 1
	for other in values:
		if float(other) > value:
			rank += 1
	return rank


func ticket_types() -> Array[String]:
	var result: Array[String] = ["独胜"]
	var wealth := account_wealth()
	if wealth >= 500:
		result.append("入席")
	return result


func race_odds(beast_index: int, ticket_type: String) -> float:
	if beast_index < 0 or beast_index >= RACE_BEASTS.size():
		return 1.0
	var weather_key := weather if RACE_WIN_PROBABILITIES.has(weather) else "晴"
	var probabilities: Array = RACE_TOP3_PROBABILITIES[weather_key] if ticket_type == "入席" else RACE_WIN_PROBABILITIES[weather_key]
	var probability := maxf(0.00001, float(probabilities[beast_index]))
	return clampf(RACE_TARGET_RETURN / probability, 1.01, 20.0)


func race_bet_cap(available_cash: int = -1) -> int:
	var wealth_cap := maxi(50, int(floor(float(account_wealth()) * 0.10)))
	var spendable := cash if available_cash < 0 else available_cash
	return mini(spendable, mini(5000, wealth_cap))


func run_race(beast_index: int, ticket_type: String, requested_bet: int, aid_id: String = "") -> Dictionary:
	if beast_index < 0 or beast_index >= RACE_BEASTS.size():
		return {"ok": false, "text": "请选择逐风兽。"}
	if not ticket_types().has(ticket_type):
		return {"ok": false, "text": "当前持有的金贝尚未解锁该票种。"}
	var aid_info := race_aid_info(aid_id, beast_index)
	if not bool(aid_info.get("ok", false)):
		return aid_info
	var aid_fee := int(aid_info.get("fee", 0))
	if cash < aid_fee:
		return {"ok": false, "text": "部署%s需要%d金贝。" % [str(aid_info.get("name", "造物")), aid_fee]}
	var cash_before := cash
	var used_free := free_race_ticket > 0
	var max_bet := race_bet_cap(cash - aid_fee)
	if not used_free and max_bet < 10:
		return {"ok": false, "text": "支付辅助费后不足以购买最低10金贝祝胜券。"}
	var stake := 10 if used_free else mini(max_bet, maxi(10, requested_bet))
	cash -= aid_fee
	if used_free:
		free_race_ticket -= 1
	else:
		cash -= stake
		locked_principal += stake

	var results: Array = []
	for index in range(RACE_BEASTS.size()):
		var beast: Dictionary = RACE_BEASTS[index]
		var stability := float(beast["stability"])
		var sigma := 12.0 - stability * 0.08
		var stage_bases := _race_stage_bases(beast)
		var weather_mod := _race_weather_modifier(beast)
		var score := float(beast["form"])
		var stage_scores: Array[float] = []
		for stage in range(4):
			score += float(stage_bases[stage]) + weather_mod + rng.randfn(0.0, sigma)
			stage_scores.append(score)
		results.append({"index": index, "name": beast["name"], "score": score, "stage_scores": stage_scores})
	results.sort_custom(func(a, b): return float(a["score"]) > float(b["score"]))
	var stage_reports: Array = []
	var stage_names := ["起步", "巡航", "地形", "冲刺"]
	for stage in range(4):
		var stage_order: Array = results.duplicate(true)
		stage_order.sort_custom(func(a, b): return float(a["stage_scores"][stage]) > float(b["stage_scores"][stage]))
		var selected_rank := 0
		for rank_index in range(stage_order.size()):
			if int(stage_order[rank_index]["index"]) == beast_index:
				selected_rank = rank_index + 1
				break
		stage_reports.append({
			"stage": stage_names[stage],
			"leader": str(stage_order[0]["name"]),
			"selected_rank": selected_rank
		})

	var place := 0
	for index in range(results.size()):
		if int(results[index]["index"]) == beast_index:
			place = index + 1
			break
	var won := place == 1 if ticket_type == "独胜" else place <= 3
	var odds := race_odds(beast_index, ticket_type)
	var payout := int(round(stake * odds)) if won else 0
	if not used_free:
		locked_principal = maxi(0, locked_principal - stake)
	cash += payout
	advance_time(1)
	_record_wealth("逐风竞速 · %s" % ("命中" if won else "未中"))
	changed.emit()
	return {
		"ok": true,
		"won": won,
		"place": place,
		"payout": payout,
		"stake": stake,
		"aid_id": aid_id,
		"aid_name": str(aid_info.get("name", "不使用造物")),
		"aid_fee": aid_fee,
		"aid_insight": str(aid_info.get("insight", "")),
		"cash_before": cash_before,
		"cash_after": cash,
		"net_cash": cash - cash_before,
		"free": used_free,
		"odds": odds,
		"bet_cap": max_bet,
		"bet_was_capped": not used_free and requested_bet > max_bet,
		"results": results,
		"stage_reports": stage_reports,
		"text": "%s获得第%d名。%s%s" % [
			RACE_BEASTS[beast_index]["name"], place,
			("返还%d金贝。" % payout) if won else "祝胜券未命中。",
			(" %s部署费%d金贝。" % [str(aid_info.get("name", "造物")), aid_fee]) if aid_fee > 0 else ""
		]
	}


func begin_poker_session(buy_in: int = 80) -> void:
	if poker_session_active:
		return
	var tier := poker_tier_for_buy_in(buy_in)
	poker_session_buy_in = int(tier["buy_in"])
	poker_session_active = true
	poker_session_id = "table-%d" % int(Time.get_unix_time_from_system() * 1000.0)
	poker_session_hands = 0
	poker_dealer_index = -1
	poker_dealer_seat = -1
	poker_session_end_reason = ""
	poker_player_brought = cash
	poker_session_tutorial = not poker_completed and poker_session_buy_in == 80
	poker_tutorial_balance = 100 if poker_session_tutorial else 0
	poker_tutorial_settled = false
	poker_session_time_charged = false
	poker_session_seed = int(Time.get_unix_time_from_system() * 1000000.0) ^ int(Time.get_ticks_usec())
	rng.seed = poker_session_seed
	poker = {}
	poker_npc_wallets.clear()
	poker_npc_brought.clear()
	poker_npc_present.clear()
	var wallet_ranges := [[1.5, 2.8], [2.2, 3.8], [1.3, 2.4], [1.8, 3.0], [2.5, 4.5]]
	for limits in wallet_ranges:
		var minimum := int(round(float(limits[0]) * poker_session_buy_in))
		var maximum := int(round(float(limits[1]) * poker_session_buy_in))
		var amount := rng.randi_range(minimum, maximum)
		poker_npc_wallets.append(amount)
		poker_npc_brought.append(amount)
		poker_npc_present.append(true)
	changed.emit()


func _settle_poker_tutorial_profit() -> void:
	if not poker_session_tutorial or poker_tutorial_settled:
		return
	var profit := maxi(0, poker_tutorial_balance - 100)
	if profit > 0:
		cash += profit
		poker_session_end_reason += (" 教学盈利%d金贝已转入钱包。" % profit)
	poker_tutorial_settled = true


func _charge_poker_session_time() -> void:
	if poker_session_time_charged or poker_session_hands <= 0:
		return
	poker_session_time_charged = true
	advance_time(2)
	_record_wealth("命运牌会 · 离桌")


func _close_poker_session(reason: String) -> void:
	poker_session_active = false
	poker_session_end_reason = reason
	_settle_poker_tutorial_profit()
	_charge_poker_session_time()
	if not poker.is_empty():
		poker["session_ended"] = true
		poker["session_end_reason"] = poker_session_end_reason


func end_poker_session() -> void:
	if not poker_session_active and poker_session_time_charged:
		return
	_close_poker_session("本次牌会已结束。")
	changed.emit()


func poker_player_available() -> int:
	var base := poker_tutorial_balance if poker_session_tutorial else cash
	if not poker.is_empty() and not bool(poker.get("completed", true)):
		base += int(poker.get("player_stack", 0))
	return base


func poker_npc_available(index: int) -> int:
	if index < 0 or index >= poker_npc_wallets.size():
		return 0
	var amount := int(poker_npc_wallets[index])
	if not poker.is_empty() and not bool(poker.get("completed", true)):
		var stacks: Array = poker.get("opponent_stacks", [])
		if index < stacks.size():
			amount += int(stacks[index])
	return amount


func poker_wealth_leaderboard() -> Array:
	var entries: Array = []
	var player_current := poker_player_available()
	var player_start := 100 if poker_session_tutorial else poker_player_brought
	entries.append({"id": "player", "name": "你", "current": player_current, "start": player_start, "net": player_current - player_start, "present": true})
	for index in range(ORACLE_OPPONENTS.size()):
		var current := poker_npc_available(index)
		var started := int(poker_npc_brought[index]) if index < poker_npc_brought.size() else current
		entries.append({"id": str(index), "name": str(ORACLE_OPPONENTS[index]["name"]), "current": current, "start": started, "net": current - started, "present": bool(poker_npc_present[index]) if index < poker_npc_present.size() else true})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["net"]) == int(b["net"]):
			return int(a["current"]) > int(b["current"])
		return int(a["net"]) > int(b["net"])
	)
	return entries


func _seat_name(seat_index: int) -> String:
	return "你" if seat_index == 0 else str(ORACLE_OPPONENTS[seat_index - 1]["name"])


func _next_table_seat(after_seat: int) -> int:
	for offset in range(1, 7):
		var candidate := posmod(after_seat + offset, 6)
		if poker.is_empty() or not poker.has("seats"):
			return candidate
		var seats: Array = poker["seats"]
		if candidate < seats.size() and bool(seats[candidate].get("present", true)):
			return candidate
	return -1


func _clockwise_seats_from(start_seat: int) -> Array[int]:
	var result: Array[int] = []
	for offset in range(6):
		result.append(posmod(start_seat + offset, 6))
	return result


func _sync_poker_views() -> void:
	if poker.is_empty() or not poker.has("seats"):
		return
	var seats: Array = poker["seats"]
	poker["player_stack"] = int(seats[0]["stack"])
	poker["player_round_commit"] = int(seats[0]["round_commit"])
	poker["player_hand_commit"] = int(seats[0]["hand_commit"])
	poker["player_action"] = str(seats[0]["action"])
	var active: Array = []
	var stacks: Array = []
	var round_commits: Array = []
	var hand_commits: Array = []
	var actions: Array = []
	for seat_index in range(1, 6):
		var seat: Dictionary = seats[seat_index]
		active.append(bool(seat["present"]) and not bool(seat["folded"]))
		stacks.append(int(seat["stack"]))
		round_commits.append(int(seat["round_commit"]))
		hand_commits.append(int(seat["hand_commit"]))
		actions.append(str(seat["action"]))
	poker["active"] = active
	poker["opponent_stacks"] = stacks
	poker["opponent_round_commits"] = round_commits
	poker["opponent_hand_commits"] = hand_commits
	poker["opponent_actions"] = actions
	poker["pot"] = _poker_total_committed()
	var player_to_call := maxi(0, int(poker.get("current_bet", 0)) - int(seats[0]["round_commit"]))
	poker["to_call"] = player_to_call


func _poker_total_committed() -> int:
	var total := 0
	for seat in poker.get("seats", []):
		total += int(seat.get("hand_commit", 0))
	return total


func start_poker_hand(buy_in_override: int = -1) -> Dictionary:
	if not poker.is_empty() and not bool(poker.get("completed", true)):
		return {"ok": false, "text": "当前命运契约还没有结束。"}
	if not poker_session_active and not poker.is_empty() and bool(poker.get("session_ended", false)):
		return {"ok": false, "session_ended": true, "text": str(poker.get("session_end_reason", "本次牌会已经结束。"))}
	var requested_buy_in := buy_in_override if buy_in_override > 0 else poker_session_buy_in
	if not poker_session_active:
		begin_poker_session(requested_buy_in)
	var tier := poker_tier_for_buy_in(poker_session_buy_in)
	var buy_in := int(tier["buy_in"])
	if account_wealth() < int(tier["wealth_required"]):
		return {"ok": false, "text": "%s需要账户财富达到%d金贝。" % [str(tier["name"]), int(tier["wealth_required"])]}
	if poker_player_available() < buy_in:
		return {"ok": false, "text": "进入%s至少需要%d金贝%s。" % [str(tier["name"]), buy_in, "教学额度" if poker_session_tutorial else ""]}
	if poker_session_hands >= 8:
		_close_poker_session("短牌会最多8手，本次牌会结束。")
		return {"ok": false, "session_ended": true, "text": poker_session_end_reason}
	for index in range(5):
		if index >= poker_npc_wallets.size() or int(poker_npc_wallets[index]) <= 0:
			_close_poker_session("已有客人钱包归零，本次牌会结束。")
			return {"ok": false, "session_ended": true, "text": poker_session_end_reason}

	var cash_before_hand := cash
	var bank_before := poker_player_available()
	if poker_session_tutorial:
		poker_tutorial_balance -= buy_in
	else:
		cash -= buy_in
		locked_principal += buy_in
	var deck: Array[int] = []
	for card in range(48):
		deck.append(card)
	_shuffle(deck)
	var player_hand := [deck.pop_back(), deck.pop_back()]
	var opponent_hands: Array = []
	for _opponent in range(5):
		opponent_hands.append([deck.pop_back(), deck.pop_back()])
	var community: Array = []
	for _card in range(5):
		community.append(deck.pop_back())

	var seats: Array = []
	seats.append({"seat": 0, "name": "你", "npc_index": -1, "present": true, "stack": buy_in, "round_commit": 0, "hand_commit": 0, "folded": false, "all_in": false, "needs_action": true, "round_actions": 0, "action": "等待行动"})
	var opponent_limits: Array = []
	for index in range(5):
		var limit := mini(buy_in, int(poker_npc_wallets[index]))
		poker_npc_wallets[index] = int(poker_npc_wallets[index]) - limit
		opponent_limits.append(limit)
		seats.append({"seat": index + 1, "name": str(ORACLE_OPPONENTS[index]["name"]), "npc_index": index, "present": true, "stack": limit, "round_commit": 0, "hand_commit": 0, "folded": false, "all_in": false, "needs_action": true, "round_actions": 0, "action": "等待"})

	poker_session_hands += 1
	poker = {
		"hand_id": "oracle-%d-%d" % [int(Time.get_unix_time_from_system() * 1000.0), poker_session_hands],
		"session_id": poker_session_id, "session_hand": poker_session_hands, "session_seed": poker_session_seed,
		"cash_before": cash_before_hand, "player_bank_before": bank_before,
		"buy_in": buy_in, "tier_name": str(tier["name"]), "small_blind": int(tier["small_blind"]), "big_blind": int(tier["big_blind"]),
		"completed": false, "stage": 0, "player_hand": player_hand, "opponent_hands": opponent_hands, "community": community,
		"seats": seats, "opponent_hand_limits": opponent_limits, "current_bet": 0, "min_raise": int(tier["big_blind"]), "current_actor": -1,
		"result": "", "action_log": [], "showdown": [], "player_reading": {}, "final_readings": [], "winner_names": [],
		"outcome_reason": "", "settlement": {}, "action_history": [], "last_action_sequence": [], "session_ended": false, "session_end_reason": "", "transparent_after_player_fold": false
	}
	poker_dealer_seat = rng.randi_range(0, 5) if poker_dealer_seat < 0 else _next_table_seat(poker_dealer_seat)
	var small_blind_seat := _next_table_seat(poker_dealer_seat)
	var big_blind_seat := _next_table_seat(small_blind_seat)
	var first_actor := _next_table_seat(big_blind_seat)
	poker["dealer_seat"] = poker_dealer_seat
	poker["small_blind_seat"] = small_blind_seat
	poker["big_blind_seat"] = big_blind_seat
	poker["first_actor_seat"] = first_actor
	poker_dealer_index = poker_dealer_seat - 1 if poker_dealer_seat > 0 else -1
	poker["dealer_index"] = poker_dealer_index
	poker["first_action_index"] = first_actor - 1 if first_actor > 0 else -1
	var opponent_order: Array[int] = []
	for seat_index in _clockwise_seats_from(first_actor):
		if seat_index > 0:
			opponent_order.append(seat_index - 1)
	poker["opponent_action_order"] = opponent_order
	poker["action_log"].append("本手司契位：%s；首位行动：%s。" % [_seat_name(poker_dealer_seat), _seat_name(first_actor)])
	_poker_post_blind(small_blind_seat, int(tier["small_blind"]), "小盲")
	_poker_post_blind(big_blind_seat, int(tier["big_blind"]), "大盲")
	poker["current_actor"] = first_actor
	_sync_poker_views()
	_append_oracle_event("hand_start", {"session_seed": poker_session_seed, "cash_before": cash_before_hand, "player_bank_before": bank_before, "buy_in": buy_in, "player_hand": _oracle_cards_for_record(player_hand), "stage": poker_stage_name(), "pot": int(poker["pot"]), "seats": seats.duplicate(true)})
	var progress := _poker_auto_until_player()
	if bool(progress.get("completed", false)):
		return progress
	_sync_poker_views()
	changed.emit()
	return {"ok": true, "text": "已进入%s。司契位%s，轮到%s；底池%d金贝。" % [str(tier["name"]), _seat_name(poker_dealer_seat), _seat_name(int(poker["current_actor"])), int(poker["pot"])], "npc_action_sequence": poker.get("last_action_sequence", []).duplicate(true)}


func _poker_post_blind(seat_index: int, amount: int, label: String) -> void:
	var seats: Array = poker["seats"]
	var seat: Dictionary = seats[seat_index]
	var paid := mini(amount, int(seat["stack"]))
	seat["stack"] = int(seat["stack"]) - paid
	seat["round_commit"] = int(seat["round_commit"]) + paid
	seat["hand_commit"] = int(seat["hand_commit"]) + paid
	seat["all_in"] = int(seat["stack"]) == 0
	seat["action"] = "%s%d金贝" % [label, paid]
	seats[seat_index] = seat
	poker["seats"] = seats
	poker["current_bet"] = maxi(int(poker["current_bet"]), int(seat["round_commit"]))
	poker["action_log"].append("%s投入%s%d金贝。" % [_seat_name(seat_index), label, paid])


func poker_visible_community() -> Array:
	if poker.is_empty():
		return []
	var counts := [0, 2, 4, 5, 5]
	return poker["community"].slice(0, counts[clampi(int(poker.get("stage", 0)), 0, 4)])


func poker_stage_name() -> String:
	if poker.is_empty():
		return "未开始"
	var names := ["藏命", "初兆", "交汇", "定命", "解契"]
	return names[clampi(int(poker.get("stage", 0)), 0, 4)]


func _poker_live_seats() -> Array[int]:
	var result: Array[int] = []
	for seat_index in range(poker.get("seats", []).size()):
		var seat: Dictionary = poker["seats"][seat_index]
		if bool(seat["present"]) and not bool(seat["folded"]):
			result.append(seat_index)
	return result


func _next_needing_seat(after_seat: int) -> int:
	var seats: Array = poker["seats"]
	for offset in range(1, 7):
		var candidate := posmod(after_seat + offset, 6)
		var seat: Dictionary = seats[candidate]
		if bool(seat["present"]) and not bool(seat["folded"]) and not bool(seat["all_in"]) and bool(seat["needs_action"]):
			return candidate
	return -1


func _poker_round_complete() -> bool:
	var current_bet := int(poker.get("current_bet", 0))
	for seat in poker.get("seats", []):
		if not bool(seat["present"]) or bool(seat["folded"]) or bool(seat["all_in"]):
			continue
		if bool(seat["needs_action"]) or int(seat["round_commit"]) != current_bet:
			return false
	return true


func _poker_open_next_round() -> void:
	poker["stage"] = int(poker["stage"]) + 1
	poker["current_bet"] = 0
	poker["min_raise"] = int(poker.get("big_blind", 2))
	var seats: Array = poker["seats"]
	for seat_index in range(seats.size()):
		var seat: Dictionary = seats[seat_index]
		seat["round_commit"] = 0
		seat["round_actions"] = 0
		seat["needs_action"] = bool(seat["present"]) and not bool(seat["folded"]) and not bool(seat["all_in"])
		if bool(seat["all_in"]):
			seat["action"] = "已全投 · 等待解契"
		seats[seat_index] = seat
	poker["seats"] = seats
	var first_actor := _next_table_seat(int(poker["dealer_seat"]))
	poker["first_actor_seat"] = first_actor
	poker["first_action_index"] = first_actor - 1 if first_actor > 0 else -1
	poker["current_actor"] = _next_needing_seat(posmod(first_actor - 1, 6))
	poker["action_log"].append("进入%s，首位行动：%s。" % [poker_stage_name(), _seat_name(first_actor)])
	_append_oracle_event("stage_opened", {"stage": poker_stage_name(), "visible_community": _oracle_cards_for_record(poker_visible_community()), "pot": _poker_total_committed(), "first_actor": _seat_name(first_actor)})


func _poker_apply_action(seat_index: int, action: String, raise_amount: int = 0) -> Dictionary:
	var seats: Array = poker["seats"]
	var seat: Dictionary = seats[seat_index]
	var current_bet := int(poker.get("current_bet", 0))
	var to_call := maxi(0, current_bet - int(seat["round_commit"]))
	var paid := 0
	var action_text := ""
	var raised := false
	if action == "fold":
		seat["folded"] = true
		seat["needs_action"] = false
		action_text = "退契"
		if seat_index == 0:
			poker["transparent_after_player_fold"] = true
			poker["outcome_reason"] = "fold_showdown"
	elif action == "call":
		paid = mini(to_call, int(seat["stack"]))
		seat["stack"] = int(seat["stack"]) - paid
		seat["round_commit"] = int(seat["round_commit"]) + paid
		seat["hand_commit"] = int(seat["hand_commit"]) + paid
		seat["all_in"] = int(seat["stack"]) == 0
		seat["needs_action"] = false
		action_text = "静观" if paid == 0 else ("跟契%d金贝" % paid)
	elif action in ["raise", "all_in"]:
		var desired_target := int(seat["round_commit"]) + int(seat["stack"]) if action == "all_in" else current_bet + maxi(int(poker.get("min_raise", 1)), raise_amount)
		desired_target = mini(desired_target, int(seat["round_commit"]) + int(seat["stack"]))
		if desired_target <= current_bet and action != "all_in":
			return {"ok": false, "text": "剩余额度不足以完成最低加契。"}
		paid = maxi(0, desired_target - int(seat["round_commit"]))
		seat["stack"] = int(seat["stack"]) - paid
		seat["round_commit"] = int(seat["round_commit"]) + paid
		seat["hand_commit"] = int(seat["hand_commit"]) + paid
		seat["all_in"] = int(seat["stack"]) == 0
		seat["needs_action"] = false
		if int(seat["round_commit"]) > current_bet:
			var raise_size := int(seat["round_commit"]) - current_bet
			raised = true
			poker["current_bet"] = int(seat["round_commit"])
			if raise_size >= int(poker.get("min_raise", 1)):
				poker["min_raise"] = raise_size
			for other_index in range(seats.size()):
				if other_index == seat_index:
					continue
				var other: Dictionary = seats[other_index]
				if bool(other["present"]) and not bool(other["folded"]) and not bool(other["all_in"]) and int(other["round_commit"]) < int(poker["current_bet"]):
					other["needs_action"] = true
					seats[other_index] = other
		action_text = ("全部投入%d金贝" % paid) if bool(seat["all_in"]) else ("加契至%d金贝" % int(seat["round_commit"]))
	else:
		return {"ok": false, "text": "无法识别这次契约行动。"}
	seat["action"] = action_text
	seat["round_actions"] = int(seat.get("round_actions", 0)) + 1
	seats[seat_index] = seat
	poker["seats"] = seats
	poker["action_log"].append("%s%s。" % [_seat_name(seat_index), action_text])
	poker["current_actor"] = _next_needing_seat(seat_index)
	_sync_poker_views()
	var event := {"ok": true, "seat": seat_index, "npc_index": seat_index - 1, "name": _seat_name(seat_index), "stage": poker_stage_name(), "action": action, "action_text": action_text, "action_number": int(seat["round_actions"]), "paid": paid, "raised": raised, "round_commit": int(seat["round_commit"]), "hand_commit": int(seat["hand_commit"]), "pot": int(poker["pot"])}
	poker["action_history"].append(event.duplicate(true))
	return event


func _poker_npc_action(seat_index: int) -> Dictionary:
	var seat: Dictionary = poker["seats"][seat_index]
	var npc_index := seat_index - 1
	var to_call := maxi(0, int(poker["current_bet"]) - int(seat["round_commit"]))
	if poker_test_passive_ai:
		return _poker_apply_action(seat_index, "call")
	var public_cards := poker_visible_community()
	var strength := _oracle_current_strength(poker["opponent_hands"][npc_index], public_cards)
	var style := str(ORACLE_OPPONENTS[npc_index]["style"])
	var pot_after_call := int(poker.get("pot", 0)) + to_call
	var pot_odds := float(to_call) / maxf(1.0, float(pot_after_call))
	var position_bonus := 0.04 if posmod(seat_index - int(poker["dealer_seat"]), 6) >= 4 else 0.0
	var style_courage := 0.09 if style == "潮汐型" else (-0.07 if style == "礁石型" else 0.0)
	var courage := strength + style_courage + position_bonus
	if to_call > 0:
		var is_opening_blind_call := int(poker.get("stage", 0)) == 0 and int(poker.get("current_bet", 0)) == int(poker.get("big_blind", 2)) and to_call <= int(poker.get("big_blind", 2))
		if is_opening_blind_call:
			var base_fold := 0.20 if style == "潮汐型" else (0.34 if style == "礁石型" else 0.27)
			var position := posmod(seat_index - int(poker["dealer_seat"]), 6)
			var position_adjust := 0.06 if position == 3 else (0.02 if position == 4 else (-0.04 if position in [0, 5] else 0.03))
			var hand_adjust := clampf((0.29 - strength) * 0.55, -0.10, 0.10)
			var opening_fold_chance := clampf(base_fold + position_adjust + hand_adjust, 0.08, 0.48)
			if rng.randf() < opening_fold_chance:
				return _poker_apply_action(seat_index, "fold")
		else:
			var pressure := float(to_call) / maxf(1.0, float(int(seat["stack"]) + to_call))
			var fold_threshold := 0.18 + pot_odds * 0.55 + pressure * 0.28
			if courage + rng.randf_range(-0.10, 0.10) < fold_threshold:
				return _poker_apply_action(seat_index, "fold")
	var can_raise := int(seat["stack"]) > to_call + int(poker["min_raise"])
	var raise_chance := clampf((courage - 0.52) * 0.34, 0.0, 0.18)
	if can_raise and rng.randf() < raise_chance:
		var extra := maxi(int(poker["min_raise"]), int(round(float(poker.get("pot", 0) + to_call) * (0.45 if style != "潮汐型" else 0.65))))
		return _poker_apply_action(seat_index, "raise", extra)
	return _poker_apply_action(seat_index, "call")


func _poker_auto_until_player() -> Dictionary:
	var sequence: Array = []
	var safety := 0
	while safety < 240:
		safety += 1
		if _poker_live_seats().size() <= 1:
			poker["last_action_sequence"] = sequence
			return _poker_finish_uncontested()
		if _poker_round_complete():
			if int(poker["stage"]) >= 3:
				poker["last_action_sequence"] = sequence
				return _poker_showdown_state_machine()
			_poker_open_next_round()
			continue
		var actor := int(poker.get("current_actor", -1))
		if actor < 0:
			actor = _next_needing_seat(int(poker.get("dealer_seat", 0)))
			poker["current_actor"] = actor
		if actor == 0:
			poker["last_action_sequence"] = sequence
			_sync_poker_views()
			return {"ok": true, "completed": false, "npc_action_sequence": sequence}
		if actor < 0:
			continue
		var event := _poker_npc_action(actor)
		if not bool(event.get("ok", false)):
			return event
		sequence.append(event)
		_append_oracle_event("npc_action", {"stage": poker_stage_name(), "seat": int(event.get("seat", actor)), "name": str(event.get("name", _seat_name(actor))), "action": str(event.get("action", "")), "action_text": str(event.get("action_text", "")), "paid": int(event.get("paid", 0)), "round_commit": int(event.get("round_commit", 0)), "hand_commit": int(event.get("hand_commit", 0)), "pot": int(event.get("pot", 0))})
	return {"ok": false, "text": "下注轮未能收敛，已停止本手以保护资金。"}


func poker_action(action: String, raise_amount: int = 0) -> Dictionary:
	if poker.is_empty() or bool(poker.get("completed", true)):
		return {"ok": false, "text": "当前没有进行中的命运契约。"}
	if int(poker.get("current_actor", -1)) != 0:
		return {"ok": false, "text": "当前还没有轮到你。"}
	var event := _poker_apply_action(0, action, raise_amount)
	if not bool(event.get("ok", false)):
		return event
	_append_oracle_event("player_action", {"stage": poker_stage_name(), "action": action, "action_text": str(event["action_text"]), "paid": int(event["paid"]), "round_commit": int(event["round_commit"]), "hand_commit": int(event["hand_commit"]), "pot": int(event["pot"]), "visible_community": _oracle_cards_for_record(poker_visible_community())})
	var progress := _poker_auto_until_player()
	if bool(progress.get("completed", false)):
		return progress
	_sync_poker_views()
	changed.emit()
	return {"ok": true, "completed": false, "text": "轮到你行动。需补齐%d金贝；底池%d金贝。" % [int(poker["to_call"]), int(poker["pot"])], "npc_action_sequence": poker.get("last_action_sequence", []).duplicate(true)}


func _poker_showdown_state_machine() -> Dictionary:
	poker["stage"] = 4
	var scores := {}
	var showdown: Array = []
	for seat_index in _poker_live_seats():
		var private_cards: Array = poker["player_hand"] if seat_index == 0 else poker["opponent_hands"][seat_index - 1]
		var reading := oracle_best_reading(private_cards, poker["community"])
		scores[seat_index] = reading
		if seat_index == 0:
			poker["player_reading"] = reading
		else:
			showdown.append({"index": seat_index - 1, "name": _seat_name(seat_index), "hand": private_cards, "reading": reading})
	poker["showdown"] = showdown
	var reason := "fold_showdown" if bool(poker.get("transparent_after_player_fold", false)) else "showdown"
	return _finish_poker_state_machine(reason, scores)


func _poker_finish_uncontested() -> Dictionary:
	var live := _poker_live_seats()
	var scores := {}
	if bool(poker.get("transparent_after_player_fold", false)) and not live.is_empty():
		poker["stage"] = 4
		var winner_seat := int(live[0])
		var private_cards: Array = poker["player_hand"] if winner_seat == 0 else poker["opponent_hands"][winner_seat - 1]
		var reading := oracle_best_reading(private_cards, poker["community"])
		scores[winner_seat] = reading
		if winner_seat > 0:
			poker["showdown"] = [{"index": winner_seat - 1, "name": _seat_name(winner_seat), "hand": private_cards, "reading": reading}]
	return _finish_poker_state_machine("fold_showdown" if bool(poker.get("transparent_after_player_fold", false)) else "all_fold", scores)


func _poker_best_winners(eligible: Array, scores: Dictionary) -> Array[int]:
	if eligible.size() <= 1:
		var only: Array[int] = []
		if eligible.size() == 1:
			only.append(int(eligible[0]))
		return only
	var winners: Array[int] = []
	var best_score: Array = []
	for raw_seat in eligible:
		var seat_index := int(raw_seat)
		if not scores.has(seat_index):
			continue
		var score: Array = scores[seat_index]["score"]
		if winners.is_empty() or _compare_scores(score, best_score) > 0:
			best_score = score
			winners = [seat_index]
		elif _compare_scores(score, best_score) == 0:
			winners.append(seat_index)
	return winners


func _poker_build_pots(scores: Dictionary) -> Dictionary:
	var seats: Array = poker["seats"]
	var levels: Array[int] = []
	for seat in seats:
		var amount := int(seat["hand_commit"])
		if amount > 0 and not levels.has(amount):
			levels.append(amount)
	levels.sort()
	var layers: Array = []
	var previous := 0
	var refunds := [0, 0, 0, 0, 0, 0]
	for level in levels:
		var contributors: Array[int] = []
		var eligible: Array[int] = []
		for seat_index in range(seats.size()):
			if int(seats[seat_index]["hand_commit"]) >= level:
				contributors.append(seat_index)
				if not bool(seats[seat_index]["folded"]):
					eligible.append(seat_index)
		var amount := (level - previous) * contributors.size()
		if contributors.size() == 1:
			refunds[contributors[0]] = int(refunds[contributors[0]]) + amount
		else:
			layers.append({"cap": level, "amount": amount, "contributors": contributors, "eligible": eligible})
		previous = level
	var contestable_total := 0
	for layer in layers:
		contestable_total += int(layer["amount"])
	var service_fee := 0 if poker_session_tutorial else mini(int(floor(float(contestable_total) * 0.02)), int(poker.get("big_blind", 2)))
	var fee_remaining := service_fee
	var payouts := [0, 0, 0, 0, 0, 0]
	var pot_details: Array = []
	var all_winner_seats: Array[int] = []
	for layer_index in range(layers.size()):
		var layer: Dictionary = layers[layer_index]
		var fee_here := mini(fee_remaining, int(layer["amount"]))
		fee_remaining -= fee_here
		var distributable := int(layer["amount"]) - fee_here
		var winners := _poker_best_winners(layer["eligible"], scores)
		if winners.is_empty() and _poker_live_seats().size() == 1:
			winners = [int(_poker_live_seats()[0])]
		var share := distributable / maxi(1, winners.size())
		var odd := distributable % maxi(1, winners.size())
		for winner in winners:
			payouts[winner] = int(payouts[winner]) + share
			if not all_winner_seats.has(winner):
				all_winner_seats.append(winner)
		if odd > 0:
			for seat_index in _clockwise_seats_from(_next_table_seat(int(poker["dealer_seat"]))):
				if winners.has(seat_index) and odd > 0:
					payouts[seat_index] = int(payouts[seat_index]) + 1
					odd -= 1
		pot_details.append({"name": "主池" if layer_index == 0 else "边池%d" % layer_index, "gross": int(layer["amount"]), "fee": fee_here, "amount": distributable, "cap": int(layer["cap"]), "eligible_seats": layer["eligible"].duplicate(), "winner_seats": winners.duplicate()})
	return {"payouts": payouts, "refunds": refunds, "service_fee": service_fee, "pots": pot_details, "winner_seats": all_winner_seats, "committed_total": _poker_total_committed()}


func _poker_final_readings(winner_seats: Array, scores: Dictionary) -> Array:
	var results: Array = []
	var seats: Array = poker["seats"]
	for seat_index in range(seats.size()):
		var seat: Dictionary = seats[seat_index]
		var entry := {"id": "player" if seat_index == 0 else str(seat_index - 1), "name": _seat_name(seat_index), "winner": winner_seats.has(seat_index), "folded": bool(seat["folded"]), "reading_name": "", "reading_text": "", "status": ""}
		if bool(seat["folded"]):
			entry["status"] = "已退契 · 未参与最终比较"
		elif scores.has(seat_index):
			var reading: Dictionary = scores[seat_index]
			entry["reading_name"] = str(reading.get("name", "尚未成象"))
			entry["reading_text"] = str(reading.get("text", ""))
			entry["status"] = "赢家" if bool(entry["winner"]) else "未获胜"
		elif bool(entry["winner"]):
			entry["status"] = "赢家 · 其余席位均已退契"
		else:
			entry["status"] = "未参与最终比较"
		results.append(entry)
	return results


func _finish_poker_state_machine(reason: String, scores: Dictionary) -> Dictionary:
	var pot_result := _poker_build_pots(scores)
	var payouts: Array = pot_result["payouts"]
	var refunds: Array = pot_result["refunds"]
	var winner_seats: Array = pot_result["winner_seats"]
	var seats: Array = poker["seats"]
	var player_stack_return := int(seats[0]["stack"])
	var player_return := player_stack_return + int(payouts[0]) + int(refunds[0])
	if poker_session_tutorial:
		poker_tutorial_balance += player_return
	else:
		cash += player_return
		locked_principal = maxi(0, locked_principal - int(poker.get("buy_in", 80)))
	var left_names: Array[String] = []
	for seat_index in range(1, 6):
		var npc_index := seat_index - 1
		poker_npc_wallets[npc_index] = int(poker_npc_wallets[npc_index]) + int(seats[seat_index]["stack"]) + int(payouts[seat_index]) + int(refunds[seat_index])
		if int(poker_npc_wallets[npc_index]) <= 0:
			poker_npc_wallets[npc_index] = 0
			poker_npc_present[npc_index] = false
			left_names.append(_seat_name(seat_index))

	var winner_names: Array[String] = []
	for seat_index in winner_seats:
		var name := _seat_name(int(seat_index))
		if not winner_names.has(name):
			winner_names.append(name)
	for seat_index in range(seats.size()):
		var seat: Dictionary = seats[seat_index]
		if bool(seat["folded"]):
			seat["action"] = "退契"
		elif winner_seats.has(seat_index):
			seat["action"] = "赢得底池"
		else:
			seat["action"] = "解契未胜"
		if seat_index > 0 and not bool(poker_npc_present[seat_index - 1]):
			seat["action"] = "输光离桌"
		seats[seat_index] = seat
	poker["seats"] = seats
	poker["winner_names"] = winner_names
	poker["outcome_reason"] = reason
	poker["stage"] = 4
	poker["completed"] = true
	poker_completed = true
	poker["npc_left_names"] = left_names
	poker["npc_wallets_after"] = poker_npc_wallets.duplicate()
	poker["side_pots"] = pot_result["pots"]
	poker["final_readings"] = _poker_final_readings(winner_seats, scores)
	_sync_poker_views()

	var player_bank_after := poker_player_available()
	var bank_before := int(poker.get("player_bank_before", player_bank_after))
	var bank_net := player_bank_after - bank_before
	var outcome := "fold" if bool(seats[0]["folded"]) else ("win" if winner_seats.has(0) else "loss")
	if winner_seats.has(0) and winner_seats.size() > 1:
		outcome = "tie"
	var outcome_labels := {"fold": "退契", "win": "胜利", "loss": "失利", "tie": "平分"}
	var outcome_label := str(outcome_labels[outcome])
	var session_reason := ""
	if not left_names.is_empty():
		session_reason = "%s的钱包已经归零，本次牌会结束。" % "、".join(left_names)
	elif poker_session_hands >= 8:
		session_reason = "短牌会已完成8手，本次牌会结束。"
	elif poker_player_available() < int(poker.get("buy_in", 80)):
		session_reason = "%s不足以进入下一手，本次牌会结束。" % ("教学额度" if poker_session_tutorial else "持有金贝")
	if not session_reason.is_empty():
		_close_poker_session(session_reason)

	var accounted := 0
	for amount in payouts:
		accounted += int(amount)
	for amount in refunds:
		accounted += int(amount)
	accounted += int(pot_result["service_fee"])
	var committed_total := int(pot_result["committed_total"])
	if accounted != committed_total:
		push_error("牌会资金守恒失败：投入%d，分配%d" % [committed_total, accounted])
	poker["settlement"] = {
		"outcome": outcome, "outcome_label": outcome_label,
		"cash_before": int(poker.get("cash_before", cash)), "cash_after": cash, "net_cash": cash - int(poker.get("cash_before", cash)),
		"player_bank_before": bank_before, "player_bank_after": poker_player_available(), "net_bank": poker_player_available() - bank_before,
		"buy_in": int(poker.get("buy_in", 80)), "remaining_stack": player_stack_return,
		"committed_total": committed_total, "player_hand_commit": int(seats[0]["hand_commit"]), "pot": committed_total,
		"pot_award": int(payouts[0]), "uncalled_return": int(refunds[0]), "returned": player_return,
		"service_fee": int(pot_result["service_fee"]), "payouts": payouts.duplicate(), "refunds": refunds.duplicate(), "side_pots": pot_result["pots"].duplicate(true),
		"winner_names": winner_names.duplicate(), "session_ended": not session_reason.is_empty(), "session_end_reason": poker_session_end_reason if not session_reason.is_empty() else "", "tutorial": poker_session_tutorial
	}
	poker["session_ended"] = not session_reason.is_empty()
	poker["session_end_reason"] = poker_session_end_reason if not session_reason.is_empty() else ""
	var winners_text := "、".join(winner_names) if not winner_names.is_empty() else "无人"
	poker["result"] = "%s。赢家：%s；全桌投入%d，服务费%d，未跟注返还%d；你本手%s金贝，当前%s%d金贝。" % [outcome_label, winners_text, committed_total, int(pot_result["service_fee"]), int(refunds[0]), _signed_number(bank_net), "教学额度" if poker_session_tutorial and not poker_tutorial_settled else "持有", poker_player_available() if poker_session_tutorial and not poker_tutorial_settled else cash]
	add_memory("old_joe", "你在椰影茶摊完成了一手水火占卜牌会。")
	var end_record := {"hand_id": str(poker.get("hand_id", "")), "completed_at": Time.get_datetime_string_from_system(), "day_after": day, "tide_after": tide, "outcome": outcome, "outcome_label": outcome_label, "winner_names": winner_names.duplicate(), "session_id": poker_session_id, "session_hand": poker_session_hands, "npc_wallets_after": poker_npc_wallets.duplicate(), "npc_present_after": poker_npc_present.duplicate(), "player_hand": _oracle_cards_for_record(poker["player_hand"]), "community": _oracle_cards_for_record(poker["community"]), "player_reading": poker.get("player_reading", {}).duplicate(true), "final_readings": poker["final_readings"].duplicate(true), "opponents": _oracle_opponents_for_record(true), "settlement": poker["settlement"].duplicate(true), "action_log": poker["action_log"].duplicate(), "result": str(poker["result"])}
	recent_oracle_records.push_front(end_record)
	if recent_oracle_records.size() > 20:
		recent_oracle_records.resize(20)
	_append_oracle_event("hand_end", end_record)
	changed.emit()
	return {"ok": true, "completed": true, "won": winner_seats.has(0), "outcome": outcome, "text": poker["result"], "npc_action_sequence": poker.get("last_action_sequence", []).duplicate(true)}


func _signed_number(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)


func cards_text(cards: Array) -> String:
	var parts: Array[String] = []
	for card in cards:
		parts.append(oracle_card_text(int(card)))
	return "  ".join(parts)


func oracle_card_element(card: int) -> int:
	return 0 if card < 24 else 1


func oracle_card_rank(card: int) -> int:
	return int((card % 24) / 4) + 1


func oracle_card_name(card: int) -> String:
	var rank := oracle_card_rank(card)
	return ORACLE_WATER_NAMES[rank - 1] if oracle_card_element(card) == 0 else ORACLE_FIRE_NAMES[rank - 1]


func oracle_card_text(card: int) -> String:
	var element_name := "水" if oracle_card_element(card) == 0 else "火"
	return "%s·%s〔%d阶〕" % [element_name, oracle_card_name(card), oracle_card_rank(card)]


func oracle_pattern_name(score: Array) -> String:
	if score.is_empty():
		return "尚未成象"
	return ORACLE_PATTERN_NAMES[clampi(int(score[0]), 0, ORACLE_PATTERN_NAMES.size() - 1)]


func oracle_best_reading(private_cards: Array, community_cards: Array) -> Dictionary:
	if private_cards.size() != 2 or community_cards.size() < 2:
		return {"score": [], "name": "尚未成象", "cards": private_cards.duplicate(), "public_cards": [], "text": "至少需要两张天象牌才能形成四张命象。"}
	var best_score: Array = []
	var best_cards: Array = []
	var best_public: Array = []
	for first in range(community_cards.size() - 1):
		for second in range(first + 1, community_cards.size()):
			var candidate := [private_cards[0], private_cards[1], community_cards[first], community_cards[second]]
			var score := _oracle_score_four(candidate)
			if best_score.is_empty() or _compare_scores(score, best_score) > 0:
				best_score = score
				best_cards = candidate
				best_public = [community_cards[first], community_cards[second]]
	return {
		"score": best_score,
		"name": oracle_pattern_name(best_score),
		"cards": best_cards,
		"public_cards": best_public,
		"text": _oracle_reading_text(best_score)
	}


func _oracle_score_four(cards: Array) -> Array:
	var identity_counts := {}
	var rank_counts := {}
	var elements: Array[int] = []
	var ranks: Array[int] = []
	for raw_card in cards:
		var card := int(raw_card)
		var element := oracle_card_element(card)
		var rank := oracle_card_rank(card)
		var identity := "%d:%d" % [element, rank]
		identity_counts[identity] = int(identity_counts.get(identity, 0)) + 1
		rank_counts[rank] = int(rank_counts.get(rank, 0)) + 1
		elements.append(element)
		ranks.append(rank)

	var unique_ranks: Array[int] = []
	for rank in ranks:
		if not unique_ranks.has(rank):
			unique_ranks.append(rank)
	unique_ranks.sort()
	var descending := ranks.duplicate()
	descending.sort()
	descending.reverse()
	var total := 0
	for rank in ranks:
		total += rank

	var max_identical := 1
	var repeated_ranks: Array[int] = []
	for identity in identity_counts.keys():
		var amount := int(identity_counts[identity])
		max_identical = maxi(max_identical, amount)
		if amount >= 2:
			repeated_ranks.append(int(str(identity).get_slice(":", 1)))
	repeated_ranks.sort()
	repeated_ranks.reverse()

	if max_identical == 4:
		return [8, repeated_ranks[0]]

	var consecutive := unique_ranks.size() == 4
	if consecutive:
		for index in range(1, unique_ranks.size()):
			if unique_ranks[index] != unique_ranks[index - 1] + 1:
				consecutive = false
				break
	if consecutive:
		var ordered_elements: Array[int] = []
		for rank in unique_ranks:
			for raw_card in cards:
				if oracle_card_rank(int(raw_card)) == rank:
					ordered_elements.append(oracle_card_element(int(raw_card)))
					break
		if ordered_elements == [0, 1, 0, 1] or ordered_elements == [1, 0, 1, 0]:
			return [7, unique_ranks[-1]]

	if unique_ranks.size() == 4 and elements.count(0) == 2 and elements.count(1) == 2:
		var water_total := 0
		var fire_total := 0
		for index in range(cards.size()):
			if elements[index] == 0:
				water_total += ranks[index]
			else:
				fire_total += ranks[index]
		if water_total == fire_total:
			var balanced_score: Array = [6, total]
			balanced_score.append_array(descending)
			return balanced_score

	if max_identical == 3:
		return [5, repeated_ranks[0], total]

	if unique_ranks.size() == 2:
		var mirror := true
		for rank in unique_ranks:
			if int(rank_counts[rank]) != 2:
				mirror = false
				break
			var rank_elements: Array[int] = []
			for raw_card in cards:
				if oracle_card_rank(int(raw_card)) == rank:
					rank_elements.append(oracle_card_element(int(raw_card)))
			if not rank_elements.has(0) or not rank_elements.has(1):
				mirror = false
				break
		if mirror:
			return [4, unique_ranks[-1], unique_ranks[0]]

	if consecutive:
		return [3, unique_ranks[-1]]

	if repeated_ranks.size() == 2:
		return [2, repeated_ranks[0], repeated_ranks[1], total]
	if repeated_ranks.size() == 1:
		var echo_score: Array = [1, repeated_ranks[0], total]
		echo_score.append_array(descending)
		return echo_score

	var micro_score: Array = [0, total]
	micro_score.append_array(descending)
	return micro_score


func _oracle_reading_text(score: Array) -> String:
	if score.is_empty():
		return "尚未成象。"
	var category := int(score[0])
	return "%s：%s。" % [ORACLE_PATTERN_NAMES[category], ORACLE_PATTERN_RULES[category]]


func _oracle_current_strength(private_cards: Array, public_cards: Array) -> float:
	if public_cards.size() >= 2:
		var reading := oracle_best_reading(private_cards, public_cards)
		var category := int(reading["score"][0])
		return clampf(float(category) / 8.0 + float(reading["score"][1]) * 0.015, 0.0, 1.0)
	var first := int(private_cards[0])
	var second := int(private_cards[1])
	var result := float(oracle_card_rank(first) + oracle_card_rank(second)) / 24.0
	if oracle_card_element(first) == oracle_card_element(second) and oracle_card_rank(first) == oracle_card_rank(second):
		result += 0.35
	elif oracle_card_rank(first) == oracle_card_rank(second):
		result += 0.16
	return clampf(result, 0.0, 1.0)


func _compare_scores(a: Array, b: Array) -> int:
	var count := mini(a.size(), b.size())
	for index in range(count):
		if int(a[index]) > int(b[index]):
			return 1
		if int(a[index]) < int(b[index]):
			return -1
	return 0


func oracle_record_file_path() -> String:
	return ProjectSettings.globalize_path(oracle_record_relative_path)


func _oracle_cards_for_record(cards: Array) -> Array:
	var result: Array = []
	for raw_card in cards:
		var card := int(raw_card)
		result.append({
			"id": card,
			"text": oracle_card_text(card),
			"element": "水" if oracle_card_element(card) == 0 else "火",
			"rank": oracle_card_rank(card),
			"name": oracle_card_name(card)
		})
	return result


func _oracle_opponents_for_record(include_hidden_hands: bool) -> Array:
	var result: Array = []
	for index in range(ORACLE_OPPONENTS.size()):
		var entry := {
			"index": index,
			"name": str(ORACLE_OPPONENTS[index]["name"]),
			"style": str(ORACLE_OPPONENTS[index]["style"]),
			"session_wallet": poker_npc_available(index),
			"brought": int(poker_npc_brought[index]) if index < poker_npc_brought.size() else 0,
			"present": bool(poker_npc_present[index]) if index < poker_npc_present.size() else true,
			"active": bool(poker.get("active", [true, true, true, true, true])[index]),
			"stack": int(poker.get("opponent_stacks", [80, 80, 80, 80, 80])[index]),
			"round_commit": int(poker.get("opponent_round_commits", [0, 0, 0, 0, 0])[index]),
			"hand_commit": int(poker.get("opponent_hand_commits", [0, 0, 0, 0, 0])[index]),
			"action": str(poker.get("opponent_actions", ["等待", "等待", "等待", "等待", "等待"])[index])
		}
		if include_hidden_hands and not poker.is_empty():
			var hand: Array = poker["opponent_hands"][index]
			entry["hand"] = _oracle_cards_for_record(hand)
			if poker.get("community", []).size() >= 2:
				var reading := oracle_best_reading(hand, poker["community"])
				entry["reading_name"] = str(reading["name"])
				entry["reading_score"] = reading["score"].duplicate()
		result.append(entry)
	return result


func _append_oracle_event(event_type: String, data: Dictionary = {}) -> void:
	if not recording_enabled or poker.is_empty():
		return
	var payload := {
		"timestamp": Time.get_datetime_string_from_system(),
		"timestamp_unix_ms": int(Time.get_unix_time_from_system() * 1000.0),
		"hand_id": str(poker.get("hand_id", "")),
		"event": event_type,
		"day": day,
		"tide": tide
	}
	payload.merge(data, true)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://play_records"))
	var relative_path := oracle_record_relative_path
	var file: FileAccess
	if FileAccess.file_exists(relative_path):
		file = FileAccess.open(relative_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(relative_path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入命运牌会记录：%s" % oracle_record_file_path())
		return
	file.store_line(JSON.stringify(payload))
	file.close()


func _load_recent_oracle_records() -> void:
	recent_oracle_records.clear()
	var relative_path := oracle_record_relative_path
	if not FileAccess.file_exists(relative_path):
		return
	var file := FileAccess.open(relative_path, FileAccess.READ)
	if file == null:
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty():
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary and str(parsed.get("event", "")) == "hand_end":
			recent_oracle_records.push_front(parsed)
			if recent_oracle_records.size() > 20:
				recent_oracle_records.resize(20)
	file.close()


func _shuffle(array: Array) -> void:
	for index in range(array.size() - 1, 0, -1):
		var target := rng.randi_range(0, index)
		var temp = array[index]
		array[index] = array[target]
		array[target] = temp


func _notice(text: String) -> void:
	notice.emit(text)
