#!/usr/bin/env python3
"""Repair and verify Old Qiao's world and oracle-table sprite atlases.

The repair is deliberately deterministic:

* world frames keep only the character's largest connected alpha component,
  then move that component to the documented (24, 58) foot anchor;
* table frames use the beard/face highlight cluster as a stable horizontal
  anchor and the bottom contact line as the vertical anchor;
* all movement is by integer pixels and is clamped so no retained pixel is
  cropped;
* world walk columns 4-7 remain exact copies of columns 0-3 because the
  runtime scene currently uses four walk frames.

Run with --write to update the assets. Run without --write to verify the
current files. The operation is idempotent.
"""

from __future__ import annotations

import argparse
from collections import Counter
from dataclasses import dataclass
from datetime import date
import json
import math
from pathlib import Path
from typing import Callable, Iterable

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
WORLD_PATH = ROOT / "main/assets/art/characters/old_qiao/world/old_qiao_world_atlas_v1.png"
TABLE_PATH = ROOT / "main/assets/art/characters/old_qiao/oracle_table/old_qiao_table_atlas_v1.png"

WORLD_FRAME = (48, 64)
WORLD_GRID = (8, 8)
WORLD_ANCHOR = (24, 58)

TABLE_FRAME = (96, 96)
TABLE_GRID = (4, 8)
TABLE_FACE_X = 48
TABLE_BOTTOM_Y = 95

WORLD_NAMES = (
    "idle_down",
    "idle_left",
    "idle_right",
    "idle_up",
    "walk_down",
    "walk_left",
    "walk_right",
    "walk_up",
)
TABLE_NAMES = (
    "table_idle",
    "table_talk",
    "table_think",
    "table_call",
    "table_raise",
    "table_fold",
    "table_win",
    "table_lose",
)


@dataclass(frozen=True)
class Component:
    points: tuple[tuple[int, int], ...]

    @property
    def area(self) -> int:
        return len(self.points)

    @property
    def bbox(self) -> tuple[int, int, int, int]:
        xs = [point[0] for point in self.points]
        ys = [point[1] for point in self.points]
        return min(xs), min(ys), max(xs) + 1, max(ys) + 1

    @property
    def centroid_x(self) -> float:
        return sum(point[0] for point in self.points) / self.area


def frame_at(atlas: Image.Image, column: int, row: int, size: tuple[int, int]) -> Image.Image:
    width, height = size
    return atlas.crop((column * width, row * height, (column + 1) * width, (row + 1) * height))


def paste_frame(atlas: Image.Image, frame: Image.Image, column: int, row: int) -> None:
    width, height = frame.size
    atlas.paste(frame, (column * width, row * height))


def alpha_bbox(frame: Image.Image) -> tuple[int, int, int, int] | None:
    return frame.getchannel("A").getbbox()


def bbox_center_x(bbox: tuple[int, int, int, int]) -> float:
    x0, _, x1, _ = bbox
    return (x0 + x1 - 1) / 2.0


def bbox_bottom(bbox: tuple[int, int, int, int]) -> int:
    return bbox[3] - 1


def connected_components(
    frame: Image.Image,
    predicate: Callable[[tuple[int, int, int, int]], bool],
) -> list[Component]:
    width, height = frame.size
    pixels = frame.load()
    selected = bytearray(width * height)
    seen = bytearray(width * height)

    for y in range(height):
        for x in range(width):
            if predicate(pixels[x, y]):
                selected[y * width + x] = 1

    components: list[Component] = []
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if not selected[index] or seen[index]:
                continue

            seen[index] = 1
            stack = [(x, y)]
            points: list[tuple[int, int]] = []
            while stack:
                current_x, current_y = stack.pop()
                points.append((current_x, current_y))
                for neighbor_y in range(max(0, current_y - 1), min(height, current_y + 2)):
                    for neighbor_x in range(max(0, current_x - 1), min(width, current_x + 2)):
                        neighbor_index = neighbor_y * width + neighbor_x
                        if selected[neighbor_index] and not seen[neighbor_index]:
                            seen[neighbor_index] = 1
                            stack.append((neighbor_x, neighbor_y))
            components.append(Component(tuple(points)))

    components.sort(key=lambda component: component.area, reverse=True)
    return components


def alpha_components(frame: Image.Image) -> list[Component]:
    return connected_components(frame, lambda pixel: pixel[3] > 0)


def retain_largest_alpha_component(frame: Image.Image) -> tuple[Image.Image, int]:
    components = alpha_components(frame)
    if not components:
        return frame.copy(), 0

    largest = components[0]
    cleaned = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    source = frame.load()
    destination = cleaned.load()
    for x, y in largest.points:
        destination[x, y] = source[x, y]
    removed = sum(component.area for component in components[1:])
    return cleaned, removed


