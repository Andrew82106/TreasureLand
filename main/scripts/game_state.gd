extends RefCounted
class_name GameState

signal changed
signal notice(text: String)
signal time_boundary(kind: String, data: Dictionary)

const SynthesisCatalog = preload("res://scripts/synthesis_catalog.gd")
const FishCatalog = preload("res://scripts/fish_catalog.gd")
const NpcCatalog = preload("res://scripts/npc_catalog.gd")
const ITEMS := SynthesisCatalog.ITEMS
const RECIPES := SynthesisCatalog.RECIPES
const FISH_SPECIES := FishCatalog.SPECIES
const DIVE_AREAS := FishCatalog.AREAS
const NPCS := NpcCatalog.CORE
const ENVIRONMENT_RESIDENTS := NpcCatalog.RESIDENTS

const INITIAL_DISCOVERIES := ["water", "fire", "earth"]
const MAX_SYNTHESIS_TIER := 4
const SYNTHESIS_COST_BY_TIER := [2, 5, 12]
const SHOP_OFFERS := [
	{"id": "recipe_hint", "name": "配方方向线索", "type": "hint", "price": 12, "art": "cloud", "description": "公开一个已知万物、目标阶层和关系语法，不直接揭晓答案。"},
	{"id": "experiment_discount", "name": "三次实验折扣", "type": "discount", "price": 24, "art": "energy", "uses": 3, "cap": 6, "description": "接下来三次新组合实验费减半，向上取整。"}
]
const RACE_AIDS := {
	"rain": {"name": "雨势推演", "fee": 4, "description": "比较当前天气对所选逐风兽的修正与全场适应排名。"},
	"thunderstorm": {"name": "雷暴听兆", "fee": 5, "description": "显示所选逐风兽的赛中波动与全场波动排名。"},
	"water_jar": {"name": "补水观察", "fee": 6, "description": "比较所选逐风兽的耐力、稳定与巡航能力。"},
	"river": {"name": "河势比照", "fee": 8, "description": "比较所选逐风兽在地形段的基础表现与场内排名。"}
}
const TOWER_FLOORS := [
	{"id": "tidefire_base", "name": "潮火基座", "need": 3, "description": "完成全部3条二阶关系"},
	{"id": "cloudmud_gallery", "name": "云泥回廊", "need": 14, "description": "累计完成14条关系，发现全部三阶万物"},
	{"id": "living_workshop", "name": "众生工坊", "need": 34, "description": "累计完成34条关系，至少发现20种四阶万物"},
	{"id": "fourfold_observatory", "name": "四象观台", "need": 69, "description": "完成69条关系与72种永久万物"}
]

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
const TIME_SPEED_SECONDS := {"紧凑": 90.0, "标准": 120.0, "悠闲": 150.0}
const TIME_STATE_WORLD := "world_active"
const TIME_STATE_UI := "ui_paused"
const TIME_STATE_ACTIVITY := "activity_snapshot"
const TIME_STATE_FAST_FORWARD := "fast_forward"
const TIME_STATE_DAY_END := "day_end_hold"
const SAVE_VERSION := 3
const MANUAL_SAVE_PATH := "user://saves/manual_save.json"
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
const ORACLE_NPC_IDS := ["old_joe", "shopkeeper", "mia", "granny", "luosha"]

var cash: int = 120
var locked_principal: int = 0
var day: int = 1
var tide: int = 1
var tide_progress: float = 0.0
var time_speed_mode: String = "标准"
var time_state: String = TIME_STATE_WORLD
var time_pause_reasons := {}
var day_end_pending: bool = false
var weather: String = "晴"
var wind_direction: String = "侧风"
var daily_seed: int = 20260713
var daily_schedule := {}
var time_event_log: Array = []
var discovered := {
	"water": true, "fire": true, "earth": true
}
var discovery_records := {}
var tower_milestones := {}
var attempted_pairs := {}
var recent_synthesis_pairs: Array[String] = []
var synthesis_discount_uses: int = 0
var last_shop_hint: String = ""
var last_shop_hint_key: String = ""
var relationships := {"granny": 10, "old_joe": 0, "aqiu": 0, "mia": 0, "milo": 0, "shopkeeper": 0}
var memories := {}
var known_npcs := {"granny": true}
var npc_topic_reads := {}
var npc_request_states := {}
var npc_shared_creations := {}
var npc_shared_fish := {}
var npc_deep_talk_days := {}
var npc_talk_counts := {}
var npc_memory_rewarded := {}
var free_race_ticket: int = 1
var fishing_attempts_today: int = 0
var dive_windows_remaining: int = DAILY_FISHING_LIMIT
var dive_scene_seed: int = 0
var dive_active: bool = false
var dive_state := {}
var dive_sequence: int = 0
var fish_catch_sequence: int = 0
var fish_catch_inventory: Array = []
var marine_discoveries := {}
var marine_size_records := {}
var fish_market_quotes := {}
var fish_market_stock := {}
var fish_market_demand := {}
var fish_market_reasons := {}
var fish_market_orders: Array = []
var fish_market_history: Array = []
var fish_market_transactions: Array = []
var fish_market_refresh_index: int = 0
var fish_sale_sequence: int = 0
var pending_fish_sales := {}
var processed_fish_sales := {}
var dive_equipment := {"oxygen": 50.0, "basket": 4, "swim_speed": 1.0, "preservation_days": 0}
var last_dive_result := {}
var poker_completed: bool = false
var normal_poker_completed: bool = false
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
	_initialize_npc_state()
	_initialize_discovery_records()
	_sync_tower_milestones(false)
	_generate_daily_schedule()
	_initialize_fish_market()
	_load_recent_oracle_records()
	_record_wealth("来到万物之岛", true)


func can_save_game() -> bool:
	return not poker_session_active and not dive_active and locked_principal == 0


func build_save_data(world_state: Dictionary = {}) -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"state": {
			"cash": cash,
			"locked_principal": locked_principal,
			"day": day,
			"tide": tide,
			"tide_progress": tide_progress,
			"time_speed_mode": time_speed_mode,
			"time_state": time_state,
			"time_pause_reasons": time_pause_reasons.duplicate(true),
			"day_end_pending": day_end_pending,
			"weather": weather,
			"wind_direction": wind_direction,
			"daily_seed": daily_seed,
			"daily_schedule": daily_schedule.duplicate(true),
			"time_event_log": time_event_log.duplicate(true),
			"rng_seed": str(rng.seed),
			"rng_state": str(rng.state),
			"discovered": discovered.duplicate(true),
			"discovery_records": discovery_records.duplicate(true),
			"tower_milestones": tower_milestones.duplicate(true),
			"attempted_pairs": attempted_pairs.duplicate(true),
			"recent_synthesis_pairs": recent_synthesis_pairs.duplicate(),
			"synthesis_discount_uses": synthesis_discount_uses,
			"last_shop_hint": last_shop_hint,
			"last_shop_hint_key": last_shop_hint_key,
			"relationships": relationships.duplicate(true),
			"memories": memories.duplicate(true),
			"known_npcs": known_npcs.duplicate(true),
			"npc_topic_reads": npc_topic_reads.duplicate(true),
			"npc_request_states": npc_request_states.duplicate(true),
			"npc_shared_creations": npc_shared_creations.duplicate(true),
			"npc_shared_fish": npc_shared_fish.duplicate(true),
			"npc_deep_talk_days": npc_deep_talk_days.duplicate(true),
			"npc_talk_counts": npc_talk_counts.duplicate(true),
			"npc_memory_rewarded": npc_memory_rewarded.duplicate(true),
			"free_race_ticket": free_race_ticket,
			"fishing_attempts_today": fishing_attempts_today,
			"dive_windows_remaining": dive_windows_remaining,
			"dive_scene_seed": str(dive_scene_seed),
			"dive_active": dive_active,
			"dive_state": dive_state.duplicate(true),
			"dive_sequence": dive_sequence,
			"fish_catch_sequence": fish_catch_sequence,
			"fish_catch_inventory": fish_catch_inventory.duplicate(true),
			"marine_discoveries": marine_discoveries.duplicate(true),
			"marine_size_records": marine_size_records.duplicate(true),
			"fish_market_quotes": fish_market_quotes.duplicate(true),
			"fish_market_stock": fish_market_stock.duplicate(true),
			"fish_market_demand": fish_market_demand.duplicate(true),
			"fish_market_reasons": fish_market_reasons.duplicate(true),
			"fish_market_orders": fish_market_orders.duplicate(true),
			"fish_market_history": fish_market_history.duplicate(true),
			"fish_market_transactions": fish_market_transactions.duplicate(true),
			"fish_market_refresh_index": fish_market_refresh_index,
			"fish_sale_sequence": fish_sale_sequence,
			"processed_fish_sales": processed_fish_sales.duplicate(true),
			"dive_equipment": dive_equipment.duplicate(true),
			"last_dive_result": last_dive_result.duplicate(true),
			"poker_completed": poker_completed,
			"normal_poker_completed": normal_poker_completed,
			"aqiu_request_active": aqiu_request_active,
			"aqiu_request_done": aqiu_request_done,
			"ultimate_created": ultimate_created,
			"poker_dealer_seat": poker_dealer_seat,
			"poker_npc_wallets": poker_npc_wallets.duplicate(true),
			"poker_npc_brought": poker_npc_brought.duplicate(true),
			"poker_npc_present": poker_npc_present.duplicate(true),
			"wealth_history": wealth_history.duplicate(true)
		},
		"world": world_state.duplicate(true)
	}


func save_game(path: String = MANUAL_SAVE_PATH, world_state: Dictionary = {}, allow_activity_snapshot: bool = false) -> Dictionary:
	if not allow_activity_snapshot and not can_save_game():
		return {"ok": false, "text": "当前活动仍有金贝或牌局状态未结算，暂时不能存档。"}
	var absolute_directory := ProjectSettings.globalize_path(path.get_base_dir())
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK:
		return {"ok": false, "text": "无法创建存档目录。", "error": directory_error}
	var temporary_path := path + ".tmp"
	var backup_path := path + ".bak"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "text": "无法写入存档。", "error": FileAccess.get_open_error()}
	file.store_string(JSON.stringify(build_save_data(world_state), "\t"))
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(absolute_backup)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary)
			return {"ok": false, "text": "无法轮换旧存档，原存档未被修改。", "error": backup_error}
	var install_error := DirAccess.rename_absolute(absolute_temporary, absolute_path)
	if install_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(absolute_backup, absolute_path)
		return {"ok": false, "text": "无法完成存档写入，已尝试恢复旧存档。", "error": install_error}
	return {"ok": true, "path": path, "text": "进度已保存。"}


func save_auto_game(world_state: Dictionary = {}) -> Dictionary:
	var path := "user://saves/autosave_day_%03d.json" % day
	var result := save_game(path, world_state)
	if bool(result.get("ok", false)):
		var expired_path := "user://saves/autosave_day_%03d.json" % (day - 7)
		if day > 7 and FileAccess.file_exists(expired_path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(expired_path))
	return result


func load_game(path: String = MANUAL_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "text": "还没有可读取的存档。"}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "text": "无法读取存档。", "error": FileAccess.get_open_error()}
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		return {"ok": false, "text": "存档内容损坏，未修改当前进度。"}
	var restored := restore_save_data(parsed)
	if not bool(restored.get("ok", false)):
		return restored
	restored["path"] = path
	restored["world"] = parsed.get("world", {}).duplicate(true)
	return restored


