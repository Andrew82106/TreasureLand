extends RefCounted
class_name NpcCatalog

const PHASES := ["清晨", "白天", "傍晚", "夜晚"]

const CORE := {
	"granny": {
		"name": "榕奶奶",
		"role": "万象塔守望人、茶摊主人",
		"color": "f3a6b9",
		"services": ["synthesis"],
		"dialogue": [
			"“万物不会被盆吃掉。真正留下来的，是你确认过的一段关系。”",
			"“别只盯着成功。一次未成，也会替你排除一条没有根基的路。”",
			"“水、火、土看着简单，岛上许多大东西都从这三样慢慢长出来。”",
			"“每次实验都要付一点金贝，是提醒你动手前先想想，不是拦着你好奇。”",
			"“造物被发现以后便一直属于图鉴，委托和比赛都拿不走它。”",
			"“若一条路暂时走不通，就换一边的万物。顺序会替你分清相近的关系。”",
			"“塔上的灯不是靠金贝点亮的，是靠岛民真正理解过的东西。”",
			"“今天的海风很直。适合慢慢试，不适合急着证明自己。”"
		],
		"reactions": {
			"疏远": "榕奶奶把茶盏放远了一点：“盆还可以用。至于别的话，等你愿意好好听时再说。”",
			"熟悉": "榕奶奶给你留了靠近造化盆的位置：“你已经会看结果了，接下来要学会看关系。”",
			"信任": "榕奶奶把塔上旧图的一角摊开：“我记得你走过的路，也愿意让你看看岛以前走错过什么。”"
		},
		"topics": [
			{"id": "synthesis_basics", "label": "造化盆与永久万物", "type": "公开事实", "source": "榕奶奶的造化盆说明", "private": false},
			{"id": "synthesis_direction", "label": "当前研究方向", "type": "有来源消息", "source": "榕奶奶依据你的图鉴观察", "private": false},
			{"id": "tower_memory", "label": "万象塔旧事", "type": "人物观点", "source": "榕奶奶的个人回忆", "private": true}
		],
		"request": {
			"id": "granny_first_relation",
			"title": "盆中的第一缕雾",
			"objective": "在万物图鉴中发现“蒸汽”，再向榕奶奶说明水与火的关系。",
			"hint": "让最容易彼此改变的两种根万物先相遇。",
			"condition": "discover_steam",
			"rewards": {"coins": 20, "relationship": 8}
		},
		"share_interest": ["天象", "气候", "原理"],
		"deep_talk": {
			"熟悉": "她讲起第一座造化盆：它最初不是生产工具，而是一种让争论可以被验证的公共器物。",
			"信任": "她承认万象塔也曾把错误关系写成真理。守望人的责任不是永远正确，而是让后来者能改正前人的结论。"
		},
		"schedule": {
			"清晨": {"area": "漂流湾", "location": "漂流湾造化盆", "activity": "照看造化盆", "position": Vector2(940, 535), "visual_position": Vector2(918, 555)},
			"白天": {"area": "椰影街", "location": "椰影茶摊", "activity": "为来客煮茶", "position": Vector2(1818, 1014), "visual_position": Vector2(1796, 1038)},
			"傍晚": {"area": "椰影街", "location": "椰影茶摊", "activity": "整理今日传闻", "position": Vector2(1818, 1014), "visual_position": Vector2(1796, 1038)},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊", "activity": "旁观命运牌会", "position": Vector2(1818, 1014), "visual_position": Vector2(1796, 1038)}
		}
	},
	"old_joe": {
		"name": "礁石老乔",
		"role": "稳健老牌手、港口闲谈者",
		"color": "c3a3ed",
		"services": ["poker"],
		"dialogue": [
			"“牌好不等于该把钱包全推上去，牌差也不等于一句话都不能说。”",
			"“我先看别人愿意为判断付多少，再决定自己的判断值多少。”",
			"“退契不是丢脸。明知不值还继续付，才是在拿情绪顶账。”",
			"“桌上每一枚金贝都得有来处，也得有去处。算不清的牌局不能叫牌局。”",
			"“礁石型不是什么都怕，是愿意等浪先露出方向。”",
			"“有人说得越多，手里越空；也有人一安静，你就该重新数底池。”",
			"“一场牌会最多八手，离桌再统一算时间。岛上的日子不能全耗在桌边。”",
			"“赢一手容易，带着本金离开才难。别把偶然当成本事。”"
		],
		"reactions": {
			"疏远": "老乔只朝空位点了点头：“低额桌照常开。别指望我替你判断。”",
			"熟悉": "老乔把底池边缘清出一块：“坐吧。你至少已经知道退契也是行动。”",
			"信任": "老乔压低声音：“我可以说说自己为什么停，但不会替你看牌。”"
		},
		"topics": [
			{"id": "poker_public_rules", "label": "牌会公开规则", "type": "公开事实", "source": "椰影牌会公示", "private": false},
			{"id": "table_observation", "label": "今天牌桌的节奏", "type": "人物观点", "source": "老乔的桌边观察", "private": false},
			{"id": "joe_old_loss", "label": "老乔曾经输掉的东西", "type": "人物观点", "source": "老乔的个人回忆", "private": true}
		],
		"request": {
			"id": "old_joe_first_table",
			"title": "完整地坐完一手",
			"objective": "完成一次正常命运牌会，不论胜负。",
			"hint": "先在潮边小桌完成教学牌会，再以自己的金贝坐一次。",
			"condition": "complete_poker",
			"rewards": {"coins": 30, "relationship": 8}
		},
		"share_interest": ["原理", "工艺"],
		"deep_talk": {
			"熟悉": "老乔说，稳健不是把风险降到零，而是提前决定自己最多愿意为哪种错误付多少钱。",
			"信任": "他讲起一次没有守住离桌线的旧牌会。真正让他难堪的不是输光，而是回家后仍对家人说自己只是运气不好。"
		},
		"schedule": {
			"清晨": {"area": "椰影街", "location": "椰影茶摊", "activity": "喝第一壶茶", "position": Vector2(1994, 1008), "visual_position": Vector2(1974, 1032)},
			"白天": {"area": "椰影街", "location": "椰影街公共广场", "activity": "听港口闲谈", "position": Vector2(1850, 770), "visual_position": Vector2(1828, 794)},
			"傍晚": {"area": "椰影街", "location": "椰影茶摊", "activity": "等晚桌开席", "position": Vector2(1994, 1008), "visual_position": Vector2(1974, 1032)},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊牌局", "activity": "参加命运牌会", "position": Vector2(1994, 1008), "visual_position": Vector2(1974, 1032)}
		}
	},
	"aqiu": {
		"name": "阿葵",
		"role": "年轻骑师",
		"color": "93e0ba",
		"services": ["race"],
		"dialogue": [
			"“逐风兽不是一串速度数字。它们也会怕吵、口渴，或者突然对一段风道失去耐心。”",
			"“云鳍喜欢先看清路再发力，我不逼它在起步段证明自己。”",
			"“祝胜券买的是你的判断，不是对骑师的所有权。”",
			"“天气公开，状态只能靠观察。谁跟你保证一定赢，谁就没把赛场当回事。”",
			"“水罐若能稳定补水，至少能让我们少拿一次性的东西来回折腾。”",
			"“造物最有意思的地方，是它能把一个模糊办法变成大家都能重复使用的方法。”",
			"“输一张券没关系，别因为想追回来就把下一场也当成上一场。”",
			"“看台上最响的人未必看得最准，马厩里最安静的那一刻反而常有答案。”"
		],
		"reactions": {
			"疏远": "阿葵把缰绳收回身边：“赛事大厅照常开放。我们先只谈公开赛程。”",
			"熟悉": "阿葵朝马厩里让出半步：“你可以近一点看，但别惊到正在休息的逐风兽。”",
			"信任": "阿葵递给你一张训练记录：“这是观察，不是答案。你愿意承担判断，我才愿意分享。”"
		},
		"topics": [
			{"id": "race_schedule", "label": "下一场公开赛事", "type": "公开事实", "source": "逐风海岸赛事公示", "private": false},
			{"id": "beast_condition", "label": "逐风兽今日状态", "type": "有来源消息", "source": "阿葵的马厩观察", "private": false},
			{"id": "rider_pressure", "label": "年轻骑师的压力", "type": "人物观点", "source": "阿葵的个人感受", "private": true}
		],
		"request": {
			"id": "aqiu_water_jar_method",
			"title": "不会消失的补水方法",
			"objective": "在万物图鉴中发现“水罐”，并向阿葵分享补水方法。",
			"hint": "陶器已经能固定形状，再想想什么能赋予它用途。",
			"condition": "discover_water_jar",
			"rewards": {"coins": 80, "relationship": 8}
		},
		"share_interest": ["水系", "材料", "工艺"],
		"deep_talk": {
			"熟悉": "阿葵说自己最怕的不是输，而是为了迎合看台，把逐风兽训练成只会透支冲刺的工具。",
			"信任": "她承认自己曾偷偷改过教练安排。那次结果很好，却让她第一次意识到：正确结果也可能来自不负责任的过程。"
		},
		"schedule": {
			"清晨": {"area": "逐风海岸", "location": "逐风海岸马厩", "activity": "晨间护理", "position": Vector2(2865, 760), "visual_position": Vector2(2842, 785)},
			"白天": {"area": "逐风海岸", "location": "逐风海岸赛场", "activity": "准备常规赛事", "position": Vector2(2708, 735), "visual_position": Vector2(2685, 760)},
			"傍晚": {"area": "逐风海岸", "location": "逐风海岸公共看台", "activity": "复盘今日比赛", "position": Vector2(2535, 760), "visual_position": Vector2(2512, 785)},
			"夜晚": {"area": "逐风海岸", "location": "逐风海岸休息区", "activity": "照看夜间马厩", "position": Vector2(3005, 885), "visual_position": Vector2(2982, 910)}
		}
	},
	"mia": {
		"name": "米娅",
		"role": "《晴潮晨报》记者",
		"color": "ffcf70",
		"services": ["news"],
		"dialogue": [
			"“公开事实、带来源的消息和我的判断，我会分开写。你也该分开读。”",
			"“价格上涨有原因，不代表下个时段还会继续涨。”",
			"“一个纪录鱼值得报道，但我更在意你在哪里、什么海况下看见了它。”",
			"“赛场消息最容易被一句‘状态很好’说得像保证，我不会这么写。”",
			"“财富曲线比一张赢钱截图诚实，它至少把没赢钱的那些时候也留下了。”",
			"“如果消息没有来源、生成时间和有效期，那通常只是装成情报的愿望。”",
			"“岛报会记录公共变化，不会替任何人泄露没公开的命牌。”",
			"“你发现的新万物越多，我越想知道它们怎样真的改变岛上生活。”"
		],
		"reactions": {
			"疏远": "米娅合上采访本：“公开报道你仍然可以看。私人采访先暂停。”",
			"熟悉": "米娅在页角写下你的名字：“我会把你说的话和记录核对，但至少愿意听完。”",
			"信任": "米娅把未刊出的采访提纲递给你：“你可以纠正事实，不能改掉对你不利的部分。”"
		},
		"topics": [
			{"id": "public_report", "label": "今日公开报道", "type": "公开事实", "source": "《晴潮晨报》公开栏", "private": false},
			{"id": "fish_market_observation", "label": "鱼市供需观察", "type": "有来源消息", "source": "蓝鳍鱼铺报价与米娅采访", "private": false},
			{"id": "mia_unpublished_note", "label": "尚未刊出的采访笔记", "type": "有来源消息", "source": "米娅的未刊采访", "private": true}
		],
		"request": {
			"id": "mia_first_record",
			"title": "一条可以核实的海岸记录",
			"objective": "在海岸潜捕中留下至少一种鱼的尺寸纪录，再向米娅展示。",
			"hint": "捕获任何鱼都会更新海生图鉴中的最大尺寸；不必出售它。",
			"condition": "record_fish",
			"rewards": {"coins": 40, "relationship": 6}
		},
		"share_interest": ["天象", "气候", "生命", "原理"],
		"deep_talk": {
			"熟悉": "米娅说，记者最常面对的不是纯粹谎言，而是每个人都只拿出对自己有利的那一小块真实。",
			"信任": "她承认自己压下过一篇会伤害普通鱼贩、却能让自己成名的报道。她至今不确定那是克制还是胆怯。"
		},
		"schedule": {
			"清晨": {"area": "椰影街", "location": "椰影街报亭", "activity": "更新晨报", "position": Vector2(2090, 710), "visual_position": Vector2(2070, 735)},
			"白天": {"area": "逐风海岸", "location": "逐风海岸采访区", "activity": "采访骑师与观众", "position": Vector2(2430, 620), "visual_position": Vector2(2408, 645)},
			"傍晚": {"area": "椰影街", "location": "椰影街报亭", "activity": "核对鱼价与赛果", "position": Vector2(2090, 710), "visual_position": Vector2(2070, 735)},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊", "activity": "整理未刊笔记", "position": Vector2(2078, 986), "visual_position": Vector2(2056, 1010)}
		}
	},
	"milo": {
		"name": "米洛",
		"role": "幸运俱乐部主人、契灵",
		"color": "95b9ff",
		"services": [],
		"dialogue": [
			"“我不崇拜金贝。我只喜欢它把一个人的选择放大到无法假装。”",
			"“偶然赢来的钱也是真的，问题是你接下来会把偶然当成什么。”",
			"“账户财富决定你能进哪张桌，不决定你在桌上有没有资格害怕。”",
			"“保留本金不是胆小，是给明天的自己留下继续选择的权利。”",
			"“名流不是最会赢的人，是输掉一次以后仍有别的生活可过的人。”",
			"“俱乐部的大门不会因为关系好就少收一枚金贝。”",
			"“我看过太多人急着证明自己配得上高桌，然后把证明本身输光。”",
			"“等你能把财富变成别人也能看见的东西，我们再谈岛上的影响力。”"
		],
		"reactions": {
			"疏远": "米洛的笑意没有消失：“公共资格照旧按财富计算。私人邀请则不必勉强。”",
			"熟悉": "米洛看了一眼你的财富曲线：“至少你开始把过程也当成结果的一部分。”",
			"信任": "米洛把一枚没有面值的旧贝壳放在桌上：“这是我第一次赢下俱乐部时唯一没拿去再押的东西。”"
		},
		"topics": [
			{"id": "wealth_title", "label": "财富头衔与下一步", "type": "公开事实", "source": "岛屿公共财富资格", "private": false},
			{"id": "risk_view", "label": "米洛怎么看风险", "type": "人物观点", "source": "米洛的个人判断", "private": false},
			{"id": "club_invitation", "label": "幸运俱乐部的邀请", "type": "有来源消息", "source": "米洛本人", "private": true}
		],
		"request": {
			"id": "milo_keep_reserve",
			"title": "给明天留下选择",
			"objective": "账户净资产达到500金贝，并且当前可用金贝不少于建议留存额。",
			"hint": "赚钱后不要立刻把全部现金投入下一场高风险活动。",
			"condition": "keep_reserve",
			"requires": "complete_poker",
			"rewards": {"coins": 0, "relationship": 8, "discount_uses": 1}
		},
		"share_interest": ["原理", "机械"],
		"deep_talk": {
			"熟悉": "米洛认为财富最危险的时刻不是归零，而是刚刚暴涨、所有旧约束看起来都显得可笑的时候。",
			"信任": "他坦白俱乐部并非靠一次豪赌得来，而是靠在三次本可翻倍的机会前选择停手。这个故事远没有传闻好听。"
		},
		"schedule": {
			"清晨": {"area": "", "location": "未出现", "activity": "行踪不明", "position": Vector2.ZERO, "visual_position": Vector2.ZERO, "available": false, "requires": "complete_poker"},
			"白天": {"area": "", "location": "未出现", "activity": "行踪不明", "position": Vector2.ZERO, "visual_position": Vector2.ZERO, "available": false, "requires": "complete_poker"},
			"傍晚": {"area": "逐风海岸", "location": "逐风海岸贵宾露台入口", "activity": "观察散场人群", "position": Vector2(3158, 900), "visual_position": Vector2(3135, 922), "requires": "complete_poker"},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊", "activity": "等待新的邀请对象", "position": Vector2(2120, 1010), "visual_position": Vector2(2098, 1034), "requires": "complete_poker"}
		}
	},
	"shopkeeper": {
		"name": "铺主阿拓",
		"role": "万物杂货铺经营者",
		"color": "e49f5a",
		"services": ["shop"],
		"dialogue": [
			"“我卖的是研究服务，不是把现成答案塞进你图鉴里。”",
			"“方向线索只告诉你该看哪一阶、哪种关系，最后那一步还得自己试。”",
			"“折扣凭证不会生成万物，只是让几次新实验便宜一点。”",
			"“公开服务夜里也有人代班。你不必追着我的日程才能买东西。”",
			"“真正值钱的不是一件造物，是一条别人也能重复验证的方法。”",
			"“同一条关系查第二次不收钱，研究记录已经替你留着。”",
			"“别因为手头宽裕就乱点。金贝花得快，不代表图鉴长得快。”",
			"“商店不收你刚合成的永久万物。知识不是库存耗材。”"
		],
		"reactions": {
			"疏远": "阿拓把价目牌推到你面前：“公共研究服务照价办理，闲聊就先省了。”",
			"熟悉": "阿拓翻到一页更清楚的索引：“我可以把线索说得少绕一点，但不会替你揭答案。”",
			"信任": "阿拓让你看了进货后的研究账：“真正影响价格的不是稀有，而是有多少人愿意为试错付钱。”"
		},
		"topics": [
			{"id": "shop_services", "label": "研究服务说明", "type": "公开事实", "source": "万物杂货铺价目牌", "private": false},
			{"id": "research_market", "label": "近期研究方向", "type": "有来源消息", "source": "阿拓的研究服务记录", "private": false},
			{"id": "shopkeeper_ledger", "label": "阿拓的研究账", "type": "人物观点", "source": "阿拓的私人账目观察", "private": true}
		],
		"request": {
			"id": "shopkeeper_second_tier",
			"title": "证明线索不是答案",
			"objective": "发现任意一种二阶万物，再回来说明自己的推理过程。",
			"hint": "三组根关系都能生成稳定的二阶万物。",
			"condition": "discover_tier_two",
			"rewards": {"coins": 0, "relationship": 6, "discount_uses": 2}
		},
		"share_interest": ["材料", "工艺", "机械", "原理"],
		"deep_talk": {
			"熟悉": "阿拓承认商店最难卖的不是服务，而是让客人相信“少告诉一点”有时比直接给答案更有价值。",
			"信任": "他展示一页亏损账：曾有一批人人看好的关系提示无人验证。那让他开始把自己的判断也标成“有来源消息”，而不是真理。"
		},
		"schedule": {
			"清晨": {"area": "椰影街", "location": "万物杂货铺", "activity": "整理研究索引", "position": Vector2(1474, 720), "visual_position": Vector2(1455, 742)},
			"白天": {"area": "椰影街", "location": "万物杂货铺", "activity": "提供研究服务", "position": Vector2(1474, 720), "visual_position": Vector2(1455, 742)},
			"傍晚": {"area": "椰影街", "location": "万物杂货铺", "activity": "核对当日研究账", "position": Vector2(1474, 720), "visual_position": Vector2(1455, 742)},
			"夜晚": {"area": "椰影街", "location": "万物杂货铺", "activity": "已经离店，由代班店员服务", "position": Vector2(1474, 720), "visual_position": Vector2(1455, 742), "available": false, "substitute": "夜班研究员"}
		}
	}
}

