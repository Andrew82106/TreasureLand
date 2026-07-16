extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const MainScene = preload("res://main.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_four_tier_recipe_graph()
	_test_permanent_pair_costs_and_failures()
	_test_shop_only_supports_research()
	_test_request_uses_water_jar_without_consumption()
	_test_race_insights_are_information_only()
	await _test_full_screen_synthesis_ui()
	print("DISCOVERY SYSTEM TEST PASS: 72 items, 69 relations, four tiers and full-screen basin")
	quit(0)


func _test_four_tier_recipe_graph() -> void:
	var state = GameStateScript.new()
	var initial_ids: Array[String] = state.discovered_item_ids()
	assert(initial_ids.size() == 3 and initial_ids.has("water") and initial_ids.has("fire") and initial_ids.has("earth"), "开局图鉴必须严格只有水、火、土")
	assert(state.ITEMS.size() == 72 and state.RECIPES.size() == 69, "四阶原型必须固定为72个万物和69条配方")
	var item_counts := {1: 0, 2: 0, 3: 0, 4: 0}
	var recipe_counts := {2: 0, 3: 0, 4: 0}
	for raw_id in state.ITEMS.keys():
		var item_id := str(raw_id)
		var tier := state.item_tier(item_id)
		assert(item_counts.has(tier), "所有万物必须属于一至四阶")
		var art_source := state.item_art_source(item_id)
		var art_index := state.item_art_index(item_id)
		assert(art_source == "material" or art_source == "creation", "每个万物必须映射到受支持的插图图集")
		assert(art_index >= 0 and art_index < (9 if art_source == "creation" else 16), "每个万物的插图索引必须位于对应图集范围内")
		item_counts[tier] = int(item_counts[tier]) + 1
	assert(item_counts == {1: 3, 2: 3, 3: 11, 4: 55}, "四阶规模必须为3→3→11→55")

	var pair_keys := {}
	var outputs := {}
	for raw_recipe in state.RECIPES:
		var recipe: Dictionary = raw_recipe
		var inputs: Array = recipe["inputs"]
		var pair_key: String = state.synthesis_pair_key(str(inputs[0]), str(inputs[1]))
		var output_id := str(recipe["output"])
		var output_tier := state.item_tier(output_id)
		assert(not pair_keys.has(pair_key), "每个无序输入组合只能存在一条配方")
		assert(not outputs.has(output_id), "四阶原型中每个结果必须只有一个固定来源")
		assert(not str(recipe.get("relation", "")).is_empty() and not str(recipe.get("logic", "")).is_empty(), "每条配方必须固定关系类型与内在逻辑")
		assert(state.item_tier(str(inputs[0])) < output_tier and state.item_tier(str(inputs[1])) < output_tier, "结果必须由更早阶层的两个万物生成")
		recipe_counts[output_tier] = int(recipe_counts[output_tier]) + 1
		pair_keys[pair_key] = true
		outputs[output_id] = true
	assert(recipe_counts == {2: 3, 3: 11, 4: 55}, "每个非根万物必须恰好对应一条成功关系")
	assert(int(recipe_counts[2]) == _ceil_relation_count(3, 1.0), "一到二阶必须为100%组合覆盖")
	assert(int(recipe_counts[3]) == _ceil_relation_count(6, 0.70), "二到三阶必须为70%组合覆盖并向上取整")
	assert(int(recipe_counts[4]) == _ceil_relation_count(17, 0.40), "三到四阶必须为40%组合覆盖并向上取整")

	for tier in range(1, 4):
		for raw_id in state.ITEMS.keys():
			var item_id := str(raw_id)
			if state.item_tier(item_id) != tier:
				continue
			var used_next := false
			for raw_recipe in state.RECIPES:
				var recipe: Dictionary = raw_recipe
				if state.item_tier(str(recipe["output"])) == tier + 1 and recipe["inputs"].has(item_id):
					used_next = true
					break
			assert(used_next, "%d阶万物%s必须参与下一阶关系" % [tier, state.item_name(item_id)])

	state.cash = 2000
	var first_layer_pairs := [["water", "fire", "steam"], ["water", "earth", "mud"], ["fire", "earth", "lava"]]
	for pair in first_layer_pairs:
		var result: Dictionary = state.synthesize_pair(str(pair[0]), str(pair[1]))
		assert(bool(result.get("success", false)) and str(result.get("output", "")) == str(pair[2]), "三个根万物的每一组不同配对都必须成功")
	assert(int(state.tier_discovery_progress(2)["found"]) == 3, "完成三个根关系后必须点亮全部二阶万物")

	for raw_recipe in state.RECIPES:
		var recipe: Dictionary = raw_recipe
		var output_id := str(recipe["output"])
		if state.is_discovered(output_id):
			continue
		var inputs: Array = recipe["inputs"]
		assert(state.is_discovered(str(inputs[0])) and state.is_discovered(str(inputs[1])), "按阶推进时配方输入必须已经发现")
		var result: Dictionary = state.synthesize_pair(str(inputs[0]), str(inputs[1]))
		assert(bool(result.get("success", false)) and state.is_discovered(output_id), "完整谱系必须能够按固定关系推进")
	assert(state.discovered_item_ids().size() == 72 and state.discovered_recipe_count() == 69, "走完69条关系后必须完成72个万物的四阶图鉴")
	var terminal_cash: int = int(state.cash)
	var terminal: Dictionary = state.synthesize_pair("rain", "river")
	assert(not bool(terminal.get("ok", true)) and bool(terminal.get("terminal", false)), "四阶万物必须作为当前版本的谱系终点")
	assert(state.cash == terminal_cash and state.synthesis_attempt_record("rain", "river").is_empty(), "未开放的五阶选择不得扣款或写入失败记录")


func _test_permanent_pair_costs_and_failures() -> void:
	var state = GameStateScript.new()
	var cash_before := int(state.cash)
	var steam: Dictionary = state.synthesize_pair("water", "fire")
	assert(bool(steam.get("success", false)) and int(steam.get("cost_paid", 0)) == 2, "一阶输入首次实验必须支付2金贝")
	assert(state.is_discovered("water") and state.is_discovered("fire") and state.is_discovered("steam"), "输入和结果必须永久保留")
	var discovered_after := state.discovered_item_ids().size()
	var repeated: Dictionary = state.synthesize_pair("fire", "water")
	assert(bool(repeated.get("repeat", false)) and int(repeated.get("cost_paid", -1)) == 0, "左右交换必须命中同一历史组合并免费复查")
	assert(state.cash == cash_before - 2 and state.discovered_item_ids().size() == discovered_after, "复查不得重复扣款或重复发现")

	var invalid_cash := int(state.cash)
	var same: Dictionary = state.synthesize_pair("earth", "earth")
	assert(bool(same.get("ok", false)) and not bool(same.get("success", true)), "同物组合允许提交并形成明确失败记录")
	assert(str(same.get("failure_title", "")).contains("同源") and state.cash == invalid_cash - 2, "同物失败必须提供专门反馈并按首次尝试收费")
	var failed_cash := int(state.cash)
	var same_repeat: Dictionary = state.synthesize_pair("earth", "earth")
	assert(bool(same_repeat.get("repeat", false)) and state.cash == failed_cash, "失败关系也必须永久免费复查")

	var poor = GameStateScript.new()
	poor.cash = 1
	var blocked: Dictionary = poor.synthesize_pair("water", "earth")
	assert(not bool(blocked.get("ok", true)) and poor.attempted_pairs.is_empty(), "金贝不足时不得扣款或建立关系记录")

	var discount_state = GameStateScript.new()
	assert(bool(discount_state.buy_shop_offer("experiment_discount").get("ok", false)), "研究商店必须能交付三次实验折扣")
	var discounted: Dictionary = discount_state.synthesize_pair("water", "fire")
	assert(int(discounted.get("cost_paid", 0)) == 1 and discount_state.synthesis_discount_uses == 2, "2金贝实验半价后必须向上取整为1并消耗一次折扣")


func _test_shop_only_supports_research() -> void:
	var state = GameStateScript.new()
	for raw_offer in state.shop_offers():
		var offer: Dictionary = raw_offer
		assert(["hint", "discount"].has(str(offer["type"])), "商店只能提供线索和实验折扣，不得绕过谱系出售万物")
		assert(not offer.has("unlock") and not offer.has("stock") and not offer.has("amount"), "商店服务不得包含直接解锁或库存数量字段")
	var discovered_before := state.discovered_item_ids().size()
	var hint_cash := int(state.cash)
	var hint: Dictionary = state.buy_shop_offer("recipe_hint")
	assert(bool(hint.get("ok", false)) and not str(hint.get("delivery", "")).is_empty(), "线索服务必须先找到可交付内容")
	assert(state.discovered_item_ids().size() == discovered_before and state.cash == hint_cash - 12, "购买线索只应扣款并交付方向，不得直接发现万物")
	assert(str(hint.get("delivery", "")).contains("关系") and str(hint.get("delivery", "")).contains("阶"), "商店线索必须说明关系语法和目标阶层")


func _test_request_uses_water_jar_without_consumption() -> void:
	var state = GameStateScript.new()
	state.cash = 500
	for pair in [["water", "earth"], ["mud", "fire"], ["pottery", "water"]]:
		var result: Dictionary = state.synthesize_pair(str(pair[0]), str(pair[1]))
		assert(bool(result.get("success", false)), "阿葵委托路径上的固定关系必须能够完成")
	assert(state.is_discovered("water_jar"), "陶器与水必须生成水罐")
	var cash_before := int(state.cash)
	var delivered: Dictionary = state.turn_in_aqiu_request()
	assert(bool(delivered.get("ok", false)) and state.cash == cash_before + 80, "发现水罐后必须能够完成阿葵委托")
	assert(state.is_discovered("water_jar"), "分享补水方法不得消耗永久水罐")


func _test_race_insights_are_information_only() -> void:
	var locked = GameStateScript.new()
	var blocked: Dictionary = locked.run_race(0, "独胜", 10, "rain")
	assert(not bool(blocked.get("ok", true)) and locked.cash == 120, "未发现的四阶竞速万物不得使用或扣款")

	var aided = GameStateScript.new()
	var plain = GameStateScript.new()
	for state in [aided, plain]:
		state.cash = 1000
		state.free_race_ticket = 0
		state.weather = "强风"
		state.rng.seed = 778899
	aided.discover_item("rain", "test")
	var info: Dictionary = aided.race_aid_info("rain", 0)
	assert(bool(info.get("ok", false)) and not str(info.get("insight", "")).is_empty(), "雨势推演必须在下注前提供天气适应信息")
	var aided_result: Dictionary = aided.run_race(0, "独胜", 100, "rain")
	var plain_result: Dictionary = plain.run_race(0, "独胜", 100)
	assert(_race_order(aided_result) == _race_order(plain_result), "同一随机种子下竞速研读不得改变赛果")
	assert(int(aided_result.get("aid_fee", 0)) == 4 and aided.cash == plain.cash - 4, "雨势推演只应额外收取4金贝服务费")
	for aid_id in ["rain", "thunderstorm", "water_jar", "river"]:
		aided.discover_item(aid_id, "test")
		var aid_info: Dictionary = aided.race_aid_info(aid_id, 4)
		assert(bool(aid_info.get("ok", false)) and not str(aid_info.get("insight", "")).is_empty(), "每种四阶竞速万物必须提供独立可读情报")


func _test_full_screen_synthesis_ui() -> void:
	root.size = Vector2i(1280, 720)
	var scene = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	scene._open_synthesis()
	await process_frame
	var table = scene.synthesis_table
	table.animation_speed_scale = 4.0
	assert(table.visible and not scene.modal_overlay.visible, "造化盆必须使用独立全屏页面而不是普通模态框")
	assert(table.page_root != null and table.page_root.size.round() == Vector2(1280, 720), "造化盆全屏根节点必须覆盖1280×720视口")
	assert(table.left_library != null and table.right_library != null, "独立页面必须建立左右两个万物图鉴")
	assert(table.left_library.get_child_count() == 3 and table.right_library.get_child_count() == 3, "开局左右图鉴都必须只显示水、火、土")
	assert(table.center_stage != null and not _has_ancestor_class(table.center_stage, "ScrollContainer"), "中央实验舞台必须固定且不能随图鉴滚动")
	assert(table.motion_layer != null and table.motion_layer.name == "SynthesisMotionLayer", "中央实验舞台必须提供独立且不改写玩法状态的动画层")
	for raw_recipe in table.game.RECIPES:
		var relation := str(raw_recipe.get("relation", ""))
		assert(table.RELATION_FAMILY_BY_LABEL.has(relation), "每一种真实合成关系都必须映射到明确的动画语法：%s" % relation)
	assert(_tree_contains_text(table.page_root, "1阶 3/3") and _tree_contains_text(table.page_root, "4阶 0/55"), "顶部必须显式展示四阶发现进度")
	var old_page: Control = table.page_root
	var water_button := _find_button(table.left_library, "水")
	var fire_button := _find_button(table.right_library, "火")
	assert(water_button != null and fire_button != null, "左右图鉴必须生成可操作的万物按钮")
	water_button.pressed.emit()
	fire_button.pressed.emit()
	assert(table.page_root == old_page and is_instance_valid(old_page), "选择信号期间不得同步释放当前造化盆界面")
	await process_frame
	assert(table.page_root == old_page and is_instance_valid(old_page), "信号结束后的安全帧内仍不得释放原界面")
	await process_frame
	assert(table.page_root != old_page and table.left_id == "water" and table.right_id == "fire", "选择完成后必须跨过完整安全帧并合并执行一次界面重建")
	assert(_tree_contains_text(table.center_stage, "首次尝试这段关系需要2金贝"), "中央舞台必须在提交前显示准确费用")
	var result_page: Control = table.page_root
	table.action_button.pressed.emit()
	await process_frame
	await process_frame
	assert(table.busy and table.motion_layer.get_child_count() >= 2, "真实提交按钮信号必须启动双材料汇聚演出")
	await create_timer(1.2).timeout
	await process_frame
	assert(table.page_root != result_page and table.game.is_discovered("steam"), "实验动画结束后必须延迟重建并安全显示新发现")
	table._show_graph()
	assert(table.graph_overlay.visible and _tree_contains_text(table.graph_overlay, "四阶原型共72个万物、69条固定关系"), "页面内必须提供可查询的四阶组合谱")
	table._hide_graph()
	assert(not _tree_contains_text(table.page_root, "物品数量") and not _tree_contains_text(table.page_root, "批量制作"), "独立页面不得出现数量背包或批量制作旧入口")
	table.request_close()
	assert(not table.visible and scene.player.controls_enabled, "退出造化盆后必须恢复岛上移动控制")
	scene.free()


func _race_order(result: Dictionary) -> Array[String]:
	var names: Array[String] = []
	for raw_entry in result.get("results", []):
		names.append(str(raw_entry["name"]))
	return names


func _ceil_relation_count(pool_size: int, coverage: float) -> int:
	return int(ceil(float(pool_size * (pool_size - 1)) * 0.5 * coverage))


func _tree_contains_text(node: Node, needle: String) -> bool:
	if (node is Label or node is Button) and str(node.text).contains(needle):
		return true
	for child in node.get_children():
		if _tree_contains_text(child, needle):
			return true
	return false


func _find_button(node: Node, exact_text: String) -> Button:
	if node is Button and str(node.text) == exact_text:
		return node
	for child in node.get_children():
		var found := _find_button(child, exact_text)
		if found != null:
			return found
	return null


func _has_ancestor_class(node: Node, class_name_value: String) -> bool:
	var current := node.get_parent()
	while current != null:
		if current.is_class(class_name_value):
			return true
		current = current.get_parent()
	return false