func restore_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_save_data(data)
	if not bool(validation.get("ok", false)):
		return validation
	var version := int(data.get("version", 0))
	var saved: Dictionary = data["state"]
	var saved_speed := str(saved.get("time_speed_mode", "标准"))
	if not TIME_SPEED_SECONDS.has(saved_speed):
		saved_speed = "标准"
	cash = maxi(0, int(saved.get("cash", 120)))
	locked_principal = 0
	day = maxi(1, int(saved.get("day", 1)))
	tide = clampi(int(saved.get("tide", 1)), 1, 16)
	tide_progress = clampf(float(saved.get("tide_progress", 0.0)), 0.0, 0.999999)
	time_speed_mode = saved_speed
	day_end_pending = bool(saved.get("day_end_pending", false))
	weather = str(saved.get("weather", "晴"))
	wind_direction = str(saved.get("wind_direction", "侧风"))
	daily_seed = int(saved.get("daily_seed", 20260713))
	daily_schedule = saved.get("daily_schedule", {}).duplicate(true)
	time_event_log = saved.get("time_event_log", []).duplicate(true)
	rng.seed = int(str(saved.get("rng_seed", "20260713")))
	rng.state = int(str(saved.get("rng_state", str(rng.state))))
	discovered = saved.get("discovered", {}).duplicate(true)
	for root_id in INITIAL_DISCOVERIES:
		discovered[root_id] = true
	discovery_records = saved.get("discovery_records", {}).duplicate(true)
	tower_milestones = saved.get("tower_milestones", {}).duplicate(true)
	attempted_pairs = saved.get("attempted_pairs", {}).duplicate(true)
	recent_synthesis_pairs.clear()
	for raw_key in saved.get("recent_synthesis_pairs", []):
		var pair_key := str(raw_key)
		if not recent_synthesis_pairs.has(pair_key):
			recent_synthesis_pairs.append(pair_key)
	while recent_synthesis_pairs.size() > 8:
		recent_synthesis_pairs.pop_back()
	synthesis_discount_uses = clampi(int(saved.get("synthesis_discount_uses", 0)), 0, 6)
	last_shop_hint = str(saved.get("last_shop_hint", ""))
	last_shop_hint_key = str(saved.get("last_shop_hint_key", ""))
	relationships = saved.get("relationships", {}).duplicate(true)
	memories = saved.get("memories", {}).duplicate(true)
	known_npcs = saved.get("known_npcs", {"granny": true}).duplicate(true)
	npc_topic_reads = saved.get("npc_topic_reads", {}).duplicate(true)
	npc_request_states = saved.get("npc_request_states", {}).duplicate(true)
	npc_shared_creations = saved.get("npc_shared_creations", {}).duplicate(true)
	npc_shared_fish = saved.get("npc_shared_fish", {}).duplicate(true)
	npc_deep_talk_days = saved.get("npc_deep_talk_days", {}).duplicate(true)
	npc_talk_counts = saved.get("npc_talk_counts", {}).duplicate(true)
	npc_memory_rewarded = saved.get("npc_memory_rewarded", {}).duplicate(true)
	free_race_ticket = maxi(0, int(saved.get("free_race_ticket", 0)))
	fishing_attempts_today = clampi(int(saved.get("fishing_attempts_today", 0)), 0, DAILY_FISHING_LIMIT)
	dive_windows_remaining = clampi(int(saved.get("dive_windows_remaining", DAILY_FISHING_LIMIT - fishing_attempts_today)), 0, DAILY_FISHING_LIMIT)
	fishing_attempts_today = DAILY_FISHING_LIMIT - dive_windows_remaining
	dive_scene_seed = int(str(saved.get("dive_scene_seed", "0")))
	dive_active = bool(saved.get("dive_active", false))
	dive_state = saved.get("dive_state", {}).duplicate(true)
	dive_sequence = maxi(0, int(saved.get("dive_sequence", 0)))
	fish_catch_sequence = maxi(0, int(saved.get("fish_catch_sequence", 0)))
	fish_catch_inventory = saved.get("fish_catch_inventory", []).duplicate(true)
	marine_discoveries = saved.get("marine_discoveries", {}).duplicate(true)
	marine_size_records = saved.get("marine_size_records", {}).duplicate(true)
	fish_market_quotes = saved.get("fish_market_quotes", {}).duplicate(true)
	fish_market_stock = saved.get("fish_market_stock", {}).duplicate(true)
	fish_market_demand = saved.get("fish_market_demand", {}).duplicate(true)
	fish_market_reasons = saved.get("fish_market_reasons", {}).duplicate(true)
	fish_market_orders = saved.get("fish_market_orders", []).duplicate(true)
	fish_market_history = saved.get("fish_market_history", []).duplicate(true)
	fish_market_transactions = saved.get("fish_market_transactions", []).duplicate(true)
	fish_market_refresh_index = maxi(0, int(saved.get("fish_market_refresh_index", 0)))
	fish_sale_sequence = maxi(0, int(saved.get("fish_sale_sequence", 0)))
	processed_fish_sales = saved.get("processed_fish_sales", {}).duplicate(true)
	pending_fish_sales.clear()
	dive_equipment = saved.get("dive_equipment", {"oxygen": 50.0, "basket": 4, "swim_speed": 1.0, "preservation_days": 0}).duplicate(true)
	last_dive_result = saved.get("last_dive_result", {}).duplicate(true)
	poker_completed = bool(saved.get("poker_completed", false))
	normal_poker_completed = bool(saved.get("normal_poker_completed", false))
	if not saved.has("normal_poker_completed"):
		for raw_record in recent_oracle_records:
			if raw_record is Dictionary and not bool(raw_record.get("tutorial", false)):
				normal_poker_completed = true
				break
	aqiu_request_active = bool(saved.get("aqiu_request_active", false))
	aqiu_request_done = bool(saved.get("aqiu_request_done", false))
	_initialize_npc_state()
	_initialize_discovery_records()
	_sync_tower_milestones(false)
	ultimate_created = bool(saved.get("ultimate_created", false))
	if bool(tower_milestones.get("fourfold_observatory", false)):
		ultimate_created = true
	poker_dealer_seat = int(saved.get("poker_dealer_seat", -1))
	poker_npc_wallets = saved.get("poker_npc_wallets", []).duplicate(true)
	poker_npc_brought = saved.get("poker_npc_brought", []).duplicate(true)
	poker_npc_present = saved.get("poker_npc_present", []).duplicate(true)
	wealth_history = saved.get("wealth_history", []).duplicate(true)
	if wealth_history.is_empty():
		_record_wealth("读取旧存档", true)
	poker.clear()
	poker_session_active = false
	poker_session_time_charged = false
	time_pause_reasons.clear()
	if daily_schedule.is_empty():
		_generate_daily_schedule()
	if fish_market_quotes.is_empty():
		_initialize_fish_market()
	time_state = TIME_STATE_DAY_END if day_end_pending else TIME_STATE_WORLD
	changed.emit()
	return {"ok": true, "text": "存档已读取。", "version": version}


func _validate_save_data(data: Dictionary) -> Dictionary:
	var version := int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		return {"ok": false, "text": "存档版本不受支持，未修改当前进度。"}
	if not data.get("state", {}) is Dictionary or not data.get("world", {}) is Dictionary:
		return {"ok": false, "text": "存档结构损坏，未修改当前进度。"}
	var saved: Dictionary = data["state"]
	for key in ["daily_schedule", "discovered", "discovery_records", "tower_milestones", "attempted_pairs", "relationships", "memories", "known_npcs", "npc_topic_reads", "npc_request_states", "npc_shared_creations", "npc_shared_fish", "npc_deep_talk_days", "npc_talk_counts", "npc_memory_rewarded", "dive_state", "marine_discoveries", "marine_size_records", "fish_market_quotes", "fish_market_stock", "fish_market_demand", "fish_market_reasons", "processed_fish_sales", "dive_equipment", "last_dive_result"]:
		if saved.has(key) and not saved[key] is Dictionary:
			return {"ok": false, "text": "存档字段%s损坏，未修改当前进度。" % key}
	for key in ["time_event_log", "recent_synthesis_pairs", "wealth_history", "poker_npc_wallets", "poker_npc_brought", "poker_npc_present", "fish_catch_inventory", "fish_market_orders", "fish_market_history", "fish_market_transactions"]:
		if saved.has(key) and not saved[key] is Array:
			return {"ok": false, "text": "存档字段%s损坏，未修改当前进度。" % key}
	return {"ok": true}


func item_name(item_id: String) -> String:
	if not ITEMS.has(item_id):
		return item_id
	return str(ITEMS[item_id]["name"])


func account_wealth() -> int:
	return cash + locked_principal


func asset_liquidation_value() -> int:
	return fish_inventory_value()


func net_worth() -> int:
	return account_wealth() + asset_liquidation_value()


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
	return clampi(dive_windows_remaining, 0, DAILY_FISHING_LIMIT)


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


func seconds_per_tide() -> float:
	return float(TIME_SPEED_SECONDS.get(time_speed_mode, 120.0))


func set_time_speed_mode(mode: String) -> bool:
	if not TIME_SPEED_SECONDS.has(mode):
		return false
	if time_speed_mode == mode:
		return true
	time_speed_mode = mode
	changed.emit()
	return true


func set_time_pause(reason: String, active: bool, requested_state: String = TIME_STATE_UI) -> void:
	if active:
		time_pause_reasons[reason] = requested_state
	else:
		time_pause_reasons.erase(reason)
	_recompute_time_state()


func _recompute_time_state() -> void:
	var next_state := TIME_STATE_WORLD
	if day_end_pending:
		next_state = TIME_STATE_DAY_END
	elif time_pause_reasons.values().has(TIME_STATE_ACTIVITY):
		next_state = TIME_STATE_ACTIVITY
	elif time_pause_reasons.values().has(TIME_STATE_FAST_FORWARD):
		next_state = TIME_STATE_FAST_FORWARD
	elif not time_pause_reasons.is_empty():
		next_state = TIME_STATE_UI
	if next_state == time_state:
		return
	time_state = next_state
	changed.emit()


func world_clock_running() -> bool:
	return time_state == TIME_STATE_WORLD and not day_end_pending


func time_state_label() -> String:
	return {
		TIME_STATE_WORLD: "世界流动",
		TIME_STATE_UI: "界面停表",
		TIME_STATE_ACTIVITY: "活动快照",
		TIME_STATE_FAST_FORWARD: "等待推进",
		TIME_STATE_DAY_END: "日终停驻"
	}.get(time_state, "世界流动")


func advance_world_delta(delta_seconds: float) -> bool:
	if delta_seconds <= 0.0 or not world_clock_running():
		return false
	return advance_time_fraction(delta_seconds / seconds_per_tide(), "自然流逝")


func advance_time(amount: int) -> void:
	advance_time_fraction(float(amount), "固定活动")


func fast_forward_time(amount: float, source: String = "主动等待") -> bool:
	if amount <= 0.0 or day_end_pending:
		return false
	set_time_pause("fast_forward", true, TIME_STATE_FAST_FORWARD)
	var advanced := advance_time_fraction(amount, source)
	set_time_pause("fast_forward", false)
	return advanced


func advance_time_fraction(amount: float, source: String = "固定活动") -> bool:
	if amount <= 0.0 or day_end_pending:
		return false
	var remaining := amount
	var advanced := false
	var crossed_boundary := false
	while remaining > 0.000001 and not day_end_pending:
		var available := 1.0 - tide_progress
		var step := minf(remaining, available)
		tide_progress += step
		remaining -= step
		advanced = advanced or step > 0.0
		if tide_progress >= 0.999999:
			tide_progress = 0.0
			crossed_boundary = true
			if tide >= 16:
				day_end_pending = true
				time_state = TIME_STATE_DAY_END
				_record_time_event("day_end", source)
				time_boundary.emit("day_end", {"day": day, "tide": tide, "source": source})
				break
			var old_phase := phase_name()
			tide += 1
			_record_time_event("tide", source)
			time_boundary.emit("tide", {"day": day, "tide": tide, "source": source})
			if phase_name() != old_phase:
				_record_time_event("phase", source)
				_refresh_fish_market("时段边界")
				time_boundary.emit("phase", {"day": day, "tide": tide, "phase": phase_name(), "source": source})
	if crossed_boundary:
		changed.emit()
	return advanced


func _record_time_event(kind: String, source: String) -> void:
	time_event_log.append({
		"kind": kind,
		"day": day,
		"tide": tide,
		"progress": tide_progress,
		"phase": phase_name(),
		"source": source
	})
	while time_event_log.size() > 64:
		time_event_log.pop_front()


func sleep_to_next_day() -> void:
	day += 1
	tide = 1
	tide_progress = 0.0
	day_end_pending = false
	time_pause_reasons.clear()
	time_state = TIME_STATE_WORLD
	refresh_day()
	_record_wealth("第%d天开始" % day, true)
	changed.emit()
	_notice("新的一天开始了。商店、天气和赛事已经刷新。")


func refresh_day() -> void:
	fishing_attempts_today = 0
	dive_windows_remaining = DAILY_FISHING_LIMIT
	dive_active = false
	dive_state.clear()
	dive_scene_seed = 0
	daily_seed = int(rng.randi())
	var day_rng := RandomNumberGenerator.new()
	day_rng.seed = daily_seed
	var weathers := ["晴", "阵雨", "强风"]
	var winds := ["顺风", "侧风", "逆风"]
	weather = weathers[day_rng.randi_range(0, weathers.size() - 1)]
	wind_direction = winds[day_rng.randi_range(0, winds.size() - 1)]
	_generate_daily_schedule()
	_initialize_fish_market()
	changed.emit()