const RESIDENTS := [
	{
		"id": "resident_fisher",
		"name": "潮叔",
		"role": "近岸渔民",
		"color": "67c7cf",
		"dialogue": "“我只说亲眼看见的：今天浪脚附近的小鱼比昨天密。下个时段还在不在，我可不保证。”",
		"schedule": {
			"清晨": {"area": "漂流湾", "location": "海岸潜捕点", "position": Vector2(550, 785)},
			"白天": {"area": "椰影街", "location": "蓝鳍鱼铺", "position": Vector2(1650, 790)},
			"傍晚": {"area": "漂流湾", "location": "漂流湾栈桥", "position": Vector2(640, 720)},
			"夜晚": {"area": "", "location": "已经回家", "position": Vector2.ZERO, "available": false}
		}
	},
	{
		"id": "resident_chef",
		"name": "鹭姨",
		"role": "茶摊厨师",
		"color": "f0a96d",
		"dialogue": "“我收什么鱼看今天菜单，不看传闻。订单写多少就是多少，多的得按鱼铺普通价算。”",
		"schedule": {
			"清晨": {"area": "椰影街", "location": "蓝鳍鱼铺", "position": Vector2(1710, 760)},
			"白天": {"area": "椰影街", "location": "椰影茶摊后厨", "position": Vector2(1880, 1090)},
			"傍晚": {"area": "椰影街", "location": "椰影茶摊后厨", "position": Vector2(1880, 1090)},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊", "position": Vector2(1870, 1000)}
		}
	},
	{
		"id": "resident_collector",
		"name": "星渡",
		"role": "海生纪录收藏者",
		"color": "d8c77a",
		"dialogue": "“我只收有尺寸记录的特别个体。普通鱼也值得吃，但纪录得有能复核的数字。”",
		"schedule": {
			"清晨": {"area": "椰影街", "location": "万象塔外", "position": Vector2(1690, 560)},
			"白天": {"area": "椰影街", "location": "公共广场", "position": Vector2(1770, 720)},
			"傍晚": {"area": "逐风海岸", "location": "公共看台", "position": Vector2(2580, 700)},
			"夜晚": {"area": "", "location": "整理收藏", "position": Vector2.ZERO, "available": false}
		}
	},
	{
		"id": "resident_stablehand",
		"name": "小砾",
		"role": "马厩助手",
		"color": "8fc99d",
		"dialogue": "“逐风兽今天吃喝都正常。正常不等于一定跑得好，只能说明没有明显坏消息。”",
		"schedule": {
			"清晨": {"area": "逐风海岸", "location": "马厩", "position": Vector2(2925, 730)},
			"白天": {"area": "逐风海岸", "location": "赛事准备区", "position": Vector2(2780, 680)},
			"傍晚": {"area": "逐风海岸", "location": "马厩", "position": Vector2(2925, 730)},
			"夜晚": {"area": "逐风海岸", "location": "夜间马厩", "position": Vector2(2960, 830)}
		}
	},
	{
		"id": "resident_teaguest",
		"name": "阿满",
		"role": "茶摊常客",
		"color": "bd9bd4",
		"dialogue": "“我觉得老乔今天会赢——先说好，这只是我看他喝茶的样子猜的，不是牌桌消息。”",
		"schedule": {
			"清晨": {"area": "椰影街", "location": "公共广场", "position": Vector2(1800, 820)},
			"白天": {"area": "椰影街", "location": "公共广场", "position": Vector2(1800, 820)},
			"傍晚": {"area": "椰影街", "location": "椰影茶摊", "position": Vector2(1930, 980)},
			"夜晚": {"area": "椰影街", "location": "椰影茶摊", "position": Vector2(1930, 980)}
		}
	},
	{
		"id": "resident_courier",
		"name": "舟仔",
		"role": "岛报跑腿",
		"color": "7faed8",
		"dialogue": "“报栏、鱼铺和赛事厅的公示我都送到了。路上听来的话没有署名，我就不当消息写。”",
		"schedule": {
			"清晨": {"area": "椰影街", "location": "岛报栏", "position": Vector2(2040, 650)},
			"白天": {"area": "逐风海岸", "location": "赛事大厅", "position": Vector2(2380, 560)},
			"傍晚": {"area": "漂流湾", "location": "漂流湾路牌", "position": Vector2(1080, 650)},
			"夜晚": {"area": "椰影街", "location": "岛报栏", "position": Vector2(2040, 650)}
		}
	}
]


static func core_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in CORE.keys():
		result.append(str(raw_id))
	return result


static func core_profile(npc_id: String) -> Dictionary:
	return CORE.get(npc_id, {}).duplicate(true)


static func schedule_entry(npc_id: String, phase: String) -> Dictionary:
	var profile: Dictionary = CORE.get(npc_id, {})
	return profile.get("schedule", {}).get(phase, {}).duplicate(true)


static func resident_profile(resident_id: String) -> Dictionary:
	for raw_profile in RESIDENTS:
		var profile: Dictionary = raw_profile
		if str(profile.get("id", "")) == resident_id:
			return profile.duplicate(true)
	return {}


static func resident_schedule(resident_id: String, phase: String) -> Dictionary:
	var profile := resident_profile(resident_id)
	return profile.get("schedule", {}).get(phase, {}).duplicate(true)
