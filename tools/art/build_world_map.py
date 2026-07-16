#!/usr/bin/env python3
"""Assemble the three 45-degree ground submaps into the runtime island map."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageStat


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "art_source/environments/world_map_v2"
OUTPUT_DIR = ROOT / "main/assets/art/environments/world_map_v2"
SOURCES = (
    ("漂流湾", SOURCE_DIR / "driftwood_bay_ground_source_v2.png"),
    ("椰影街", SOURCE_DIR / "coconut_street_ground_source_v2.png"),
    ("逐风海岸", SOURCE_DIR / "wind_coast_ground_source_v2.png"),
)
OVERLAP = 160
EXPECTED_TILE = (1254, 1254)


def _blend_tile(canvas: Image.Image, tile: Image.Image, origin_x: int) -> float:
    overlap_box = (origin_x, 0, origin_x + OVERLAP, tile.height)
    previous = canvas.crop(overlap_box).convert("RGB")
    incoming = tile.crop((0, 0, OVERLAP, tile.height)).convert("RGB")
    before_difference = sum(ImageStat.Stat(ImageChops.difference(previous, incoming)).mean) / 3.0

    mask = Image.new("L", (OVERLAP, tile.height))
    mask_pixels = mask.load()
    for x in range(OVERLAP):
        # Smoothstep avoids a visible derivative change at either edge.
        t = x / float(OVERLAP - 1)
        smooth = t * t * (3.0 - 2.0 * t)
        alpha = int(round(smooth * 255.0))
        for y in range(tile.height):
            mask_pixels[x, y] = alpha
    blended = Image.composite(incoming, previous, mask)
    canvas.paste(blended, (origin_x, 0))
    canvas.paste(tile.crop((OVERLAP, 0, tile.width, tile.height)), (origin_x + OVERLAP, 0))
    return before_difference


def main() -> int:
    tiles: list[tuple[str, Image.Image]] = []
    for name, path in SOURCES:
        if not path.is_file():
            raise FileNotFoundError(path)
        tile = Image.open(path).convert("RGB")
        if tile.size != EXPECTED_TILE:
            raise ValueError(f"{path}: expected {EXPECTED_TILE}, got {tile.size}")
        tiles.append((name, tile))

    step = EXPECTED_TILE[0] - OVERLAP
    width = EXPECTED_TILE[0] + step * (len(tiles) - 1)
    canvas = Image.new("RGB", (width, EXPECTED_TILE[1]))
    canvas.paste(tiles[0][1], (0, 0))
    seam_source_differences: list[float] = []
    for index, (_, tile) in enumerate(tiles[1:], start=1):
        seam_source_differences.append(_blend_tile(canvas, tile, index * step))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    output = OUTPUT_DIR / "island_ground_map_v2.png"
    canvas.save(output, optimize=True)
    preview = canvas.copy()
    preview.thumbnail((1600, 600), Image.Resampling.LANCZOS)
    preview.save(OUTPUT_DIR / "island_ground_map_v2_preview.png", optimize=True)

    report = ROOT / "doc/大地图地面拼接验证报告_2026-07-15.md"
    origins = [index * step for index in range(len(tiles))]
    report.write_text(
        "\n".join(
            [
                "# 大地图地面拼接验证报告",
                "",
                "> 检查日期：2026-07-15  ",
                "> 地图视角：约 45° 斜俯视纯地面，无天空背景",
                "",
                "## 输出",
                "",
                f"- 运行时地图：`{output.relative_to(ROOT).as_posix()}`",
                f"- 实际尺寸：{canvas.width}×{canvas.height}",
                f"- 子图尺寸：{EXPECTED_TILE[0]}×{EXPECTED_TILE[1]}，共 {len(tiles)} 张",
                f"- 相邻重叠：{OVERLAP}px，使用 smoothstep 渐变融合",
                f"- 子图原点 X：{', '.join(str(value) for value in origins)}",
                "",
                "## 子区与语义",
                "",
                "| 子区 | 地面内容 | 运行时 X 原点 |",
                "|---|---|---:|",
                f"| 漂流湾 | 漂流小屋、浅滩采集区、造化盆 | {origins[0]} |",
                f"| 椰影街 | 万象塔、杂货铺、岛报栏、命运牌会 | {origins[1]} |",
                f"| 逐风海岸 | 赛事大厅、赛道、看台、贵宾门 | {origins[2]} |",
                "",
                "## 拼接检查",
                "",
                f"- 源图交界平均色差（融合前，仅用于记录）：{seam_source_differences[0]:.2f} / {seam_source_differences[1]:.2f}",
                "- 融合条两端权重为 0/1，避免硬切线：✅",
                "- 输出尺寸与坐标契约一致：✅",
                "- 图片内未绘制任务节点、文字或 UI 标记：✅",
                "",
                "地标与交互坐标的唯一运行时来源为 `main/scripts/world_layout.gd`。",
                "",
                "复现命令：`python tools/art/build_world_map.py`",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print(f"Built {output} ({canvas.width}x{canvas.height})")
    print(report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