func _initialize_npc_state() -> void:
	for npc_id in NpcCatalog.core_ids():
		relationships[npc_id] = clampi(int(relationships.get(npc_id, 0)), -100, 100)
		if not known_npcs.has(npc_id):
			known_npcs[npc_id] = false
		var raw_memory = memories.get(npc_id, {})
		if raw_memory is Array:
			var migrated_recent: Array = []
			for index in range(raw_memory.size()):
				migrated_recent.append({
					"memory_id": "legacy_%s_%d" % [npc_id, index],
					"type": "legacy",
					"importance": 1,
					"created_day": day,
					"created_tide": tide,
					"summary": str(raw_memory[index]),
					"relationship_delta": 0,
					"effects": {},
					"occurrences": 1
				})
			memories[npc_id] = {"recent": migrated_recent, "long": []}
		elif raw_memory is Dictionary:
			var store: Dictionary = raw_memory
			var recent = store.get("recent", [])
			var long_term = store.get("long", [])
			memories[npc_id] = {
				"recent": recent.duplicate(true) if recent is Array else [],
				"long": long_term.duplicate(true) if long_term is Array else []
			}
		else:
			memories[npc_id] = {"recent": [], "long": []}
		if not npc_request_states.has(npc_id) or not npc_request_states[npc_id] is Dictionary:
			npc_request_states[npc_id] = {"state": "available", "accepted_day": 0, "completed_day": 0}
	known_npcs["granny"] = true
	var aqiu_state: Dictionary = npc_request_states.get("aqiu", {})
	if aqiu_request_done:
		aqiu_state["state"] = "completed"
	elif aqiu_request_active:
		aqiu_state["state"] = "active"
	elif str(aqiu_state.get("state", "")) == "completed":
		aqiu_request_done = true
	elif str(aqiu_state.get("state", "")) == "active":
		aqiu_request_active = true
	npc_request_states["aqiu"] = aqiu_state


func _generate_daily_schedule() -> void:
	var npc_locations := {}
	var npc_schedule := {}
	for npc_id in NpcCatalog.core_ids():
		var locations := {}
		var records := {}
		for phase in NpcCatalog.PHASES:
			var entry := NpcCatalog.schedule_entry(npc_id, phase)
			locations[phase] = str(entry.get("location", "未知区域"))
			records[phase] = entry
		npc_locations[npc_id] = locations
		npc_schedule[npc_id] = records
	daily_schedule = {
		"day": day,
		"seed": daily_seed,
		"weather": weather,
		"wind": wind_direction,
		"npc_locations": npc_locations,
		"npc_schedule": npc_schedule,
		"regular_race_tides": [3, 7, 11, 15],
		"fish_market_refresh_tides": [1, 5, 9, 13]
	}


func npc_profile(npc_id: String) -> Dictionary:
	return NpcCatalog.core_profile(npc_id)


func meet_npc(npc_id: String) -> bool:
	if not NPCS.has(npc_id):
		return false
	var first_meeting := not bool(known_npcs.get(npc_id, false))
	known_npcs[npc_id] = true
	if first_meeting:
		add_npc_memory(npc_id, {
			"memory_id": "first_meeting",
			"type": "meeting",
			"importance": 2,
			"summary": "你们在%s第一次正式交谈。" % npc_location(npc_id),
			"relationship_delta": 0,
			"effects": {"dialogue_warmth": 1}
		})
		changed.emit()
	return first_meeting


func npc_schedule_entry(npc_id: String, phase: String = "") -> Dictionary:
	var current_phase := phase_name() if phase.is_empty() else phase
	var entry := NpcCatalog.schedule_entry(npc_id, current_phase)
	if entry.is_empty():
		return {"available": false, "area": "", "location": "未知区域", "activity": "行踪不明"}
	var available := bool(entry.get("available", true))
	if str(entry.get("requires", "")) == "complete_poker" and not normal_poker_completed:
		available = false
	entry["available"] = available
	return entry


func npc_location(npc_id: String) -> String:
	return str(npc_schedule_entry(npc_id).get("location", "未知区域"))


func npc_is_available(npc_id: String) -> bool:
	return bool(npc_schedule_entry(npc_id).get("available", false))


func npc_map_entries() -> Array:
	var result: Array = []
	for npc_id in NpcCatalog.core_ids():
		if not bool(known_npcs.get(npc_id, false)):
			continue
		var profile := npc_profile(npc_id)
		var schedule := npc_schedule_entry(npc_id)
		result.append({
			"id": npc_id,
			"name": str(profile.get("name", npc_id)),
			"color": Color(str(profile.get("color", "ffffff"))),
			"area": str(schedule.get("area", "")),
			"location": str(schedule.get("location", "未知区域")),
			"activity": str(schedule.get("activity", "")),
			"position": schedule.get("position", Vector2.ZERO),
			"available": bool(schedule.get("available", false)),
			"substitute": str(schedule.get("substitute", ""))
		})
	return result


func environment_resident_entries() -> Array:
	var result: Array = []
	for raw_profile in ENVIRONMENT_RESIDENTS:
		var profile: Dictionary = raw_profile
		var resident_id := str(profile.get("id", ""))
		var schedule := NpcCatalog.resident_schedule(resident_id, phase_name())
		result.append({
			"id": resident_id,
			"name": str(profile.get("name", resident_id)),
			"role": str(profile.get("role", "岛民")),
			"color": Color(str(profile.get("color", "9bb8b8"))),
			"dialogue": str(profile.get("dialogue", "")),
			"area": str(schedule.get("area", "")),
			"location": str(schedule.get("location", "")),
			"position": schedule.get("position", Vector2.ZERO),
			"available": bool(schedule.get("available", true))
		})
	return result


func _initialize_discovery_records() -> void:
	for root_id in INITIAL_DISCOVERIES:
		if not discovery_records.has(root_id) or not discovery_records[root_id] is Dictionary:
			discovery_records[root_id] = {
				"item_id": root_id,
				"first_source": "initial",
				"first_day": 1,
				"first_tide": 1,
				"inputs": [],
				"relation": "根万物",
				"logic": "上岛时已经掌握的世界根源。"
			}
	for raw_id in discovered.keys():
		var item_id := str(raw_id)
		if not bool(discovered.get(item_id, false)) or not ITEMS.has(item_id):
			continue
		if discovery_records.has(item_id) and discovery_records[item_id] is Dictionary:
			var existing: Dictionary = discovery_records[item_id]
			existing["item_id"] = item_id
			existing["first_source"] = str(existing.get("first_source", "legacy"))
			existing["first_day"] = maxi(1, int(existing.get("first_day", 1)))
			existing["first_tide"] = clampi(int(existing.get("first_tide", 1)), 1, 16)
			existing["inputs"] = existing.get("inputs", []).duplicate() if existing.get("inputs", []) is Array else []
			existing["relation"] = str(existing.get("relation", ""))
			existing["logic"] = str(existing.get("logic", item_description(item_id)))
			discovery_records[item_id] = existing
			continue
		var recipe := _recipe_for_output(item_id)
		var pair_record: Dictionary = {}
		if not recipe.is_empty():
			var inputs: Array = recipe.get("inputs", [])
			if inputs.size() == 2:
				pair_record = attempted_pairs.get(synthesis_pair_key(str(inputs[0]), str(inputs[1])), {})
		discovery_records[item_id] = {
			"item_id": item_id,
			"first_source": "synthesis" if not recipe.is_empty() else "legacy",
			"first_day": maxi(1, int(pair_record.get("day", 1))),
			"first_tide": clampi(int(pair_record.get("tide", 1)), 1, 16),
			"inputs": recipe.get("inputs", []).duplicate() if not recipe.is_empty() else [],
			"relation": str(recipe.get("relation", "旧版本迁移")),
			"logic": str(recipe.get("logic", item_description(item_id)))
		}


func _recipe_for_output(item_id: String) -> Dictionary:
	for raw_recipe in RECIPES:
		var recipe: Dictionary = raw_recipe
		if str(recipe.get("output", "")) == item_id:
			return recipe
	return {}


func discovery_record(item_id: String) -> Dictionary:
	var record = discovery_records.get(item_id, {})
	return record.duplicate(true) if record is Dictionary else {}


func discovery_source_label(item_id: String) -> String:
	var source := str(discovery_record(item_id).get("first_source", "unknown"))
	return {
		"initial": "上岛时掌握",
		"synthesis": "造化盆首次合成",
		"legacy": "旧版本进度迁移"
	}.get(source, source)


func item_verified_relation_count(item_id: String) -> int:
	var count := 0
	for raw_record in attempted_pairs.values():
		if not raw_record is Dictionary:
			continue
		var record: Dictionary = raw_record
		if str(record.get("left_id", "")) == item_id or str(record.get("right_id", "")) == item_id:
			count += 1
	return count


func item_untried_pair_count(item_id: String) -> int:
	if not is_discovered(item_id) or item_tier(item_id) >= MAX_SYNTHESIS_TIER:
		return 0
	var count := 0
	for other_id in discovered_item_ids():
		if item_tier(other_id) >= MAX_SYNTHESIS_TIER:
			continue
		if synthesis_attempt_record(item_id, other_id).is_empty():
			count += 1
	return count


func item_cross_module_uses(item_id: String) -> Array:
	if not is_discovered(item_id):
		return []
	var result: Array = []
	result.append({
		"module": "万物合成",
		"label": "继续研究关系" if item_tier(item_id) < MAX_SYNTHESIS_TIER else "四阶终点收藏",
		"detail": "%d条涉及它的组合已验证，仍有%d组已知万物配对尚未尝试。" % [item_verified_relation_count(item_id), item_untried_pair_count(item_id)]
	})
	result.append({
		"module": "万象塔",
		"label": "永久计入谱系",
		"detail": "该发现已经计入塔层点亮进度，不需要献出或消耗。"
	})
	result.append({
		"module": "人物社交",
		"label": "展示与分享方法",
		"detail": "可以向已认识的核心NPC分享；符合人物研究方向时会形成独立记忆。"
	})
	if RACE_AIDS.has(item_id):
		var aid: Dictionary = RACE_AIDS[item_id]
		result.append({
			"module": "逐风竞速",
			"label": str(aid.get("name", "赛事研读")),
			"detail": str(aid.get("description", "提供公开情报，不改变赛果。"))
		})
	var request_labels := {
		"steam": "榕奶奶委托“盆中的第一缕雾”",
		"water_jar": "阿葵委托“不会消失的补水方法”"
	}
	if request_labels.has(item_id):
		result.append({
			"module": "人物委托",
			"label": str(request_labels[item_id]),
			"detail": "委托只读取永久发现状态，交付方法不会移除万物。"
		})
	if item_tier(item_id) == 2:
		result.append({
			"module": "研究商店",
			"label": "阿拓的二阶研究委托",
			"detail": "任意二阶万物都能证明你已独立完成一条根关系。"
		})
	return result


func collection_categories() -> Array[String]:
	var result: Array[String] = []
	for raw_item in ITEMS.values():
		var item: Dictionary = raw_item
		var category := str(item.get("category", "未分类"))
		if not result.has(category):
			result.append(category)
	result.sort()
	return result


func recent_discovered_item_ids(limit: int = 8) -> Array[String]:
	var ids := discovered_item_ids()
	ids.sort_custom(func(a: String, b: String):
		var record_a := discovery_record(a)
		var record_b := discovery_record(b)
		if int(record_a.get("first_day", 1)) != int(record_b.get("first_day", 1)):
			return int(record_a.get("first_day", 1)) > int(record_b.get("first_day", 1))
		if int(record_a.get("first_tide", 1)) != int(record_b.get("first_tide", 1)):
			return int(record_a.get("first_tide", 1)) > int(record_b.get("first_tide", 1))
		if item_tier(a) != item_tier(b):
			return item_tier(a) > item_tier(b)
		return item_name(a) < item_name(b)
	)
	if ids.size() > limit:
		ids.resize(limit)
	return ids


func tower_floor_states() -> Array:
	var current := discovered_recipe_count()
	var result: Array = []
	for raw_floor in TOWER_FLOORS:
		var floor: Dictionary = raw_floor
		var entry := floor.duplicate(true)
		entry["current"] = mini(current, int(floor["need"]))
		entry["unlocked"] = current >= int(floor["need"])
		entry["remaining"] = maxi(0, int(floor["need"]) - current)
		entry["progress"] = clampf(float(current) / float(int(floor["need"])), 0.0, 1.0)
		result.append(entry)
	return result


