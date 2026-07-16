extends SceneTree

const GameStateScript := preload("res://scripts/game_state.gd")
const NpcCatalogScript := preload("res://scripts/npc_catalog.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_catalog_contract()
	_test_relationship_memory_and_topics()
	_test_requests_sharing_and_deep_talk()
	_test_schedule_services_and_residents()
	_test_save_round_trip()
	print("NPC SOCIAL SYSTEM TEST PASS")
	quit(0)


func _state():
	var state = GameStateScript.new()
	state.recording_enabled = false
	return state


func _test_catalog_contract() -> void:
	assert(NpcCatalogScript.CORE.size() == 6, "首版必须有6名核心NPC。")
	assert(NpcCatalogScript.RESIDENTS.size() >= 5 and NpcCatalogScript.RESIDENTS.size() <= 8, "首版必须有5—8名环境居民。")
	for npc_id in NpcCatalogScript.core_ids():
		var profile := NpcCatalogScript.core_profile(npc_id)
		assert(profile.get("dialogue", []).size() >= 8, "每名核心NPC至少需要8条普通对话：%s" % npc_id)
		assert(profile.get("reactions", {}).size() >= 3, "每名核心NPC至少需要3条关系反应：%s" % npc_id)
		assert(not profile.get("request", {}).is_empty(), "每名核心NPC必须有一个基础委托：%s" % npc_id)
		assert(profile.get("topics", []).size() >= 3, "每名核心NPC必须同时提供事实、消息或观点话题：%s" % npc_id)
		for phase in NpcCatalogScript.PHASES:
			assert(not NpcCatalogScript.schedule_entry(npc_id, phase).is_empty(), "每名核心NPC必须覆盖四时段日程：%s/%s" % [npc_id, phase])


func _test_relationship_memory_and_topics() -> void:
	var state = _state()
	state.relationships["old_joe"] = -95
	assert(state.adjust_relationship("old_joe", -20) == -100, "关系分数必须在-100封底。")
	assert(state.relationship_state("old_joe") == "疏远", "低于-19必须进入疏远。")
	assert(state.adjust_relationship("old_joe", 250) == 100 and state.relationship_state("old_joe") == "信任", "关系分数必须在100封顶并进入信任。")

	for index in range(7):
		state.add_npc_memory("mia", {
			"memory_id": "small_%d" % index,
			"type": "observation",
			"importance": 1,
			"summary": "短期记录%d" % index,
			"effects": {}
		})
	assert(state.npc_recent_memories("mia").size() == 5, "每名核心NPC最近记忆必须严格限制为5条。")

	state.add_npc_memory("mia", {
		"memory_id": "repeated_record",
		"type": "record_fish",
		"importance": 3,
		"summary": "玩家反复提供可核实的海生纪录。",
		"relationship_delta": 4,
		"effects": {"private_topic_access": 1, "dialogue_warmth": 2}
	})
	var score_after_first := int(state.relationships["mia"])
	state.add_npc_memory("mia", {
		"memory_id": "repeated_record",
		"type": "record_fish",
		"importance": 3,
		"summary": "玩家反复提供可核实的海生纪录。",
		"relationship_delta": 4,
		"effects": {"private_topic_access": 1, "dialogue_warmth": 2}
	})
	assert(int(state.relationships["mia"]) == score_after_first, "同一记忆更新不能重复发放关系变化。")
	assert(state.npc_long_memories("mia").size() == 1, "重复的重要短期记忆必须沉淀为长期记忆。")
	assert(state.npc_memory_effect("mia", "private_topic_access") == 1, "长期记忆必须产生可查询的行为影响。")

	for index in range(3):
		state.add_npc_memory("mia", {
			"memory_id": "major_%d" % index,
			"type": "major",
			"importance": 5,
			"persistent": true,
			"summary": "重大长期记录%d" % index,
			"effects": {"dialogue_warmth": 1}
		})
	assert(state.npc_long_memories("mia").size() == 2, "每名核心NPC长期记忆必须严格限制为2条。")
	var dedup_state = _state()
	dedup_state.add_npc_memory("aqiu", {
		"memory_id": "support_once",
		"importance": 2,
		"summary": "只应结算一次的支持。",
		"relationship_delta": 5,
		"effects": {}
	})
	var dedup_score: int = int(dedup_state.relationships["aqiu"])
	for index in range(8):
		dedup_state.add_npc_memory("aqiu", {
			"memory_id": "evict_%d" % index,
			"importance": 5,
			"persistent": true,
			"summary": "用于淘汰旧记忆%d" % index,
			"effects": {}
		})
	dedup_state.add_npc_memory("aqiu", {
		"memory_id": "support_once",
		"importance": 2,
		"summary": "即使已退出可见记忆，也不能再次结算。",
		"relationship_delta": 5,
		"effects": {}
	})
	assert(int(dedup_state.relationships["aqiu"]) == dedup_score, "记忆被短期和长期列表淘汰后，同一memory_id仍不能重复发放关系变化。")

	var private_before := state.npc_topics("granny").any(func(topic): return str(topic.get("id", "")) == "tower_memory")
	assert(not private_before, "陌生或熟悉状态不应自动公开私人话题。")
	state.add_npc_memory("granny", {
		"memory_id": "trusted_method",
		"type": "request_completed",
		"importance": 4,
		"summary": "玩家完成了守望人的重要请求。",
		"effects": {"private_topic_access": 1}
	})
	assert(state.npc_topics("granny").any(func(topic): return str(topic.get("id", "")) == "tower_memory"), "长期记忆影响必须能够开放私人话题。")

	var cash_before: int = state.cash
	var relationship_before := int(state.relationships["granny"])
	var first_read := state.npc_ask("granny", "synthesis_basics")
	var second_read := state.npc_ask("granny", "synthesis_basics")
	assert(bool(first_read.get("ok", false)) and not bool(first_read.get("repeat", true)), "首次询问必须生成带来源的话题记录。")
	assert(bool(second_read.get("repeat", false)), "同一时段重复询问必须明确标记重复。")
	assert(state.cash == cash_before and int(state.relationships["granny"]) == relationship_before, "重复询问不得生成金贝或关系奖励。")
	assert(str(first_read.get("source", "")).length() > 0 and str(first_read.get("valid_until", "")).length() > 0, "非空话题必须记录来源与有效期。")


func _test_requests_sharing_and_deep_talk() -> void:
	var state = _state()
	var accepted := state.accept_npc_request("shopkeeper")
	assert(bool(accepted.get("ok", false)), "阿拓的基础委托必须能够接受。")
	assert(not bool(state.npc_request_info("shopkeeper").get("condition_met", true)), "未发现二阶万物前不能交付阿拓委托。")
	state.discover_item("steam", "test")
	assert(bool(state.npc_request_info("shopkeeper").get("condition_met", false)), "发现二阶万物后必须满足阿拓委托。")
	var discounts_before: int = state.synthesis_discount_uses
	var delivered := state.turn_in_npc_request("shopkeeper")
	assert(bool(delivered.get("ok", false)) and state.synthesis_discount_uses == discounts_before + 2, "通用委托必须原子结算唯一奖励。")
	assert(not bool(state.turn_in_npc_request("shopkeeper").get("ok", true)), "已完成委托不能重复领取奖励。")
	assert(state.npc_long_memories("shopkeeper").any(func(memory): return str(memory.get("type", "")) == "request_completed"), "完成委托必须写入长期人物记忆。")

	var share_score := int(state.relationships["granny"])
	var shared := state.share_creation_with_npc("granny", "steam")
	assert(bool(shared.get("ok", false)) and int(state.relationships["granny"]) >= share_score, "永久万物必须能向NPC分享且不被消耗。")
	assert(state.is_discovered("steam"), "分享造物不能移除永久发现。")
	var repeated := state.share_creation_with_npc("granny", "steam")
	assert(bool(repeated.get("repeat", false)), "同一万物向同一NPC重复分享必须被识别。")

	state.tide = 1
	state.tide_progress = 0.0
	state.relationships["granny"] = 10
	var deep := state.npc_deep_talk("granny")
	assert(bool(deep.get("ok", false)) and is_equal_approx(float(deep.get("time_cost", 0.0)), 0.5), "熟悉状态深入交谈必须统一结算0.5潮刻。")
	assert(state.tide == 1 and is_equal_approx(state.tide_progress, 0.5), "深入交谈只能通过统一时间入口推进一次。")
	var progress_after: float = state.tide_progress
	assert(not bool(state.npc_deep_talk("granny").get("ok", true)) and is_equal_approx(state.tide_progress, progress_after), "同一人物同一天不能重复结算深入交谈。")


func _test_schedule_services_and_residents() -> void:
	var state = _state()
	state.tide = 1
	assert(str(state.npc_schedule_entry("granny").get("area", "")) == "漂流湾", "榕奶奶清晨必须在漂流湾造化盆。")
	state.tide = 5
	assert(str(state.npc_schedule_entry("granny").get("area", "")) == "椰影街", "榕奶奶白天必须移动到椰影茶摊。")
	state.tide = 9
	assert(not state.npc_is_available("milo"), "未完成正常牌会前米洛不能提前出现。")
	state.normal_poker_completed = true
	assert(state.npc_is_available("milo"), "完成正常牌会后米洛必须按傍晚日程出现。")
	state.tide = 13
	state.relationships["shopkeeper"] = -100
	var shop_schedule := state.npc_schedule_entry("shopkeeper")
	assert(not bool(shop_schedule.get("available", true)) and str(shop_schedule.get("substitute", "")).length() > 0, "阿拓夜间离店时必须标明代班人员。")
	assert(state.npc_profile("shopkeeper").get("services", []).has("shop"), "疏远或离店不能删除公共研究商店服务。")

	state.meet_npc("mia")
	var map_entries := state.npc_map_entries()
	assert(map_entries.any(func(entry): return str(entry.get("id", "")) == "granny"), "默认认识的榕奶奶必须出现在地图人物数据中。")
	assert(map_entries.any(func(entry): return str(entry.get("id", "")) == "mia"), "正式认识米娅后必须进入地图人物数据。")
	assert(not map_entries.any(func(entry): return str(entry.get("id", "")) == "old_joe"), "未认识人物不能提前进入地图追踪。")
	assert(state.environment_resident_entries().size() == NpcCatalogScript.RESIDENTS.size(), "四时段运行数据必须覆盖全部环境居民。")
	var relationship_count: int = state.relationships.size()
	assert(state.add_npc_memory("resident_fisher", {"summary": "不应写入"}).is_empty(), "环境居民不能写入核心长期记忆。")
	assert(state.relationships.size() == relationship_count, "环境居民不能生成独立关系线。")


func _test_save_round_trip() -> void:
	var state = _state()
	state.meet_npc("mia")
	state.accept_npc_request("mia")
	state.npc_ask("mia", "public_report")
	state.add_npc_memory("mia", {
		"memory_id": "save_memory",
		"type": "major",
		"importance": 4,
		"summary": "需要跨存档保留的记忆。",
		"relationship_delta": 2,
		"effects": {"dialogue_warmth": 3}
	})
	var save_data := state.build_save_data({"current_area": "椰影街"})
	assert(int(save_data.get("version", 0)) == state.SAVE_VERSION, "新社交字段必须进入当前存档版本。")
	var restored = _state()
	var result := restored.restore_save_data(save_data)
	assert(bool(result.get("ok", false)), "包含社交状态的存档必须能够读取。")
	assert(bool(restored.known_npcs.get("mia", false)), "已认识人物必须跨存档保留。")
	assert(str(restored.npc_request_info("mia").get("state", "")) == "active", "人物委托状态必须跨存档保留。")
	assert(restored.npc_long_memories("mia").any(func(memory): return str(memory.get("memory_id", "")) == "save_memory"), "长期记忆必须跨存档保留。")
	assert(restored.npc_memory_effect("mia", "dialogue_warmth") >= 3, "长期记忆行为数值必须跨存档保留。")
	var restored_score: int = int(restored.relationships["mia"])
	restored.add_npc_memory("mia", {"memory_id": "save_memory", "importance": 4, "summary": "重复", "relationship_delta": 2, "effects": {"dialogue_warmth": 3}})
	assert(int(restored.relationships["mia"]) == restored_score, "关系奖励去重标记必须跨存档保留。")

	var legacy = _state()
	var legacy_result := legacy.restore_save_data({
		"version": 1,
		"state": {
			"relationships": {"granny": 10},
			"memories": {"granny": ["旧存档中的字符串记忆"]},
			"poker_completed": true
		},
		"world": {}
	})
	assert(bool(legacy_result.get("ok", false)), "版本1存档必须迁移到版本2社交结构。")
	assert(legacy.npc_recent_memories("granny").size() == 1 and str(legacy.npc_recent_memories("granny")[0].get("summary", "")) == "旧存档中的字符串记忆", "旧字符串记忆必须无损迁移为结构化最近记忆。")
	assert(legacy.memories.get("granny", {}) is Dictionary and legacy.npc_long_memories("granny").is_empty(), "旧存档迁移后必须具有5短2长容器。")