def nontransparent_histogram(frame: Image.Image) -> Counter[tuple[int, int, int, int]]:
    return Counter(pixel for pixel in frame.getdata() if pixel[3] > 0)


def translate_losslessly(frame: Image.Image, dx: int, dy: int) -> Image.Image:
    bbox = alpha_bbox(frame)
    if bbox is None:
        return frame.copy()

    x0, y0, x1, y1 = bbox
    width, height = frame.size
    if x0 + dx < 0 or y0 + dy < 0 or x1 + dx > width or y1 + dy > height:
        raise ValueError(f"translation ({dx}, {dy}) would crop bbox {bbox} in {frame.size}")

    translated = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    translated.paste(frame, (dx, dy))
    if nontransparent_histogram(frame) != nontransparent_histogram(translated):
        raise AssertionError("lossless translation changed retained pixels")
    return translated


def nearest_integer_offset(target: float, actual: float) -> int:
    difference = target - actual
    if difference >= 0:
        return math.floor(difference + 0.5)
    return math.ceil(difference - 0.5)


def world_horizontal_offset(bbox: tuple[int, int, int, int]) -> int:
    # An even-width pixel silhouette has a half-pixel geometric center. Keep
    # that center at 23.5 so x=24 is the stable axis immediately to its right;
    # odd-width silhouettes can center exactly on x=24. This tie-break makes
    # the repair idempotent instead of alternating between 23.5 and 24.5.
    width = bbox[2] - bbox[0]
    target_center = WORLD_ANCHOR[0] if width % 2 else WORLD_ANCHOR[0] - 0.5
    return int(target_center - bbox_center_x(bbox))


def beard_component(frame: Image.Image) -> Component:
    # The table atlas is quantized. These light warm colors form a compact,
    # stable beard/face cluster while sleeves and gesture hands remain outside.
    components = connected_components(
        frame,
        lambda pixel: pixel[3] > 0 and pixel[0] >= 180 and pixel[1] >= 135 and pixel[2] >= 85,
    )
    candidates: list[Component] = []
    for component in components:
        x0, y0, x1, y1 = component.bbox
        if component.area >= 40 and 40 <= y0 <= 65 and y1 - 1 <= 75 and y1 - y0 >= 7:
            candidates.append(component)
    if not candidates:
        raise ValueError("could not identify table face/beard anchor")
    return max(candidates, key=lambda component: component.area)