func _sync_tower_milestones(announce: bool) -> Array[String]:
	var newly_unlocked: Array[String] = []
	var current := discovered_recipe_count()
	for raw_floor in TOWER_FLOORS:
		var floor: Dictionary = raw_floor
		var floor_id := str(floor["id"])
		var unlocked := current >= int(floor["need"])
		if not unlocked:
			tower_milestones.erase(floor_id)
			continue
		if bool(tower_milestones.get(floor_id, false)):
			continue
		tower_milestones[floor_id] = true
		newly_unlocked.append(floor_id)
		if announce:
			var summary := "你点亮了万象塔的%s：%s。" % [str(floor["name"]), str(floor["description"])]
			add_npc_memory("granny", {
				"memory_id": "tower_%s" % floor_id,
				"type": "tower_milestone",
				"importance": 5,
				"persistent": true,
				"summary": summary,
				"relationship_delta": 0,
				"effects": {"dialogue_warmth": 2, "private_topic_access": 1}
			})
			add_npc_memory("mia", {
				"memory_id": "tower_%s" % floor_id,
				"type": "tower_milestone",
				"importance": 4,
				"summary": summary,
				"relationship_delta": 0,
				"effects": {"dialogue_warmth": 1}
			})
			_notice("万象塔 · %s已经点亮。" % str(floor["name"]))
	if bool(tower_milestones.get("fourfold_observatory", false)):
		ultimate_created = true
	return newly_unlocked


func synthesis_goal() -> Dictionary:
	var current := discovered_recipe_count()
	for raw_floor in TOWER_FLOORS:
		var floor: Dictionary = raw_floor
		if current >= int(floor["need"]):
			continue
		var anchor_id := ""
		var anchor_count := -1
		for item_id in discovered_item_ids():
			var opportunity_count := available_relation_count(item_id)
			if opportunity_count > anchor_count:
				anchor_id = item_id
				anchor_count = opportunity_count
		if anchor_count <= 0:
			for item_id in discovered_item_ids():
				var pair_count := item_untried_pair_count(item_id)
				if pair_count > anchor_count:
					anchor_id = item_id
					anchor_count = pair_count
		return {
			"complete": false,
			"floor_id": str(floor["id"]),
			"title": "点亮%s" % str(floor["name"]),
			"description": str(floor["description"]),
			"current": current,
			"target": int(floor["need"]),
			"remaining": int(floor["need"]) - current,
			"anchor_id": anchor_id,
			"anchor_name": item_name(anchor_id) if not anchor_id.is_empty() else "",
			"anchor_opportunities": maxi(0, anchor_count)
		}
	return {
		"complete": true,
		"title": "四阶谱系已经完成",
		"description": "72种永久万物与69条稳定关系已经全部进入图鉴。",
		"current": current,
		"target": RECIPES.size(),
		"remaining": 0,
		"anchor_id": "",
		"anchor_name": "",
		"anchor_opportunities": 0
	}


func is_discovered(item_id: String) -> bool:
	return bool(discovered.get(item_id, false))


func discover_item(item_id: String, source: String = "world", details: Dictionary = {}) -> bool:
	if not ITEMS.has(item_id) or is_discovered(item_id):
		return false
	discovered[item_id] = true
	discovery_records[item_id] = {
		"item_id": item_id,
		"first_source": source,
		"first_day": day,
		"first_tide": tide,
		"inputs": details.get("inputs", []).duplicate() if details.get("inputs", []) is Array else [],
		"relation": str(details.get("relation", "")),
		"logic": str(details.get("logic", item_description(item_id))),
		"pair_key": str(details.get("pair_key", ""))
	}
	var tier := item_tier(item_id)
	if tier >= 2:
		for npc_id in ["granny", "shopkeeper", "mia"]:
			add_npc_memory(npc_id, {
				"memory_id": "discovered_%s" % item_id,
				"type": "synthesis_discovery",
				"importance": clampi(tier, 2, 5),
				"persistent": tier >= 4,
				"summary": "你首次发现了%d阶万物“%s”。" % [tier, item_name(item_id)],
				"relationship_delta": 0,
				"effects": {"dialogue_warmth": 1, "private_topic_access": 1 if tier >= 4 else 0}
			})
	_sync_tower_milestones(true)
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


func item_tier(item_id: String) -> int:
	return int(ITEMS.get(item_id, {}).get("tier", 0))


func item_art_source(item_id: String) -> String:
	return str(ITEMS.get(item_id, {}).get("art_source", "material"))


func item_art_index(item_id: String) -> int:
	return int(ITEMS.get(item_id, {}).get("art_index", 0))


func tier_discovery_progress(tier: int) -> Dictionary:
	var total := 0
	var found := 0
	for raw_id in ITEMS.keys():
		var item_id := str(raw_id)
		if item_tier(item_id) != tier:
			continue
		total += 1
		if is_discovered(item_id):
			found += 1
	return {"tier": tier, "found": found, "total": total, "complete": total > 0 and found == total}


func available_relation_count(item_id: String) -> int:
	if not is_discovered(item_id):
		return 0
	var count := 0
	for raw_recipe in RECIPES:
		var recipe: Dictionary = raw_recipe
		if is_discovered(str(recipe["output"])):
			continue
		var inputs: Array = recipe["inputs"]
		if not inputs.has(item_id):
			continue
		var other_id := str(inputs[1]) if str(inputs[0]) == item_id else str(inputs[0])
		if is_discovered(other_id) and synthesis_attempt_record(item_id, other_id).is_empty():
			count += 1
	return count


func synthesis_pair_key(left_id: String, right_id: String) -> String:
	var ids := [left_id, right_id]
	ids.sort()
	return "%s|%s" % [ids[0], ids[1]]


func synthesis_attempt_record(left_id: String, right_id: String) -> Dictionary:
	return attempted_pairs.get(synthesis_pair_key(left_id, right_id), {})


func can_synthesize_pair(left_id: String, right_id: String) -> bool:
	if not ITEMS.has(left_id) or not ITEMS.has(right_id):
		return false
	return maxi(item_tier(left_id), item_tier(right_id)) < MAX_SYNTHESIS_TIER


func synthesis_base_cost(left_id: String, right_id: String) -> int:
	if not can_synthesize_pair(left_id, right_id):
		return 0
	var tier := maxi(int(ITEMS[left_id].get("tier", 0)), int(ITEMS[right_id].get("tier", 0)))
	return int(SYNTHESIS_COST_BY_TIER[clampi(tier - 1, 0, SYNTHESIS_COST_BY_TIER.size() - 1)])


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
	if not can_synthesize_pair(left_id, right_id):
		return {
			"ok": false,
			"success": false,
			"terminal": true,
			"cost_paid": 0,
			"text": "四阶万物是当前谱系终点；五阶开放前不会扣款或记录这次选择。"
		}
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
		var tower_before := tower_milestones.duplicate(true)
		record["first_discovery"] = discover_item(output_id, "synthesis", {
			"inputs": [left_id, right_id],
			"relation": str(matched.get("relation", "关系")),
			"logic": str(matched.get("logic", "")),
			"pair_key": pair_key
		})
		var tower_unlocks: Array[String] = []
		for raw_floor in TOWER_FLOORS:
			var floor: Dictionary = raw_floor
			var floor_id := str(floor["id"])
			if bool(tower_milestones.get(floor_id, false)) and not bool(tower_before.get(floor_id, false)):
				tower_unlocks.append(str(floor["name"]))
		record["tower_unlocks"] = tower_unlocks
		record["category"] = str(ITEMS[output_id]["category"])
		record["tier"] = int(ITEMS[output_id]["tier"])
		record["relation"] = str(matched.get("relation", "关系"))
		record["logic"] = str(matched.get("logic", ""))
		record["collection_count"] = discovered_recipe_count()
		record["collection_total"] = RECIPES.size()
		record["new_opportunities"] = count_untried_visible_pairs()
	attempted_pairs[pair_key] = record.duplicate(true)
	recent_synthesis_pairs.erase(pair_key)
	recent_synthesis_pairs.push_front(pair_key)
	while recent_synthesis_pairs.size() > 8:
		recent_synthesis_pairs.pop_back()
	_record_wealth("万物实验 · %s + %s" % [item_name(left_id), item_name(right_id)])
	advance_time_fraction(0.25, "万物实验")
	changed.emit()
	var result := record.duplicate(true)
	result["ok"] = true
	result["time_cost"] = 0.25
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
	var count := 0
	for raw_recipe in RECIPES:
		var recipe: Dictionary = raw_recipe
		var inputs: Array = recipe["inputs"]
		var left_id := str(inputs[0])
		var right_id := str(inputs[1])
		if is_discovered(left_id) and is_discovered(right_id) and synthesis_attempt_record(left_id, right_id).is_empty():
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
		if offer_type == "discount" and synthesis_discount_uses + int(offer["uses"]) > int(offer["cap"]):
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
	if offer_type == "discount":
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
	if offer_type == "discount":
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
				"text": "阿拓的线索：%s还有一条%s关系，对方是%d阶%s类万物" % [item_name(left_id), str(recipe.get("relation", "稳定")), item_tier(right_id), str(ITEMS[right_id]["category"])]
			}
		if is_discovered(right_id):
			return {
				"pair_key": pair_key,
				"text": "阿拓的线索：%s还有一条%s关系，对方是%d阶%s类万物" % [item_name(right_id), str(recipe.get("relation", "稳定")), item_tier(left_id), str(ITEMS[left_id]["category"])]
			}
	return {}


func dive_area_unlocked(area_id: String) -> bool:
	if area_id == "sand_shallows":
		return true
	if area_id == "coral_shelf":
		return dive_sequence > 0 or not marine_discoveries.is_empty()
	if area_id == "wreck_edge":
		return marine_discoveries.size() >= 5 or is_discovered("water_jar")
	return false


func dive_area_status(area_id: String) -> Dictionary:
	if not DIVE_AREAS.has(area_id):
		return {"ok": false, "text": "未知潜捕区域。"}
	var area: Dictionary = DIVE_AREAS[area_id]
	var visibility := float(area["visibility"])
	if weather == "阵雨":
		visibility *= 0.82
	elif weather == "强风":
		visibility *= 0.68
	return {
		"ok": true,
		"id": area_id,
		"name": str(area["name"]),
		"description": str(area["description"]),
		"current": str(area["current"]),
		"visibility": clampf(visibility, 0.25, 1.0),
		"unlocked": dive_area_unlocked(area_id),
		"unlock": str(area["unlock"])
	}


func begin_dive(area_id: String) -> Dictionary:
	if dive_active:
		return {"ok": true, "resumed": true, "state": dive_state.duplicate(true)}
	if fishing_remaining_today() <= 0:
		return {"ok": false, "text": "今天的三个有效鱼群窗口已经用尽，明天清晨会随海况刷新。"}
	if not DIVE_AREAS.has(area_id) or not dive_area_unlocked(area_id):
		return {"ok": false, "text": "这个区域目前还不能安全进入。"}
	var area_index := DIVE_AREAS.keys().find(area_id)
	var used_window := DAILY_FISHING_LIMIT - dive_windows_remaining
	dive_scene_seed = posmod(daily_seed, 2147483647) ^ ((day + 31) * 7919) ^ ((used_window + 7) * 104729) ^ ((area_index + 3) * 15485863)
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = dive_scene_seed
	var candidate_count := 10 if area_id == "sand_shallows" else (9 if area_id == "coral_shelf" else 8)
	var candidates: Array = []
	for index in range(candidate_count):
		var species_id := _roll_dive_species(local_rng, area_id)
		var size_roll := clampf(local_rng.randf() + (0.04 if area_id == "wreck_edge" else 0.0), 0.0, 1.0)
		var behavior := str(FISH_SPECIES[species_id]["behavior"])
		var base_speed: float = float({"群游": 58.0, "藏礁": 43.0, "疾游": 78.0}.get(behavior, 55.0))
		candidates.append({
			"index": index,
			"species_id": species_id,
			"size": FishCatalog.size_from_roll(size_roll),
			"size_score": snappedf(size_roll, 0.0001),
			"behavior": behavior,
			"position": {"x": local_rng.randf_range(0.18, 0.91), "y": local_rng.randf_range(0.16, 0.84)},
			"route_angle": local_rng.randf_range(-PI, PI),
			"speed": base_speed * local_rng.randf_range(0.86, 1.14),
			"captured": false
		})
	dive_active = true
	dive_state = {
		"area_id": area_id,
		"seed": str(dive_scene_seed),
		"day": day,
		"tide": tide,
		"weather": weather,
		"phase": phase_name(),
		"oxygen_max": float(dive_equipment.get("oxygen", 50.0)),
		"oxygen": float(dive_equipment.get("oxygen", 50.0)),
		"basket_capacity": int(dive_equipment.get("basket", 4)),
		"captured_indices": [],
		"candidates": candidates,
		"elapsed": 0.0
	}
	changed.emit()
	return {"ok": true, "resumed": false, "state": dive_state.duplicate(true)}


