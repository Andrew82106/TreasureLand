class_name ShareCatalog
extends RefCounted

const UNLOCK_ACCOUNT_WEALTH := 20000
const MARKET_CLOSE_TIDE := 10
const TRADE_FEE_RATE := 0.01
const MAX_DAILY_CHANGE := 0.12
const CONSERVATIVE_LIQUIDATION_RATE := 0.98
const OVERNIGHT_BUY_RESERVE_RATE := 1.13

const COMPANIES := {
	"bluefin": {
		"name": "蓝鳍渔业",
		"short_name": "蓝鳍",
		"sector": "渔获、餐厅与加工",
		"base_price": 100,
		"total_shares": 1000,
		"player_cap": 600,
		"target_profit": 10000,
		"color": "64c6c8",
		"description": "采购玩家与NPC鱼获，向餐厅、居民和加工坊供货。鱼价上涨可能意味着需求旺盛，也可能意味着缺货和成本上升。"
	},
	"wayfarer": {
		"name": "万象行运",
		"short_name": "行运",
		"sector": "造物研究与岛内运输",
		"base_price": 140,
		"total_shares": 1000,
		"player_cap": 600,
		"target_profit": 4500,
		"color": "d9ad68",
		"description": "承接造物实验后的器具、材料和知识运输。新关系增加业务，强风、重复空跑和事故则抬高成本。"
	},
	"windring": {
		"name": "逐风联合会",
		"short_name": "逐风",
		"sector": "赛事组织与赛道服务",
		"base_price": 180,
		"total_shares": 1000,
		"player_cap": 600,
		"target_profit": 2000,
		"color": "91d59e",
		"description": "经营逐风赛事、票务和赛道服务。活跃票池增加收入，恶劣海风、低到场和赛事维护会侵蚀利润。"
	}
}


static func company_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in COMPANIES.keys():
		result.append(str(raw_id))
	result.sort()
	return result


static func company(company_id: String) -> Dictionary:
	var raw = COMPANIES.get(company_id, {})
	return raw.duplicate(true) if raw is Dictionary else {}