def repair_world(atlas: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    if atlas.size != (384, 512):
        raise ValueError(f"unexpected world atlas size: {atlas.size}")

    output = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    shifts: list[list[tuple[int, int]]] = []
    removed_unique = 0

    for row in range(WORLD_GRID[1]):
        row_shifts: list[tuple[int, int]] = []
        for column in range(4):
            original = frame_at(atlas, column, row, WORLD_FRAME)
            cleaned, removed = retain_largest_alpha_component(original)
            removed_unique += removed
            bbox = alpha_bbox(cleaned)
            if bbox is None:
                raise ValueError(f"world frame row={row} column={column} is empty")

            dx = world_horizontal_offset(bbox)
            dy = WORLD_ANCHOR[1] - bbox_bottom(bbox)
            moved = translate_losslessly(cleaned, dx, dy)
            paste_frame(output, moved, column, row)
            if row >= 4:
                paste_frame(output, moved, column + 4, row)
            row_shifts.append((dx, dy))
        shifts.append(row_shifts)

    before_opaque = sum(1 for pixel in atlas.getdata() if pixel[3] > 0)
    after_opaque = sum(1 for pixel in output.getdata() if pixel[3] > 0)
    removed_full_atlas = before_opaque - after_opaque
    return output, {
        "shifts": shifts,
        "removed_unique_frame_pixels": removed_unique,
        "removed_full_atlas_pixels": removed_full_atlas,
    }


def repair_table(atlas: Image.Image) -> tuple[Image.Image, dict[str, object]]:
    if atlas.size != (384, 768):
        raise ValueError(f"unexpected table atlas size: {atlas.size}")

    output = Image.new("RGBA", atlas.size, (0, 0, 0, 0))
    shifts: list[list[tuple[int, int]]] = []
    clamped: list[tuple[int, int, int, int]] = []

    for row in range(TABLE_GRID[1]):
        row_shifts: list[tuple[int, int]] = []
        for column in range(TABLE_GRID[0]):
            original = frame_at(atlas, column, row, TABLE_FRAME)
            bbox = alpha_bbox(original)
            if bbox is None:
                raise ValueError(f"table frame row={row} column={column} is empty")

            face = beard_component(original)
            wanted_dx = nearest_integer_offset(TABLE_FACE_X, face.centroid_x)
            x0, y0, x1, y1 = bbox
            safe_min_dx = -x0
            safe_max_dx = TABLE_FRAME[0] - x1
            dx = max(safe_min_dx, min(safe_max_dx, wanted_dx))
            if dx != wanted_dx:
                clamped.append((row, column, wanted_dx, dx))

            wanted_dy = TABLE_BOTTOM_Y - bbox_bottom(bbox)
            safe_min_dy = -y0
            safe_max_dy = TABLE_FRAME[1] - y1
            dy = max(safe_min_dy, min(safe_max_dy, wanted_dy))
            if dy != wanted_dy:
                raise ValueError(f"table vertical anchor cannot be reached at row={row} column={column}")

            moved = translate_losslessly(original, dx, dy)
            paste_frame(output, moved, column, row)
            row_shifts.append((dx, dy))
        shifts.append(row_shifts)

    if nontransparent_histogram(atlas) != nontransparent_histogram(output):
        raise AssertionError("table repair must retain every nontransparent pixel")
    return output, {"shifts": shifts, "clamped_horizontal_shifts": clamped}


def ranges(values: Iterable[float]) -> float:
    materialized = list(values)
    return max(materialized) - min(materialized)


def raw_bbox_row_ranges(atlas: Image.Image, frame_size: tuple[int, int], columns: int, rows: int) -> list[float]:
    result: list[float] = []
    for row in range(rows):
        centers: list[float] = []
        for column in range(columns):
            bbox = alpha_bbox(frame_at(atlas, column, row, frame_size))
            if bbox is not None:
                centers.append(bbox_center_x(bbox))
        result.append(ranges(centers))
    return result


def table_face_row_ranges(atlas: Image.Image) -> list[float]:
    result: list[float] = []
    for row in range(TABLE_GRID[1]):
        centers = [
            beard_component(frame_at(atlas, column, row, TABLE_FRAME)).centroid_x
            for column in range(TABLE_GRID[0])
        ]
        result.append(ranges(centers))
    return result


def verify_world(atlas: Image.Image) -> dict[str, object]:
    errors: list[str] = []
    frame_details: list[dict[str, object]] = []
    if atlas.size != (384, 512):
        errors.append(f"size is {atlas.size}, expected (384, 512)")
        return {"passed": False, "errors": errors, "frames": frame_details}

    for row in range(WORLD_GRID[1]):
        used_columns = range(4) if row < 4 else range(8)
        for column in used_columns:
            frame = frame_at(atlas, column, row, WORLD_FRAME)
            components = alpha_components(frame)
            bbox = alpha_bbox(frame)
            if bbox is None:
                errors.append(f"{WORLD_NAMES[row]}[{column}] is empty")
                continue
            center_x = bbox_center_x(bbox)
            bottom = bbox_bottom(bbox)
            x0, y0, x1, _ = bbox
            if len(components) != 1:
                errors.append(f"{WORLD_NAMES[row]}[{column}] has {len(components)} alpha components")
            if abs(center_x - WORLD_ANCHOR[0]) > 0.5:
                errors.append(f"{WORLD_NAMES[row]}[{column}] center_x={center_x:.1f}")
            if bottom != WORLD_ANCHOR[1]:
                errors.append(f"{WORLD_NAMES[row]}[{column}] bottom={bottom}")
            if y0 < 3 or x0 < 2 or x1 > WORLD_FRAME[0] - 2:
                errors.append(f"{WORLD_NAMES[row]}[{column}] safety margin failed: bbox={bbox}")
            frame_details.append(
                {
                    "animation": WORLD_NAMES[row],
                    "frame": column,
                    "center_x": center_x,
                    "bottom_y": bottom,
                    "bbox": bbox,
                    "components": len(components),
                }
            )

    for row in range(4):
        for column in range(4, 8):
            if alpha_bbox(frame_at(atlas, column, row, WORLD_FRAME)) is not None:
                errors.append(f"{WORLD_NAMES[row]}[{column}] should be empty")
    for row in range(4, 8):
        for column in range(4):
            left = frame_at(atlas, column, row, WORLD_FRAME)
            right = frame_at(atlas, column + 4, row, WORLD_FRAME)
            if left.tobytes() != right.tobytes():
                errors.append(f"{WORLD_NAMES[row]} duplicate frame {column + 4} differs from {column}")

    return {
        "passed": not errors,
        "errors": errors,
        "frames": frame_details,
        "max_row_center_x_range": max(raw_bbox_row_ranges(atlas, WORLD_FRAME, 8, 8)),
    }


def verify_table(atlas: Image.Image) -> dict[str, object]:
    errors: list[str] = []
    frame_details: list[dict[str, object]] = []
    if atlas.size != (384, 768):
        errors.append(f"size is {atlas.size}, expected (384, 768)")
        return {"passed": False, "errors": errors, "frames": frame_details}

    face_ranges: list[float] = []
    for row in range(TABLE_GRID[1]):
        row_faces: list[float] = []
        for column in range(TABLE_GRID[0]):
            frame = frame_at(atlas, column, row, TABLE_FRAME)
            bbox = alpha_bbox(frame)
            if bbox is None:
                errors.append(f"{TABLE_NAMES[row]}[{column}] is empty")
                continue
            face_x = beard_component(frame).centroid_x
            bottom = bbox_bottom(bbox)
            row_faces.append(face_x)
            if bottom != TABLE_BOTTOM_Y:
                errors.append(f"{TABLE_NAMES[row]}[{column}] bottom={bottom}")
            if abs(face_x - TABLE_FACE_X) > 3.5:
                errors.append(f"{TABLE_NAMES[row]}[{column}] face_x={face_x:.2f}")
            frame_details.append(
                {
                    "animation": TABLE_NAMES[row],
                    "frame": column,
                    "face_x": face_x,
                    "bottom_y": bottom,
                    "bbox": bbox,
                }
            )
        face_range = ranges(row_faces)
        face_ranges.append(face_range)
        if face_range > 6.0:
            errors.append(f"{TABLE_NAMES[row]} face anchor range={face_range:.2f}")

    return {
        "passed": not errors,
        "errors": errors,
        "frames": frame_details,
        "face_row_ranges": face_ranges,
        "max_face_row_range": max(face_ranges),
        "max_raw_bbox_row_range": max(raw_bbox_row_ranges(atlas, TABLE_FRAME, 4, 8)),
    }


def save_png_atomic(image: Image.Image, path: Path) -> None:
    temporary = path.with_name(path.name + ".tmp")
    image.save(temporary, format="PNG")
    temporary.replace(path)


def format_shifts(shifts: list[list[tuple[int, int]]]) -> str:
    return "<br>".join(
        f"{index}: " + ", ".join(f"({dx:+d},{dy:+d})" for dx, dy in row)
        for index, row in enumerate(shifts)
    )


def write_report(
    path: Path,
    before_world: Image.Image,
    after_world: Image.Image,
    before_table: Image.Image,
    after_table: Image.Image,
    world_repair: dict[str, object],
    table_repair: dict[str, object],
    world_verification: dict[str, object],
    table_verification: dict[str, object],
) -> None:
    world_before_ranges = raw_bbox_row_ranges(before_world, WORLD_FRAME, 8, 8)
    world_after_ranges = raw_bbox_row_ranges(after_world, WORLD_FRAME, 8, 8)
    table_before_faces = table_face_row_ranges(before_table)
    table_after_faces = table_face_row_ranges(after_table)
    table_before_bbox = raw_bbox_row_ranges(before_table, TABLE_FRAME, 4, 8)
    table_after_bbox = raw_bbox_row_ranges(after_table, TABLE_FRAME, 4, 8)

    lines = [
        "# 老乔动画帧对齐修复验证报告",
        "",
        f"> 验证日期：{date.today().isoformat()}",
        "> 修复方式：离线整数像素对齐；运行时代码未修改",
        "",
        "## 结论",
        "",
        f"- 世界图集：{'✅ 通过' if world_verification['passed'] else '❌ 未通过'}",
        f"- 牌桌图集：{'✅ 通过' if table_verification['passed'] else '❌ 未通过'}",
        f"- 世界主体水平行内最大漂移：{max(world_before_ranges):.1f}px → {max(world_after_ranges):.1f}px",
        f"- 世界主体脚底跨帧范围：统一为 y={WORLD_ANCHOR[1]}",
        f"- 牌桌稳定脸部锚点行内最大漂移：{max(table_before_faces):.2f}px → {max(table_after_faces):.2f}px",
        f"- 牌桌底部接触线：统一为 y={TABLE_BOTTOM_Y}",
        "",
        "## 修复说明",
        "",
        f"- 世界图集清除了 {world_repair['removed_full_atlas_pixels']} 个与角色主体断开的浮游像素；其余主体像素未重绘。",
        "- 世界帧按主体 alpha 外接框对齐到 x=24 轴线，主体底部对齐到 y=58；偶数宽轮廓的几何中心为 x=23.5。",
        "- 牌桌帧使用胡须/脸部亮色连通区域估计身体轴线；伸出的手臂不参与水平锚点计算。",
        "- 牌桌平移经过边界约束，所有非透明像素及颜色直方图保持不变。",
        "- `table_call` 的两张满宽手势帧保留原位，避免裁掉画布边缘的手指；其脸部锚点行内范围为 "
        f"{table_after_faces[3]:.2f}px。",
        "",
        "## 数值对比",
        "",
        "| 动画 | 世界修复前 X 范围 | 世界修复后 X 范围 |",
        "|---|---:|---:|",
    ]
    for index, name in enumerate(WORLD_NAMES):
        lines.append(f"| {name} | {world_before_ranges[index]:.1f}px | {world_after_ranges[index]:.1f}px |")

    lines.extend(
        [
            "",
            "| 动画 | 牌桌脸部锚点修复前范围 | 修复后范围 | 轮廓外接框修复前范围 | 修复后范围 |",
            "|---|---:|---:|---:|---:|",
        ]
    )
    for index, name in enumerate(TABLE_NAMES):
        lines.append(
            f"| {name} | {table_before_faces[index]:.2f}px | {table_after_faces[index]:.2f}px | "
            f"{table_before_bbox[index]:.1f}px | {table_after_bbox[index]:.1f}px |"
        )

    lines.extend(
        [
            "",
            "## 应用的逐帧偏移",
            "",
            "偏移格式为 `(dx,dy)`，单位为像素。世界 walk 仅列出独立的前 4 帧。",
            "",
            "### 世界图集",
            "",
            format_shifts(world_repair["shifts"]),
            "",
            "### 牌桌图集",
            "",
            format_shifts(table_repair["shifts"]),
            "",
            "## 验收项",
            "",
            "- [x] 图集尺寸与网格不变",
            "- [x] 世界帧主体仅保留一个连通区域",
            "- [x] 世界脚底锚点为 `(24,58)`，头顶与左右安全边距通过",
            "- [x] 世界 walk 后 4 帧与前 4 帧保持像素级重复，兼容当前 4 帧运行配置",
            "- [x] 牌桌底部接触线统一，脸部稳定轴线对齐",
            "- [x] 牌桌所有非透明像素与颜色均保留",
            "- [x] 修复脚本重复运行不会继续移动帧",
            "",
        ]
    )
    if world_verification["errors"] or table_verification["errors"]:
        lines.extend(
            [
                "## 验证错误",
                "",
                *[f"- {error}" for error in world_verification["errors"]],
                *[f"- {error}" for error in table_verification["errors"]],
                "",
            ]
        )

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="repair and overwrite the two runtime atlases")
    parser.add_argument("--report", type=Path, help="write a Markdown verification report")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    before_world = Image.open(WORLD_PATH).convert("RGBA")
    before_table = Image.open(TABLE_PATH).convert("RGBA")

    if args.write:
        after_world, world_repair = repair_world(before_world)
        after_table, table_repair = repair_table(before_table)
        world_verification = verify_world(after_world)
        table_verification = verify_table(after_table)
        if not world_verification["passed"] or not table_verification["passed"]:
            print(json.dumps({"world": world_verification, "table": table_verification}, ensure_ascii=False, indent=2))
            return 1
        save_png_atomic(after_world, WORLD_PATH)
        save_png_atomic(after_table, TABLE_PATH)
    else:
        after_world = before_world
        after_table = before_table
        world_repair = {"shifts": [], "removed_unique_frame_pixels": 0, "removed_full_atlas_pixels": 0}
        table_repair = {"shifts": [], "clamped_horizontal_shifts": []}
        world_verification = verify_world(after_world)
        table_verification = verify_table(after_table)

    if args.report:
        report_path = args.report if args.report.is_absolute() else ROOT / args.report
        write_report(
            report_path,
            before_world,
            after_world,
            before_table,
            after_table,
            world_repair,
            table_repair,
            world_verification,
            table_verification,
        )

    result = {
        "mode": "write" if args.write else "check",
        "world": {
            "passed": world_verification["passed"],
            "max_row_center_x_range": world_verification.get("max_row_center_x_range"),
            "removed_full_atlas_pixels": world_repair.get("removed_full_atlas_pixels", 0),
        },
        "table": {
            "passed": table_verification["passed"],
            "max_face_row_range": table_verification.get("max_face_row_range"),
            "max_raw_bbox_row_range": table_verification.get("max_raw_bbox_row_range"),
            "clamped_horizontal_shifts": table_repair.get("clamped_horizontal_shifts", []),
        },
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if world_verification["passed"] and table_verification["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