func _roll_dive_species(local_rng: RandomNumberGenerator, area_id: String) -> String:
	var weighted: Array = []
	var total := 0.0
	for raw_id in FISH_SPECIES.keys():
		var species_id := str(raw_id)
		var weight := FishCatalog.candidate_weight(species_id, area_id, phase_name(), weather)
		if weight <= 0.0:
			continue
		total += weight
		weighted.append({"id": species_id, "ceiling": total})
	if weighted.is_empty():
		return "bubble_sardine"
	var roll := local_rng.randf() * total
	for entry in weighted:
		if roll <= float(entry["ceiling"]):
			return str(entry["id"])
	return str(weighted[-1]["id"])


func update_dive_oxygen(delta_seconds: float, fast_swimming: bool = false) -> float:
	if not dive_active or delta_seconds <= 0.0:
		return float(dive_state.get("oxygen", 0.0))
	var rate := 1.35 if fast_swimming else 1.0
	dive_state["elapsed"] = float(dive_state.get("elapsed", 0.0)) + delta_seconds
	dive_state["oxygen"] = maxf(0.0, float(dive_state.get("oxygen", 0.0)) - delta_seconds * rate)
	return float(dive_state["oxygen"])


func dive_capture(candidate_index: int) -> Dictionary:
	if not dive_active:
		return {"ok": false, "text": "当前没有进行中的潜捕。"}
	if float(dive_state.get("oxygen", 0.0)) <= 0.0:
		return {"ok": false, "forced_surface": true, "text": "氧气已经耗尽，必须立即上浮。"}
	var captured: Array = dive_state.get("captured_indices", [])
	if captured.size() >= int(dive_state.get("basket_capacity", 4)):
		return {"ok": false, "basket_full": true, "text": "鱼篓已经装满。可以放走一条鱼，或带着现有鱼获上浮。"}
	var candidates: Array = dive_state.get("candidates", [])
	if candidate_index < 0 or candidate_index >= candidates.size() or captured.has(candidate_index):
		return {"ok": false, "text": "这条鱼已经离开抓取范围。"}
	captured.append(candidate_index)
	dive_state["captured_indices"] = captured
	dive_state["oxygen"] = maxf(0.0, float(dive_state.get("oxygen", 0.0)) - 1.25)
	var candidate: Dictionary = candidates[candidate_index]
	return {
		"ok": true,
		"candidate": candidate.duplicate(true),
		"basket_count": captured.size(),
		"basket_capacity": int(dive_state.get("basket_capacity", 4)),
		"text": "抓到%s · %s。" % [FishCatalog.species_name(str(candidate["species_id"])), str(candidate["size"])]
	}


func release_dive_catch(candidate_index: int) -> bool:
	if not dive_active:
		return false
	var captured: Array = dive_state.get("captured_indices", [])
	if not captured.has(candidate_index):
		return false
	captured.erase(candidate_index)
	dive_state["captured_indices"] = captured
	return true


func finish_dive(forced_surface: bool = false) -> Dictionary:
	if not dive_active:
		return {"ok": false, "text": "当前没有需要结算的潜捕。"}
	var area_id := str(dive_state.get("area_id", "sand_shallows"))
	var candidates: Array = dive_state.get("candidates", [])
	var caught_now: Array = []
	var first_discoveries: Array[String] = []
	var new_records: Array[String] = []
	for raw_index in dive_state.get("captured_indices", []):
		var candidate_index := int(raw_index)
		if candidate_index < 0 or candidate_index >= candidates.size():
			continue
		var candidate: Dictionary = candidates[candidate_index]
		fish_catch_sequence += 1
		var species_id := str(candidate["species_id"])
		var catch_record := {
			"catch_id": "catch_d%03d_%05d" % [day, fish_catch_sequence],
			"species_id": species_id,
			"size": str(candidate["size"]),
			"size_score": float(candidate["size_score"]),
			"caught_day": day,
			"caught_tide": tide,
			"source_area": area_id,
			"scene_seed": str(dive_scene_seed)
		}
		fish_catch_inventory.append(catch_record)
		caught_now.append(catch_record.duplicate(true))
		if not marine_discoveries.has(species_id):
			first_discoveries.append(FishCatalog.species_name(species_id))
			marine_discoveries[species_id] = {
				"seen": true, "caught": true, "first_day": day, "first_tide": tide,
				"first_area": area_id, "known_tags": FISH_SPECIES[species_id]["tags"].duplicate()
			}
		var prior_score := float(marine_size_records.get(species_id, {}).get("size_score", -1.0))
		if float(candidate["size_score"]) > prior_score:
			marine_size_records[species_id] = {
				"size_score": float(candidate["size_score"]), "size": str(candidate["size"]),
				"catch_id": str(catch_record["catch_id"]), "day": day
			}
			if str(candidate["size"]) == "纪录级":
				new_records.append(FishCatalog.species_name(species_id))
	if not first_discoveries.is_empty():
		add_npc_memory("mia", {
			"memory_id": "marine_discovery_day_%d" % day,
			"type": "marine_discovery",
			"importance": 3,
			"summary": "你在海岸留下了新的海生记录：%s。" % "、".join(first_discoveries),
			"relationship_delta": 0,
			"effects": {"dialogue_warmth": 1}
		})
	if not new_records.is_empty():
		add_npc_memory("mia", {
			"memory_id": "record_fish_day_%d" % day,
			"type": "record_fish",
			"importance": 4,
			"summary": "你捕获了纪录级鱼获：%s。" % "、".join(new_records),
			"relationship_delta": 0,
			"effects": {"private_topic_access": 1, "dialogue_warmth": 1}
		})
	dive_windows_remaining = maxi(0, dive_windows_remaining - 1)
	fishing_attempts_today = DAILY_FISHING_LIMIT - dive_windows_remaining
	dive_sequence += 1
	dive_active = false
	dive_state.clear()
	advance_time_fraction(1.0, "海岸潜捕")
	var estimated_total := 0
	for catch_record in caught_now:
		estimated_total += fish_catch_value(catch_record)
	last_dive_result = {
		"ok": true,
		"forced_surface": forced_surface,
		"area_id": area_id,
		"catches": caught_now,
		"first_discoveries": first_discoveries,
		"new_records": new_records,
		"estimated_total": estimated_total,
		"remaining": dive_windows_remaining,
		"text": "%s，共带回%d条鱼获；当前鱼铺估值约%d金贝。今日还剩%d个有效鱼群窗口。" % [
			"氧气耗尽后自动上浮" if forced_surface else "你主动返回岸边",
			caught_now.size(), estimated_total, dive_windows_remaining
		]
	}
	_record_wealth("海岸潜捕 · 上岸")
	changed.emit()
	return last_dive_result.duplicate(true)


func fish_once() -> Dictionary:
	# 兼容自动测试和无障碍快速潜捕：只生成并保存鱼获，不再直接发放金贝。
	var started := begin_dive("sand_shallows")
	if not bool(started.get("ok", false)):
		return started
	var candidates: Array = dive_state.get("candidates", [])
	var capacity := int(dive_state.get("basket_capacity", 4))
	for index in range(mini(capacity, candidates.size())):
		dive_capture(index)
	return finish_dive(false)


func fish_freshness_state(catch_record: Dictionary) -> String:
	var preservation := clampi(int(dive_equipment.get("preservation_days", 0)), 0, 1)
	var age := maxi(0, day - int(catch_record.get("caught_day", day)) - preservation)
	if age <= 0:
		return "鲜活"
	if age == 1:
		return "尚鲜"
	return "加工级"


func fish_catch_value(catch_record: Dictionary) -> int:
	var species_id := str(catch_record.get("species_id", ""))
	if not FISH_SPECIES.has(species_id):
		return 1
	var quote := float(fish_market_quotes.get(species_id, int(FISH_SPECIES[species_id]["base_value"])))
	var size_multiplier := float(FishCatalog.SIZE_MULTIPLIERS.get(str(catch_record.get("size", "标准")), 1.0))
	var freshness_multiplier := float(FishCatalog.FRESHNESS_MULTIPLIERS.get(fish_freshness_state(catch_record), 0.4))
	return maxi(1, int(round(quote * size_multiplier * freshness_multiplier)))


func fish_inventory_value() -> int:
	var total := 0
	for raw_catch in fish_catch_inventory:
		total += fish_catch_value(raw_catch)
	return total


func _initialize_fish_market() -> void:
	fish_market_quotes.clear()
	fish_market_stock.clear()
	fish_market_demand.clear()
	fish_market_reasons.clear()
	fish_market_refresh_index = 0
	var market_rng := RandomNumberGenerator.new()
	market_rng.seed = posmod(daily_seed, 2147483647) ^ 32452843
	for raw_id in FISH_SPECIES.keys():
		var species_id := str(raw_id)
		var fish: Dictionary = FISH_SPECIES[species_id]
		var rarity := str(fish["rarity"])
		var stock := market_rng.randi_range(5, 12) if rarity == "普通" else (market_rng.randi_range(2, 7) if rarity == "少见" else market_rng.randi_range(0, 2))
		if weather == "强风":
			stock = int(round(stock * 0.65))
		var demand := market_rng.randi_range(5, 11)
		if fish["tags"].has("餐厅"):
			demand += 2
		if phase_name() == "夜晚" and fish["tags"].has("收藏"):
			demand += 3
		fish_market_stock[species_id] = maxi(0, stock)
		fish_market_demand[species_id] = maxi(1, demand)
		fish_market_quotes[species_id] = _fish_target_quote(species_id, demand, stock)
		fish_market_reasons[species_id] = _fish_price_reasons(species_id, stock, demand)
	_generate_fish_market_orders(market_rng)
	_record_fish_market_history("清晨开市")


func _refresh_fish_market(reason: String) -> void:
	if fish_market_quotes.is_empty():
		_initialize_fish_market()
		return
	fish_market_refresh_index += 1
	var market_rng := RandomNumberGenerator.new()
	market_rng.seed = posmod(daily_seed, 2147483647) ^ (fish_market_refresh_index * 49979687)
	for raw_id in FISH_SPECIES.keys():
		var species_id := str(raw_id)
		var fish: Dictionary = FISH_SPECIES[species_id]
		var stock := maxi(0, int(fish_market_stock.get(species_id, 0)))
		var prior_demand := maxi(1, int(fish_market_demand.get(species_id, 1)))
		var consumption := mini(stock, market_rng.randi_range(1, maxi(1, mini(5, prior_demand))))
		stock -= consumption
		var supply_max := 6 if str(fish["rarity"]) == "普通" else (3 if str(fish["rarity"]) == "少见" else 1)
		var npc_supply := market_rng.randi_range(0, supply_max)
		if weather == "强风":
			npc_supply = int(floor(npc_supply * 0.5))
		elif weather == "阵雨" and fish["weather"].has("阵雨"):
			npc_supply += 1
		stock += npc_supply
		var demand := market_rng.randi_range(4, 10)
		if fish["tags"].has("餐厅"):
			demand += 2
		if phase_name() == "傍晚" and fish["tags"].has("节庆"):
			demand += 3
		if phase_name() == "夜晚" and fish["tags"].has("收藏"):
			demand += 3
		var target := float(_fish_target_quote(species_id, demand, stock))
		var previous := float(fish_market_quotes.get(species_id, target))
		fish_market_stock[species_id] = stock
		fish_market_demand[species_id] = demand
		fish_market_quotes[species_id] = maxi(1, int(round(previous * 0.60 + target * 0.40)))
		fish_market_reasons[species_id] = _fish_price_reasons(species_id, stock, demand)
	_record_fish_market_history(reason)
	changed.emit()


func _fish_target_quote(species_id: String, demand: int, stock: int) -> int:
	var base_value := float(FISH_SPECIES[species_id]["base_value"])
	var supply_demand := clampf(sqrt(float(demand + 1) / float(stock + 1)), 0.60, 2.20)
	return maxi(1, int(round(base_value * supply_demand)))


func _fish_price_reasons(species_id: String, stock: int, demand: int) -> Array:
	var fish: Dictionary = FISH_SPECIES[species_id]
	var reasons: Array[String] = []
	if weather == "强风":
		reasons.append("强风让渔船到货减少")
	elif weather == "阵雨" and fish["weather"].has("阵雨"):
		reasons.append("阵雨海况让该鱼群更活跃")
	if phase_name() == "傍晚" and fish["tags"].has("节庆"):
		reasons.append("傍晚宴席正在采购节庆鱼")
	elif phase_name() == "夜晚" and fish["tags"].has("收藏"):
		reasons.append("夜市收藏需求增加")
	elif fish["tags"].has("餐厅"):
		reasons.append("海鲜餐厅维持采购")
	if stock >= demand + 4:
		reasons.append("当前库存充足，报价承压")
	elif demand >= stock + 4:
		reasons.append("重点需求高于现有库存")
	else:
		reasons.append("居民供需大致平衡")
	return reasons.slice(0, 3)


