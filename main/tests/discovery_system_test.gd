extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const MainScene = preload("res://main.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_permanent_pair_discovery()
	_test_invalid_and_same_item_pairs()
	_test_cost_and_discount_contract()
	_test_knowledge_shop()
	_test_request_uses_discovery_without_consumption()
	_test_race_aids_are_information_only()
	await _test_discovery_ui_contract()
	print("DISCOVERY SYSTEM TEST PASS: permanent pairs, services, race aids and mirrored UI")
	quit(0)


func _test_permanent_pair_discovery() -> void:
	var state = GameStateScript.new()
	var initial_ids := state.discovered_item_ids()
	assert(initial_ids.size() == 6 and initial_ids.has("water") and initial_ids.has("wood"), "开局必须永久掌握六种基础万物")
	var cash_before := int(state.cash)
	var result: Dictionary = state.synthesize_pair("water", "earth")
	assert(bool(result.get("success", false)) and str(result.get("output", "")) == "mud", "水与土必须发现泥")
	assert(state.cash == cash_before - 2, "两个0阶万物的首次实验必须支付2金贝")
	assert(state.is_discovered("water") and state.is_discovered("earth") and state.is_discovered("mud"), "合成双方与结果都必须永久保留")
	var discovered_after := state.discovered_item_ids().size()
	var cash_after := int(state.cash)
	var reversed: Dictionary = state.synthesize_pair("earth", "water")
	assert(bool(reversed.get("repeat", false)) and int(reversed.get("cost_paid", -1)) == 0, "左右交换必须命中同一历史组合并免费查看")
	assert(state.cash == cash_after and state.discovered_item_ids().size() == discovered_after, "历史组合不得重复扣款或重复发现")
	var chained: Dictionary = state.synthesize_pair("mud", "fire")
	assert(bool(chained.get("success", false)) and state.is_discovered("pottery"), "新发现必须立即能够参与下一层组合")
	assert(int(chained.get("cost_paid", 0)) == 5, "包含1阶万物的首次实验必须支付5金贝")


func _test_invalid_and_same_item_pairs() -> void:
	var state = GameStateScript.new()
	var invalid: Dictionary = state.synthesize_pair("water", "wood")
	assert(bool(invalid.get("ok", false)) and not bool(invalid.get("success", true)), "无配方的二元组合必须形成明确失败记录")
	assert(not str(invalid.get("failure_reason", "")).is_empty() and not str(invalid.get("suggestion", "")).is_empty(), "失败必须说明关系并给出方向提示")
	assert(state.is_discovered("water") and state.is_discovered("wood"), "失败不得移除任何万物")
	var cash_after := int(state.cash)
	var repeat: Dictionary = state.synthesize_pair("wood", "water")
	assert(bool(repeat.get("repeat", false)) and state.cash == cash_after, "无效组合左右交换后也必须免费显示历史")
	var same: Dictionary = state.synthesize_pair("stone", "stone")
	assert(bool(same.get("ok", false)) and not bool(same.get("success", true)), "左右两侧必须允许选择同一个万物")
	assert(str(same.get("failure_title", "")).contains("同源"), "同物无效组合必须提供专门反馈")
	var rejected: Dictionary = state.synthesize(["water", "earth", "fire"])
	assert(not bool(rejected.get("ok", true)), "造化盆必须严格只接受两个输入")


func _test_cost_and_discount_contract() -> void:
	var poor = GameStateScript.new()
	poor.cash = 1
	var blocked: Dictionary = poor.synthesize_pair("water", "earth")
	assert(not bool(blocked.get("ok", true)) and poor.attempted_pairs.is_empty(), "金贝不足时不得扣款或建立尝试记录")

	var state = GameStateScript.new()
	var bought: Dictionary = state.buy_shop_offer("experiment_discount")
	assert(bool(bought.get("ok", false)) and state.synthesis_discount_uses == 3, "折扣服务必须一次增加三次")
	var cash_before := int(state.cash)
	var discounted: Dictionary = state.synthesize_pair("water", "stone")
	assert(int(discounted.get("cost_paid", 0)) == 1 and state.cash == cash_before - 1, "2金贝实验应用半价后必须向上取整为1金贝")
	assert(state.synthesis_discount_uses == 2, "只有真正的新组合实验才消耗一次折扣")
	state.synthesize_pair("stone", "water")
	assert(state.synthesis_discount_uses == 2, "查看历史组合不得消耗折扣")
	state.synthesis_discount_uses = 4
	var cash_with_partial_space := int(state.cash)
	assert(not bool(state.buy_shop_offer("experiment_discount").get("ok", true)) and state.cash == cash_with_partial_space, "三次折扣必须整组交付，剩余空间不足时不得扣款")
	state.synthesis_discount_uses = 6
	var cash_at_cap := int(state.cash)
	assert(not bool(state.buy_shop_offer("experiment_discount").get("ok", true)) and state.cash == cash_at_cap, "折扣达到六次上限后不得继续扣款")


func _test_knowledge_shop() -> void:
	var state = GameStateScript.new()
	assert(not state.is_discovered("metal"), "金工知识购买前不得提前发现金")
	var cash_before := int(state.cash)
	var learned: Dictionary = state.buy_shop_offer("metal_knowledge")
	assert(bool(learned.get("ok", false)) and state.is_discovered("metal"), "购买金工拓片必须立即永久发现金")
	assert(state.cash == cash_before - 35, "金工拓片必须准确扣除35金贝")
	var cash_after := int(state.cash)
	assert(not bool(state.buy_shop_offer("metal_knowledge").get("ok", true)) and state.cash == cash_after, "永久知识不得重复购买或重复扣款")
	var hint_before := int(state.cash)
	var hint: Dictionary = state.buy_shop_offer("recipe_hint")
	assert(bool(hint.get("ok", false)) and not str(hint.get("delivery", "")).is_empty(), "线索服务必须先找到可交付内容")
	assert(state.cash == hint_before - 12 and state.last_shop_hint == str(hint.get("delivery", "")), "线索交付后必须准确扣款并保留最近线索")
	var first_hint: String = str(state.last_shop_hint)
	var second_hint: Dictionary = state.buy_shop_offer("recipe_hint")
	assert(bool(second_hint.get("ok", false)) and state.last_shop_hint != first_hint, "连续购买不得交付同一条配方线索")
	for raw_offer in state.shop_offers():
		var offer: Dictionary = raw_offer
		assert(not offer.has("stock") and not offer.has("amount"), "商店目录不得重新引入万物库存或购买数量")


func _test_request_uses_discovery_without_consumption() -> void:
	var state = GameStateScript.new()
	state.discover_item("fish", "test")
	state.discover_item("salt", "test")
	var crafted: Dictionary = state.synthesize_pair("fish", "salt")
	assert(bool(crafted.get("success", false)) and state.is_discovered("salted_fish"), "鱼与盐必须发现咸鱼保存方法")
	var cash_before := int(state.cash)
	var delivered: Dictionary = state.turn_in_aqiu_request()
	assert(bool(delivered.get("ok", false)) and state.cash == cash_before + 80, "掌握咸鱼后必须能够完成阿葵委托")
	assert(state.is_discovered("salted_fish"), "完成委托不得消耗永久万物")


func _test_race_aids_are_information_only() -> void:
	var locked = GameStateScript.new()
	var blocked: Dictionary = locked.run_race(0, "独胜", 10, "tool")
	assert(not bool(blocked.get("ok", true)) and locked.cash == 120, "未发现的竞速造物不得使用或扣款")

	var aided = GameStateScript.new()
	var plain = GameStateScript.new()
	for state in [aided, plain]:
		state.cash = 1000
		state.free_race_ticket = 0
		state.weather = "强风"
		state.rng.seed = 778899
	aided.discover_item("tool", "test")
	var info: Dictionary = aided.race_aid_info("tool", 0)
	assert(bool(info.get("ok", false)) and not str(info.get("insight", "")).is_empty(), "分段量具必须在下注前提供完整情报")
	var aided_result: Dictionary = aided.run_race(0, "独胜", 100, "tool")
	var plain_result: Dictionary = plain.run_race(0, "独胜", 100)
	assert(_race_order(aided_result) == _race_order(plain_result), "同一随机种子下信息造物不得改变赛果")
	assert(int(aided_result.get("aid_fee", 0)) == 4 and aided.cash == plain.cash - 4, "分段量具只应额外收取4金贝部署费")
	assert(aided.is_discovered("tool"), "竞速使用后造物必须永久保留")
	for aid_id in ["tool", "sail", "calm_incense", "wind_bell"]:
		aided.discover_item(aid_id, "test")
		var aid_info: Dictionary = aided.race_aid_info(aid_id, 4)
		assert(bool(aid_info.get("ok", false)) and not str(aid_info.get("insight", "")).is_empty(), "每种首版竞速造物必须提供独立可读情报")


func _test_discovery_ui_contract() -> void:
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene._open_synthesis()
	assert(scene.synthesis_left_library != null and scene.synthesis_right_library != null, "造化盆必须建立左右两个永久万物栏")
	assert(scene.synthesis_left_library.get_child_count() == scene.synthesis_right_library.get_child_count(), "左右栏必须读取完全相同的发现集合")
	assert(scene.synthesis_stage != null and _tree_contains_text(scene.synthesis_stage, "新组合实验费") == false, "未选择双方时中央舞台必须等待选择而不是提前扣费")
	scene._select_synthesis_item("left", "water")
	scene._select_synthesis_item("right", "earth")
	assert(_tree_contains_text(scene.synthesis_stage, "新组合实验费 2金贝"), "中央舞台必须在确认前显示准确实验费")
	assert(not _tree_contains_text(scene.modal_body, "数量") and not _tree_contains_text(scene.modal_body, "批量制作"), "造化盆界面不得保留万物数量和批量制作")
	scene._open_shop()
	assert(_tree_contains_text(scene.modal_body, "永久知识与研究服务"), "商店必须明确展示知识与服务定位")
	assert(not _tree_contains_text(scene.modal_body, "出售") and not _tree_contains_text(scene.modal_body, "库存"), "商店界面不得保留出售与库存区")
	scene.game.discover_item("tool", "test")
	scene._open_race()
	assert(scene.race_aid_option.item_count == 2, "逐风竞速必须显示不使用与已发现分段量具两个选项")
	scene.race_aid_option.select(1)
	scene._update_race_preview(1)
	assert(scene.race_preview_label.text.contains("分段量具") and scene.race_preview_label.text.contains("起步"), "选择竞速造物后必须显式展示新增情报")
	scene.free()


func _race_order(result: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_entry in result.get("results", []):
		names.append(str(raw_entry["name"]))
	return names


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and str(node.text).contains(needle):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false
