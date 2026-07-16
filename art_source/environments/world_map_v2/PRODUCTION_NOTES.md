# 大地图源图生产说明

> 日期：2026-07-15  
> 生成方式：Codex 内置 `imagegen`

三张源图均使用约 45° 斜俯视纯地面构图，没有天空、地平线、文字、任务点或 UI 标记；建筑、道路和可行走空地直接画在同一投影中。

| 源图 | 画面语义 |
|---|---|
| `driftwood_bay_ground_source_v2.png` | 漂流小屋、浅滩采集、造化盆、通往街区的石阶 |
| `coconut_street_ground_source_v2.png` | 万象塔、杂货铺、岛报栏、中心广场、命运牌会 |
| `wind_coast_ground_source_v2.png` | 赛事大厅、看台、马厩、环形赛道、贵宾门、海岸 |

`tools/art/build_world_map.py` 使用 160px smoothstep 重叠带拼接三张 `1254×1254` 子图，输出 `3442×1254` 的运行时地图。所有节点、NPC、碰撞、快速旅行和区域发现坐标都由 `main/scripts/world_layout.gd` 统一管理，未烘焙进图片。

复现：

```powershell
python tools/art/build_world_map.py
```