func _record_fish_market_history(reason: String) -> void:
	fish_market_history.append({
		"day": day, "tide": tide, "phase": phase_name(), "reason": reason,
		"quotes": fish_market_quotes.duplicate(true), "stock": fish_market_stock.duplicate(true),
		"demand": fish_market_demand.duplicate(true)
	})
	while fish_market_history.size() > 32:
		fish_market_history.pop_front()


func _generate_fish_market_orders(market_rng: RandomNumberGenerator) -> void:
	fish_market_orders.clear()
	var candidates: Array[String] = []
	for raw_id in FISH_SPECIES.keys():
		var species_id := str(raw_id)
		if FISH_SPECIES[species_id]["tags"].has("餐厅") or FISH_SPECIES[species_id]["tags"].has("收藏"):
			candidates.append(species_id)
	for order_index in range(2):
		var species_id := candidates[market_rng.randi_range(0, candidates.size() - 1)]
		var quantity := 2 if str(FISH_SPECIES[species_id]["rarity"]) == "普通" else 1
		var reward_each := maxi(1, int(round(float(fish_market_quotes[species_id]) * (1.35 if order_index == 0 else 1.55))))
		fish_market_orders.append({
			"order_id": "order-d%03d-%d" % [day, order_index + 1],
			"buyer": "海鲜餐厅" if order_index == 0 else "潮灯收藏家",
			"species_id": species_id,
			"quantity": quantity,
			"reward_each": reward_each,
			"deadline_day": day,
			"deadline_tide": 12 if order_index == 0 else 16,
			"completed": false
		})


func fish_market_rows() -> Array:
	var rows: Array = []
	for raw_id in FISH_SPECIES.keys():
		var species_id := str(raw_id)
		var previous_quote := int(fish_market_quotes.get(species_id, int(FISH_SPECIES[species_id]["base_value"])))
		if fish_market_history.size() >= 2:
			var previous: Dictionary = fish_market_history[-2]
			previous_quote = int(previous.get("quotes", {}).get(species_id, previous_quote))
		rows.append({
			"species_id": species_id,
			"name": FishCatalog.species_name(species_id),
			"rarity": str(FISH_SPECIES[species_id]["rarity"]),
			"quote": int(fish_market_quotes.get(species_id, 1)),
			"change": int(fish_market_quotes.get(species_id, 1)) - previous_quote,
			"stock": int(fish_market_stock.get(species_id, 0)),
			"demand": int(fish_market_demand.get(species_id, 0)),
			"reasons": fish_market_reasons.get(species_id, []).duplicate()
		})
	rows.sort_custom(func(a, b): return int(a["quote"]) > int(b["quote"]))
	return rows


func create_fish_sale_preview(catch_ids: Array) -> Dictionary:
	var selected: Array = []
	var requested := {}
	for raw_id in catch_ids:
		requested[str(raw_id)] = true
	for raw_catch in fish_catch_inventory:
		var catch_record: Dictionary = raw_catch
		if requested.has(str(catch_record.get("catch_id", ""))):
			selected.append(catch_record.duplicate(true))
	if selected.is_empty():
		return {"ok": false, "text": "没有选择可出售的鱼获。"}
	var demand_remaining := fish_market_demand.duplicate(true)
	var overflow_counts := {}
	var lines: Array = []
	var total := 0
	for catch_record in selected:
		var species_id := str(catch_record["species_id"])
		var quote := int(fish_market_quotes.get(species_id, int(FISH_SPECIES.get(species_id, {}).get("base_value", 1))))
		var size_multiplier := float(FishCatalog.SIZE_MULTIPLIERS.get(str(catch_record.get("size", "标准")), 1.0))
		var freshness := fish_freshness_state(catch_record)
		var freshness_multiplier := float(FishCatalog.FRESHNESS_MULTIPLIERS.get(freshness, 0.4))
		var remaining := int(demand_remaining.get(species_id, 0))
		var tier := "重点需求"
		var raw_unit := float(quote)
		var demand_consumed := 0
		if remaining > 0:
			demand_remaining[species_id] = remaining - 1
			demand_consumed = 1
		else:
			var overflow := int(overflow_counts.get(species_id, 0))
			var overflow_capacity := maxi(2, int(ceil(float(fish_market_demand.get(species_id, 0)) * 0.5)))
			if overflow < overflow_capacity:
				tier = "普通加工85%"
				raw_unit = quote * 0.85
			else:
				tier = "大量加工60%"
				raw_unit = float(FISH_SPECIES.get(species_id, {}).get("base_value", 1)) * 0.60
			overflow_counts[species_id] = overflow + 1
		var unit_price := maxi(1, int(round(raw_unit * size_multiplier * freshness_multiplier)))
		total += unit_price
		lines.append({
			"catch_id": str(catch_record["catch_id"]), "species_id": species_id,
			"name": FishCatalog.species_name(species_id), "size": str(catch_record["size"]),
			"freshness": freshness, "tier": tier, "unit_price": unit_price,
			"demand_consumed": demand_consumed
		})
	fish_sale_sequence += 1
	var sale_id := "sale-d%03d-t%02d-%05d" % [day, tide, fish_sale_sequence]
	var preview := {"ok": true, "sale_id": sale_id, "lines": lines, "total": total, "count": lines.size()}
	pending_fish_sales[sale_id] = preview.duplicate(true)
	return preview


func confirm_fish_sale(sale_id: String) -> Dictionary:
	if processed_fish_sales.has(sale_id):
		return {"ok": false, "duplicate": true, "text": "这笔成交已经结算，不能重复领取金贝。"}
	if not pending_fish_sales.has(sale_id):
		return {"ok": false, "text": "出售预览已经失效，请重新确认当前报价。"}
	var preview: Dictionary = pending_fish_sales[sale_id]
	var inventory_by_id := {}
	for raw_catch in fish_catch_inventory:
		var catch_record: Dictionary = raw_catch
		inventory_by_id[str(catch_record.get("catch_id", ""))] = catch_record
	for raw_line in preview["lines"]:
		if not inventory_by_id.has(str(raw_line["catch_id"])):
			pending_fish_sales.erase(sale_id)
			return {"ok": false, "text": "鱼获箱已经变化，未执行本次出售。"}
	var sold_ids := {}
	for raw_line in preview["lines"]:
		var line: Dictionary = raw_line
		var species_id := str(line["species_id"])
		sold_ids[str(line["catch_id"])] = true
		fish_market_stock[species_id] = int(fish_market_stock.get(species_id, 0)) + 1
		fish_market_demand[species_id] = maxi(0, int(fish_market_demand.get(species_id, 0)) - int(line.get("demand_consumed", 0)))
	var retained: Array = []
	for raw_catch in fish_catch_inventory:
		if not sold_ids.has(str(raw_catch.get("catch_id", ""))):
			retained.append(raw_catch)
	fish_catch_inventory = retained
	var total := int(preview["total"])
	cash += total
	processed_fish_sales[sale_id] = true
	pending_fish_sales.erase(sale_id)
	var transaction := {
		"sale_id": sale_id, "day": day, "tide": tide, "total": total,
		"count": int(preview["count"]), "lines": preview["lines"].duplicate(true)
	}
	fish_market_transactions.append(transaction)
	while fish_market_transactions.size() > 64:
		fish_market_transactions.pop_front()
	_record_wealth("蓝鳍鱼铺 · 出售%d条鱼获" % int(preview["count"]))
	changed.emit()
	return {"ok": true, "sale_id": sale_id, "total": total, "count": int(preview["count"]), "text": "蓝鳍鱼铺收购了%d条鱼获，支付%d金贝。" % [int(preview["count"]), total]}


func turn_in_fish_order(order_id: String) -> Dictionary:
	var order_index := -1
	for index in range(fish_market_orders.size()):
		if str(fish_market_orders[index].get("order_id", "")) == order_id:
			order_index = index
			break
	if order_index < 0:
		return {"ok": false, "text": "这个订单已经不在公告板上。"}
	var order: Dictionary = fish_market_orders[order_index]
	if bool(order.get("completed", false)):
		return {"ok": false, "text": "这个订单已经交付。"}
	if day > int(order["deadline_day"]) or (day == int(order["deadline_day"]) and tide > int(order["deadline_tide"])):
		return {"ok": false, "text": "这个订单已经超过截止潮刻。"}
	var qualifying: Array = []
	for raw_catch in fish_catch_inventory:
		if str(raw_catch.get("species_id", "")) == str(order["species_id"]):
			qualifying.append(raw_catch)
	if qualifying.size() < int(order["quantity"]):
		return {"ok": false, "text": "还需要%d条%s。" % [int(order["quantity"]), FishCatalog.species_name(str(order["species_id"]))]}
	qualifying.sort_custom(func(a, b): return int(a["caught_day"]) < int(b["caught_day"]))
	var used := {}
	for index in range(int(order["quantity"])):
		used[str(qualifying[index]["catch_id"])] = true
	var retained: Array = []
	for raw_catch in fish_catch_inventory:
		if not used.has(str(raw_catch.get("catch_id", ""))):
			retained.append(raw_catch)
	fish_catch_inventory = retained
	var reward := int(order["quantity"]) * int(order["reward_each"])
	cash += reward
	order["completed"] = true
	fish_market_orders[order_index] = order
	_record_wealth("鱼市订单 · %s" % str(order["buyer"]))
	changed.emit()
	return {"ok": true, "reward": reward, "text": "%s收下%d条%s，支付%d金贝。" % [str(order["buyer"]), int(order["quantity"]), FishCatalog.species_name(str(order["species_id"])), reward]}


func activate_aqiu_request() -> void:
	accept_npc_request("aqiu")


func turn_in_aqiu_request() -> Dictionary:
	if aqiu_request_done:
		return {"ok": false, "text": "阿葵已经记下你发现的水罐补水方法。"}
	if str(npc_request_states.get("aqiu", {}).get("state", "available")) == "available":
		accept_npc_request("aqiu")
	if not _npc_request_condition_met("discover_water_jar"):
		return {"ok": false, "text": "阿葵想为逐风兽准备稳定的补水器具。陶器已经能固定形状，再想想什么能赋予它用途。"}
	var result := turn_in_npc_request("aqiu")
	if bool(result.get("ok", false)):
		result["text"] = "阿葵记下水罐的补水方法，支付80金贝，并告诉你云鳍今天状态不错。水罐仍永久保留在图鉴中。"
	return result


func add_memory(npc_id: String, text: String) -> void:
	add_npc_memory(npc_id, {
		"memory_id": "legacy_%s_%d" % [npc_id, int(Time.get_ticks_usec())],
		"type": "event",
		"importance": 2,
		"summary": text,
		"relationship_delta": 0,
		"effects": {}
	})


func adjust_relationship(npc_id: String, amount: int) -> int:
	if not NPCS.has(npc_id):
		return 0
	relationships[npc_id] = clampi(int(relationships.get(npc_id, 0)) + amount, -100, 100)
	return int(relationships[npc_id])


func add_npc_memory(npc_id: String, raw_memory: Dictionary) -> Dictionary:
	if not NPCS.has(npc_id):
		return {}
	if not memories.has(npc_id) or not memories[npc_id] is Dictionary:
		memories[npc_id] = {"recent": [], "long": []}
	var store: Dictionary = memories[npc_id]
	var recent: Array = store.get("recent", [])
	var memory_id := str(raw_memory.get("memory_id", ""))
	if memory_id.is_empty():
		memory_id = "%s_%s_%d_%d" % [npc_id, str(raw_memory.get("type", "event")), day, tide]
	var existing_index := -1
	for index in range(recent.size()):
		if str(recent[index].get("memory_id", "")) == memory_id:
			existing_index = index
			break
	var is_new := existing_index < 0
	var record: Dictionary = raw_memory.duplicate(true)
	if not is_new:
		var existing: Dictionary = recent[existing_index]
		record["occurrences"] = int(existing.get("occurrences", 1)) + 1
		record["importance"] = maxi(int(existing.get("importance", 1)), int(record.get("importance", 1)))
		if str(record.get("summary", "")).is_empty():
			record["summary"] = str(existing.get("summary", ""))
		if not record.has("effects"):
			record["effects"] = existing.get("effects", {}).duplicate(true)
		recent.remove_at(existing_index)
	else:
		record["occurrences"] = maxi(1, int(record.get("occurrences", 1)))
	record["memory_id"] = memory_id
	record["type"] = str(record.get("type", "event"))
	record["importance"] = clampi(int(record.get("importance", 1)), 1, 5)
	record["created_day"] = day
	record["created_tide"] = tide
	record["summary"] = str(record.get("summary", "发生了一件被记住的事。"))
	record["relationship_delta"] = int(record.get("relationship_delta", 0))
	if not record.get("effects", {}) is Dictionary:
		record["effects"] = {}
	recent.push_front(record)
	var reward_key := "%s:%s" % [npc_id, memory_id]
	if int(record["relationship_delta"]) != 0 and not bool(npc_memory_rewarded.get(reward_key, false)):
		adjust_relationship(npc_id, int(record["relationship_delta"]))
		npc_memory_rewarded[reward_key] = true
	var should_consolidate := bool(record.get("persistent", false)) or int(record["importance"]) >= 4 or int(record["occurrences"]) >= 2
	if should_consolidate:
		_upsert_long_memory(store, record)
	while recent.size() > 5:
		var remove_index := recent.size() - 1
		var lowest_importance := int(recent[remove_index].get("importance", 1))
		for index in range(recent.size() - 2, -1, -1):
			var importance := int(recent[index].get("importance", 1))
			if importance < lowest_importance:
				lowest_importance = importance
				remove_index = index
		recent.remove_at(remove_index)
	store["recent"] = recent
	memories[npc_id] = store
	return record.duplicate(true)


func _upsert_long_memory(store: Dictionary, record: Dictionary) -> void:
	var long_term: Array = store.get("long", [])
	var existing_index := -1
	for index in range(long_term.size()):
		if str(long_term[index].get("memory_id", "")) == str(record.get("memory_id", "")):
			existing_index = index
			break
	var consolidated := record.duplicate(true)
	consolidated["consolidated_day"] = day
	consolidated["consolidated_tide"] = tide
	if existing_index >= 0:
		long_term[existing_index] = consolidated
	else:
		long_term.append(consolidated)
	long_term.sort_custom(func(a, b):
		var priority_a := int(a.get("importance", 1)) * 10 + mini(9, int(a.get("occurrences", 1)))
		var priority_b := int(b.get("importance", 1)) * 10 + mini(9, int(b.get("occurrences", 1)))
		if priority_a != priority_b:
			return priority_a > priority_b
		return int(a.get("consolidated_day", 0)) > int(b.get("consolidated_day", 0))
	)
	if long_term.size() > 2:
		long_term.resize(2)
	store["long"] = long_term


func npc_recent_memories(npc_id: String) -> Array:
	var store = memories.get(npc_id, {})
	return store.get("recent", []).duplicate(true) if store is Dictionary else []


func npc_long_memories(npc_id: String) -> Array:
	var store = memories.get(npc_id, {})
	return store.get("long", []).duplicate(true) if store is Dictionary else []


func npc_memory_effect(npc_id: String, effect_key: String) -> int:
	var total := 0
	var long_ids := {}
	for raw_memory in npc_long_memories(npc_id):
		var memory: Dictionary = raw_memory
		long_ids[str(memory.get("memory_id", ""))] = true
		var effects = memory.get("effects", {})
		if effects is Dictionary:
			total += int(effects.get(effect_key, 0))
	for raw_memory in npc_recent_memories(npc_id):
		var memory: Dictionary = raw_memory
		if long_ids.has(str(memory.get("memory_id", ""))):
			continue
		var effects = memory.get("effects", {})
		if effects is Dictionary:
			total += int(effects.get(effect_key, 0))
	return clampi(total, -20, 20)


func relationship_state(npc_id: String) -> String:
	var score := int(relationships.get(npc_id, 0))
	if score < -19:
		return "疏远"
	if score < 10:
		return "陌生"
	if score < 40:
		return "熟悉"
	return "信任"


func npc_talk(npc_id: String) -> Dictionary:
	if not NPCS.has(npc_id):
		return {"ok": false, "text": "这里没有可以交谈的人。"}
	meet_npc(npc_id)
	var profile := npc_profile(npc_id)
	var dialogue: Array = profile.get("dialogue", [])
	if dialogue.is_empty():
		return {"ok": false, "text": "对方暂时没有新的话。"}
	var count := int(npc_talk_counts.get(npc_id, 0))
	npc_talk_counts[npc_id] = count + 1
	var index := posmod(count + day + tide, dialogue.size())
	var state := relationship_state(npc_id)
	var parts: Array[String] = []
	if state != "陌生" and profile.get("reactions", {}).has(state):
		parts.append(str(profile["reactions"][state]))
	parts.append(str(dialogue[index]))
	var recent := npc_recent_memories(npc_id)
	if not recent.is_empty() and count % 3 == 1:
		parts.append("对方还记得：%s" % str(recent[0].get("summary", "")))
	changed.emit()
	return {"ok": true, "text": "\n\n".join(parts), "state": state, "repeatable": true}


func npc_topics(npc_id: String) -> Array:
	if not NPCS.has(npc_id):
		return []
	var profile := npc_profile(npc_id)
	var result: Array = []
	var private_access := relationship_state(npc_id) == "信任" or npc_memory_effect(npc_id, "private_topic_access") > 0
	for raw_topic in profile.get("topics", []):
		var topic: Dictionary = raw_topic.duplicate(true)
		if bool(topic.get("private", false)) and not private_access:
			continue
		var read_key := _npc_topic_read_key(npc_id, str(topic.get("id", "")))
		topic["read"] = bool(npc_topic_reads.get(read_key, false))
		result.append(topic)
	return result


func _npc_topic_read_key(npc_id: String, topic_id: String) -> String:
	return "%s:%s:%d:%s" % [npc_id, topic_id, day, phase_name()]


func npc_ask(npc_id: String, topic_id: String) -> Dictionary:
	var selected: Dictionary = {}
	for raw_topic in npc_topics(npc_id):
		var topic: Dictionary = raw_topic
		if str(topic.get("id", "")) == topic_id:
			selected = topic
			break
	if selected.is_empty():
		return {"ok": false, "text": "这条话题现在还没有开放。"}
	var read_key := _npc_topic_read_key(npc_id, topic_id)
	var repeated := bool(npc_topic_reads.get(read_key, false))
	npc_topic_reads[read_key] = true
	changed.emit()
	return {
		"ok": true,
		"text": _npc_topic_text(npc_id, topic_id),
		"type": str(selected.get("type", "人物观点")),
		"source": str(selected.get("source", "对方本人")),
		"generated_at": "第%d天%s" % [day, phase_name()],
		"valid_until": _npc_topic_valid_until(topic_id),
		"repeat": repeated
	}


func _npc_topic_valid_until(topic_id: String) -> String:
	if topic_id in ["synthesis_direction", "table_observation", "race_schedule", "beast_condition", "public_report", "fish_market_observation", "research_market"]:
		return "第%d天%s结束" % [day, phase_name()]
	return "长期有效"


func _npc_topic_text(npc_id: String, topic_id: String) -> String:
	match topic_id:
		"synthesis_basics":
			return "已经发现的万物会永久留在图鉴中，可以在造化盆左右两侧反复使用。新组合只支付实验费，不消耗万物。"
		"synthesis_direction":
			return "你目前发现了%d/%d项万物，眼下有%d条由已知万物组成、但尚未尝试的关系。" % [discovered_item_ids().size(), ITEMS.size(), count_untried_visible_pairs()]
		"tower_memory":
			return "“塔并不收藏所有正确答案。它收藏岛民愿意公开验证、也允许后来者改正的关系。”"
		"poker_public_rules":
			return "命运牌会由六席轮换司契位与盲注，每席只补齐本轮差额；退契者不再行动，主池、边池、未跟注返还和服务费必须守恒。"
		"table_observation":
			var courage_effect := npc_memory_effect("old_joe", "poker_courage")
			return "老乔认为今天桌面%s。他强调这只是对行动节奏的观察，不代表任何人的隐藏命牌。" % ("比平常更敢施压" if courage_effect > 0 else ("比平常更谨慎" if courage_effect < 0 else "还没有形成明显倾向"))
		"joe_old_loss":
			return "“我输得最重的那次，牌并不差。坏的是我早把离桌线说出口，后来又亲手越过去。”"
		"race_schedule":
			var next_tide := 0
			for scheduled_tide in [3, 7, 11, 15]:
				if scheduled_tide >= tide:
					next_tide = scheduled_tide
					break
			return "今天的公开赛事潮刻为3、7、11、15。%s" % ("下一场在%d/16潮刻。" % next_tide if next_tide > 0 else "今天的常规场已经结束。")
		"beast_condition":
			var support_count := npc_memory_effect("aqiu", "race_support")
			return "阿葵今天没有观察到明显伤病。%s会改变部分逐风兽的发挥区间，但“状态正常”不等于保证名次。她还记得你此前%d点持续观赛与支持记录。" % [weather, maxi(0, support_count)]
		"rider_pressure":
			return "“看台希望每一场都有英雄，可骑师更该记得，逐风兽明天还要继续生活。”"
		"public_report":
			return "第%d天，天气%s、%s。公开鱼价、赛事与财富资格都以当前时段的公示为准。" % [day, weather, wind_direction]
		"fish_market_observation":
			var rows := fish_market_rows()
			if rows.is_empty():
				return "蓝鳍鱼铺当前没有可核对的报价记录。"
			var top: Dictionary = rows[0]
			return "%s当前报价%d金贝。公开原因：%s。这个报价会在时段刷新时重新计算。" % [str(top.get("name", "鱼获")), int(top.get("quote", 0)), "；".join(top.get("reasons", []))]
		"mia_unpublished_note":
			return "“我正在核对财富暴涨与高风险活动之间的关系。现在只有样本，没有结论，所以暂时不会写成头条。”"
		"wealth_title":
			var milestone := next_wealth_milestone()
			if bool(milestone.get("complete", false)):
				return "你当前是%s，已经达到现有最高公共财富资格。" % wealth_title()
			return "你当前是%s；距离下一头衔“%s”还差%d金贝净资产。" % [wealth_title(), str(milestone.get("title", "")), int(milestone.get("remaining", 0))]
		"risk_view":
			return "“风险不是赔率大不大，而是结果最坏时，你是否仍保有下一次选择。”"
		"club_invitation":
			return "“俱乐部会在后期财富系统开放后发出正式邀请。关系只能决定我愿不愿意邀请，不能替你绕过财富资格。”"
		"shop_services":
			return "杂货铺目前提供配方方向线索与有限次数的实验折扣。服务不会直接解锁万物，也不会收走永久造物。"
		"research_market":
			return "当前仍有%d条可由已知万物直接研究的新关系。阿拓的判断来自本店研究记录，不代表哪条关系最赚钱。" % count_untried_visible_pairs()
		"shopkeeper_ledger":
			return "“我见过最贵的错误，是大家都认为别人已经验证过，于是谁也没有亲手验证。”"
	return "%s暂时只愿意说：这是一条个人判断，不是系统保证。" % str(npc_profile(npc_id).get("name", "对方"))


func npc_request_info(npc_id: String) -> Dictionary:
	var profile := npc_profile(npc_id)
	var request: Dictionary = profile.get("request", {}).duplicate(true)
	if request.is_empty():
		return {}
	var state_record: Dictionary = npc_request_states.get(npc_id, {"state": "available"})
	var state := str(state_record.get("state", "available"))
	if not _npc_request_requirement_met(str(request.get("requires", ""))):
		state = "locked"
	request["state"] = state
	request["condition_met"] = _npc_request_condition_met(str(request.get("condition", "")))
	request["accepted_day"] = int(state_record.get("accepted_day", 0))
	request["completed_day"] = int(state_record.get("completed_day", 0))
	return request


func _npc_request_requirement_met(requirement: String) -> bool:
	if requirement.is_empty():
		return true
	if requirement == "complete_poker":
		return normal_poker_completed
	return false


func _npc_request_condition_met(condition: String) -> bool:
	match condition:
		"discover_steam":
			return is_discovered("steam")
		"complete_poker":
			return normal_poker_completed
		"discover_water_jar":
			return is_discovered("water_jar")
		"record_fish":
			return not marine_size_records.is_empty()
		"keep_reserve":
			return account_wealth() >= 500 and cash >= suggested_reserve()
		"discover_tier_two":
			for item_id in discovered_item_ids():
				if item_tier(item_id) == 2:
					return true
	return false


func accept_npc_request(npc_id: String) -> Dictionary:
	var info := npc_request_info(npc_id)
	if info.is_empty():
		return {"ok": false, "text": "对方现在没有可接受的委托。"}
	var state := str(info.get("state", "available"))
	if state == "locked":
		return {"ok": false, "text": "这项委托还没有出现。先完成相关人物引导。"}
	if state == "completed":
		return {"ok": false, "text": "这项委托已经完成。"}
	if state == "active":
		return {"ok": false, "text": "这项委托已经在进行中。"}
	npc_request_states[npc_id] = {"state": "active", "accepted_day": day, "completed_day": 0}
	if npc_id == "aqiu":
		aqiu_request_active = true
		aqiu_request_done = false
	add_npc_memory(npc_id, {
		"memory_id": "accepted_%s" % str(info.get("id", npc_id)),
		"type": "request",
		"importance": 2,
		"summary": "你接受了委托“%s”。" % str(info.get("title", "人物请求")),
		"relationship_delta": 0,
		"effects": {"request_priority": 1}
	})
	changed.emit()
	return {"ok": true, "text": "已接受“%s”。\n目标：%s\n线索：%s" % [str(info.get("title", "人物请求")), str(info.get("objective", "")), str(info.get("hint", ""))]}


func turn_in_npc_request(npc_id: String) -> Dictionary:
	var info := npc_request_info(npc_id)
	if info.is_empty():
		return {"ok": false, "text": "对方现在没有可交付的委托。"}
	var state := str(info.get("state", "available"))
	if state == "completed":
		return {"ok": false, "text": "这项委托已经结算，不能重复领取奖励。"}
	if state != "active":
		return {"ok": false, "text": "需要先接受这项委托。"}
	if not bool(info.get("condition_met", false)):
		return {"ok": false, "text": "目标尚未完成。\n%s\n线索：%s" % [str(info.get("objective", "")), str(info.get("hint", ""))]}
	var rewards: Dictionary = info.get("rewards", {})
	var coins := maxi(0, int(rewards.get("coins", 0)))
	var relationship_delta := int(rewards.get("relationship", 0))
	var discount_uses := maxi(0, int(rewards.get("discount_uses", 0)))
	if coins > 0:
		cash += coins
		_record_wealth("完成%s委托" % str(npc_profile(npc_id).get("name", "人物")))
	if discount_uses > 0:
		synthesis_discount_uses = mini(6, synthesis_discount_uses + discount_uses)
	npc_request_states[npc_id] = {"state": "completed", "accepted_day": int(info.get("accepted_day", day)), "completed_day": day}
	if npc_id == "aqiu":
		aqiu_request_active = false
		aqiu_request_done = true
	add_npc_memory(npc_id, {
		"memory_id": "completed_%s" % str(info.get("id", npc_id)),
		"type": "request_completed",
		"importance": 5,
		"persistent": true,
		"summary": "你完成了委托“%s”。" % str(info.get("title", "人物请求")),
		"relationship_delta": relationship_delta,
		"effects": {"dialogue_warmth": 2, "private_topic_access": 1, "request_priority": 2}
	})
	changed.emit()
	var reward_parts: Array[String] = []
	if coins > 0:
		reward_parts.append("%d金贝" % coins)
	if relationship_delta != 0:
		reward_parts.append("人物关系发生变化")
	if discount_uses > 0:
		reward_parts.append("%d次实验折扣" % discount_uses)
	return {"ok": true, "text": "委托“%s”已经完成。获得：%s。" % [str(info.get("title", "人物请求")), "、".join(reward_parts) if not reward_parts.is_empty() else "一段被长期记住的经历"], "rewards": rewards.duplicate(true)}


func share_creation_with_npc(npc_id: String, item_id: String) -> Dictionary:
	if not NPCS.has(npc_id) or not is_discovered(item_id):
		return {"ok": false, "text": "只能分享已经永久发现的万物。"}
	var share_key := "%s:%s" % [npc_id, item_id]
	if bool(npc_shared_creations.get(share_key, false)):
		return {"ok": false, "repeat": true, "text": "%s已经听你讲过%s的方法；重复分享不会再次改变关系。" % [str(npc_profile(npc_id).get("name", "对方")), item_name(item_id)]}
	npc_shared_creations[share_key] = true
	var profile := npc_profile(npc_id)
	var interests: Array = profile.get("share_interest", [])
	var category := str(ITEMS.get(item_id, {}).get("category", ""))
	var relevant := interests.has(category)
	add_npc_memory(npc_id, {
		"memory_id": "shared_creation_%s" % item_id,
		"type": "shared_creation",
		"importance": 3 if relevant else 2,
		"summary": "你向%s分享了%s的形成方法。" % [str(profile.get("name", "对方")), item_name(item_id)],
		"relationship_delta": 2 if relevant else 0,
		"effects": {"dialogue_warmth": 1 if relevant else 0}
	})
	changed.emit()
	return {"ok": true, "text": "%s认真看过%s。%s万物仍永久保留在图鉴中。" % [str(profile.get("name", "对方")), item_name(item_id), "这正合对方的研究方向；" if relevant else "对方记下了你的方法；"], "relevant": relevant}


func share_record_fish_with_npc(npc_id: String, species_id: String) -> Dictionary:
	if not NPCS.has(npc_id) or not marine_size_records.has(species_id):
		return {"ok": false, "text": "这项海生尺寸纪录尚未建立。"}
	var share_key := "%s:%s" % [npc_id, species_id]
	if bool(npc_shared_fish.get(share_key, false)):
		return {"ok": false, "repeat": true, "text": "这项纪录已经展示过，重复查看不会再次改变关系。"}
	npc_shared_fish[share_key] = true
	var relevant := npc_id in ["mia", "aqiu"]
	var fish_name := FishCatalog.species_name(species_id)
	var size_record: Dictionary = marine_size_records.get(species_id, {})
	var size_label := str(size_record.get("size", "标准"))
	add_npc_memory(npc_id, {
		"memory_id": "shared_fish_%s" % species_id,
		"type": "record_fish",
		"importance": 3,
		"summary": "你展示了%s级的%s尺寸纪录。" % [size_label, fish_name],
		"relationship_delta": 2 if relevant else 0,
		"effects": {"dialogue_warmth": 1, "race_support": 1 if npc_id == "aqiu" else 0}
	})
	changed.emit()
	return {"ok": true, "text": "%s查看了%s级的%s纪录。展示纪录不会移除鱼获。" % [str(npc_profile(npc_id).get("name", "对方")), size_label, fish_name]}


func npc_deep_talk(npc_id: String) -> Dictionary:
	if relationship_state(npc_id) not in ["熟悉", "信任"]:
		return {"ok": false, "text": "关系达到熟悉后，才会出现可以深入谈论的个人话题。"}
	if int(npc_deep_talk_days.get(npc_id, 0)) == day:
		return {"ok": false, "text": "今天已经深入谈过一次。普通交谈仍可继续，但不会重复结算关系或时间事件。"}
	if day_end_pending:
		return {"ok": false, "text": "夜已经停驻，先回小屋完成日终。"}
	var state := relationship_state(npc_id)
	var profile := npc_profile(npc_id)
	var deep_text := str(profile.get("deep_talk", {}).get(state, "你们谈了一段没有公开记录的往事。"))
	var time_cost := 1.0 if state == "信任" else 0.5
	npc_deep_talk_days[npc_id] = day
	add_npc_memory(npc_id, {
		"memory_id": "deep_talk_day_%d" % day,
		"type": "deep_talk",
		"importance": 3,
		"summary": "你们在第%d天进行了一次深入交谈。" % day,
		"relationship_delta": 1,
		"effects": {"dialogue_warmth": 1}
	})
	set_time_pause("npc_deep_talk", true, TIME_STATE_ACTIVITY)
	advance_time_fraction(time_cost, "与%s深入交谈" % str(profile.get("name", "人物")))
	set_time_pause("npc_deep_talk", false)
	changed.emit()
	return {"ok": true, "text": deep_text, "time_cost": time_cost}


func _record_poker_social_memories(outcome: String, bank_net: int) -> void:
	var summary := ""
	var courage_effect := 0
	match outcome:
		"win", "tie":
			summary = "你在最近一手命运牌会中获胜或参与平分，本手净变化%s金贝。" % _signed_number(bank_net)
			courage_effect = -1
		"fold":
			summary = "你在最近一手命运牌会中选择退契，本手净变化%s金贝。" % _signed_number(bank_net)
			courage_effect = 1
		_:
			summary = "你在最近一手命运牌会中未获胜，本手净变化%s金贝。" % _signed_number(bank_net)
			courage_effect = 1
	for npc_id in ["old_joe", "shopkeeper", "mia", "granny"]:
		add_npc_memory(npc_id, {
			"memory_id": "poker_pattern_%s" % outcome,
			"type": "poker",
			"importance": 3,
			"summary": summary,
			"relationship_delta": 0,
			"effects": {"poker_courage": courage_effect}
		})


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
		"rain":
			var modifier := _race_weather_modifier(beast)
			var modifiers: Array[float] = []
			for raw_beast in RACE_BEASTS:
				modifiers.append(_race_weather_modifier(raw_beast))
			insight = "%s在%s中的阶段修正为%+.2f，天气适应列第%d。" % [str(beast["name"]), weather, modifier, _descending_rank(modifier, modifiers)]
		"thunderstorm":
			var sigma := 12.0 - float(beast["stability"]) * 0.08
			var sigmas: Array[float] = []
			for raw_beast in RACE_BEASTS:
				sigmas.append(12.0 - float(raw_beast["stability"]) * 0.08)
			var level := "低波动" if sigma <= 6.0 else ("中波动" if sigma <= 7.0 else "高波动")
			insight = "%s为%s，阶段标准差 %.2f，波动程度列第%d。" % [str(beast["name"]), level, sigma, _descending_rank(sigma, sigmas)]
		"water_jar":
			var stamina_values: Array[float] = []
			var stability_values: Array[float] = []
			for raw_beast in RACE_BEASTS:
				stamina_values.append(float(raw_beast["stamina"]))
				stability_values.append(float(raw_beast["stability"]))
			var cruise := float(_race_stage_bases(beast)[1])
			insight = "%s耐力第%d、稳定第%d，巡航基础 %.1f。" % [str(beast["name"]), _descending_rank(float(beast["stamina"]), stamina_values), _descending_rank(float(beast["stability"]), stability_values), cruise]
		"river":
			var terrain_values: Array[float] = []
			for raw_beast in RACE_BEASTS:
				terrain_values.append(float(_race_stage_bases(raw_beast)[2]))
			var terrain := float(_race_stage_bases(beast)[2])
			insight = "%s地形段基础 %.1f，场内列第%d；赛道适性为%d。" % [str(beast["name"]), terrain, _descending_rank(terrain, terrain_values), int(beast["course"])]
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
	var selected_beast_id := str(RACE_BEASTS[beast_index]["id"])
	add_npc_memory("aqiu", {
		"memory_id": "supported_%s" % selected_beast_id,
		"type": "race_support",
		"importance": 3 if selected_beast_id == "cloudfin" else 2,
		"summary": "你在逐风竞速中选择支持%s，结果为第%d名。" % [str(RACE_BEASTS[beast_index]["name"]), place],
		"relationship_delta": 2 if selected_beast_id == "cloudfin" else 0,
		"effects": {"race_support": 2 if selected_beast_id == "cloudfin" else 1, "dialogue_warmth": 1}
	})
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
	var first_seat_after_dealer := _next_table_seat(int(poker["dealer_seat"]))
	var first_actor := _next_needing_seat(posmod(first_seat_after_dealer - 1, 6))
	poker["first_actor_seat"] = first_actor
	poker["first_action_index"] = first_actor - 1 if first_actor > 0 else -1
	poker["current_actor"] = first_actor
	var first_actor_name := _seat_name(first_actor) if first_actor >= 0 else "无人仍可行动"
	poker["action_log"].append("进入%s，首位行动：%s。" % [poker_stage_name(), first_actor_name])
	_append_oracle_event("stage_opened", {"stage": poker_stage_name(), "visible_community": _oracle_cards_for_record(poker_visible_community()), "pot": _poker_total_committed(), "first_actor": first_actor_name})


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
	var npc_id := str(ORACLE_NPC_IDS[npc_index])
	var remembered_courage := float(npc_memory_effect(npc_id, "poker_courage")) * 0.01 if NPCS.has(npc_id) else 0.0
	var courage := strength + style_courage + position_bonus + remembered_courage
	if to_call > 0:
		var is_opening_blind_call := int(poker.get("stage", 0)) == 0 and int(poker.get("current_bet", 0)) == int(poker.get("big_blind", 2)) and to_call <= int(poker.get("big_blind", 2))
		if is_opening_blind_call:
			var base_fold := 0.20 if style == "潮汐型" else (0.34 if style == "礁石型" else 0.27)
			var position := posmod(seat_index - int(poker["dealer_seat"]), 6)
			var position_adjust := 0.06 if position == 3 else (0.02 if position == 4 else (-0.04 if position in [0, 5] else 0.03))
			var hand_adjust := clampf((0.29 - strength) * 0.55, -0.10, 0.10)
			var opening_fold_chance := clampf(base_fold + position_adjust + hand_adjust - remembered_courage, 0.08, 0.48)
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
	if not poker_session_tutorial:
		normal_poker_completed = true
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
	_record_poker_social_memories(outcome, bank_net)
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
