#!/usr/bin/env python3
"""Run TreasureLand's blocking Godot checks locally or in CI."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
from typing import Sequence


EXPECTED_GODOT_VERSION = "4.7.stable"
COMMAND_TIMEOUT_SECONDS = 120

BLOCKING_TESTS: tuple[tuple[str, str], ...] = (
    ("res://tests/discovery_system_test.gd", "DISCOVERY SYSTEM TEST PASS"),
    (
        "res://tests/synthesis_signal_lifetime_test.gd",
        "SYNTHESIS SIGNAL LIFETIME TEST PASS",
    ),
    ("res://tests/world_time_save_test.gd", "WORLD TIME SAVE TEST PASS"),
    ("res://tests/fish_market_system_test.gd", "FISH MARKET SYSTEM TEST PASS"),
    ("res://tests/dive_ui_flow_test.gd", "DIVE UI FLOW TEST PASS"),
    ("res://tests/npc_social_system_test.gd", "NPC SOCIAL SYSTEM TEST PASS"),
    ("res://tests/npc_social_ui_test.gd", "NPC SOCIAL UI TEST PASS"),
    (
        "res://tests/collection_progression_test.gd",
        "COLLECTION PROGRESSION TEST PASS",
    ),
    ("res://tests/race_event_system_test.gd", "RACE EVENT SYSTEM TEST PASS"),
    ("res://tests/poker_session_flow_test.gd", "POKER SESSION FLOW TEST PASS"),
    ("res://tests/share_market_system_test.gd", "SHARE MARKET SYSTEM TEST PASS"),
    ("res://tests/home_finale_system_test.gd", "HOME FINALE SYSTEM TEST PASS"),
    (
        "res://tests/share_market_economy_stress_test.gd",
        "SHARE MARKET ECONOMY STRESS PASS",
    ),
    ("res://tests/smoke_test.gd", "SMOKE TEST PASS"),
    (
        "res://tests/poker_state_machine_stress_test.gd",
        "POKER STATE MACHINE STRESS PASS",
    ),
    ("res://tests/poker_opening_ai_test.gd", "POKER OPENING AI PASS"),
    ("res://tests/poker_animation_test.gd", "POKER ANIMATION TEST PASS"),
    ("res://tests/poker_npc_avatar_test.gd", "POKER NPC AVATAR TEST PASS"),
    (
        "res://tests/pixel_character_animator_test.gd",
        "PIXEL CHARACTER ANIMATOR TEST PASS",
    ),
    ("res://tests/world_layout_test.gd", "WORLD LAYOUT TEST PASS"),
)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Import the Godot project and run all blocking test scripts."
    )
    parser.add_argument(
        "--godot",
        default=os.environ.get("GODOT_BIN", "godot"),
        help="Godot executable path or command name (default: GODOT_BIN or godot).",
    )
    parser.add_argument(
        "--project",
        default="main",
        help="Path containing project.godot (default: main).",
    )
    return parser.parse_args(argv)


def resolve_executable(value: str) -> str:
    candidate = Path(value).expanduser()
    if candidate.is_file():
        return str(candidate.resolve())

    resolved = shutil.which(value)
    if resolved:
        return resolved

    raise FileNotFoundError(f"Godot executable was not found: {value}")


def stream_command(command: Sequence[str], label: str) -> tuple[int, str]:
    print(f"\n:: {label}", flush=True)
    print("$ " + " ".join(command), flush=True)
    process = subprocess.Popen(
        command,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    try:
        output, _ = process.communicate(timeout=COMMAND_TIMEOUT_SECONDS)
    except subprocess.TimeoutExpired:
        process.kill()
        output, _ = process.communicate()
        timeout_message = (
            f"ERROR: {label} exceeded {COMMAND_TIMEOUT_SECONDS}s and was terminated.\n"
        )
        print(output, end="", flush=True)
        print(timeout_message, end="", file=sys.stderr, flush=True)
        return 124, output + timeout_message
    print(output, end="", flush=True)
    return process.returncode, output


def write_step_summary(title: str, details: Sequence[str]) -> None:
    summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
    if not summary_path:
        return
    with Path(summary_path).open("a", encoding="utf-8") as summary:
        summary.write(f"## {title}\n\n")
        for detail in details:
            summary.write(f"- {detail}\n")


def run_suite(godot: str, project: Path) -> int:
    version_result = subprocess.run(
        [godot, "--version"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    version = (version_result.stdout or version_result.stderr).strip()
    print(f"Godot version: {version}", flush=True)
    if version_result.returncode != 0 or not version.startswith(EXPECTED_GODOT_VERSION):
        print(
            f"ERROR: expected Godot {EXPECTED_GODOT_VERSION}, got {version or 'unknown'}.",
            file=sys.stderr,
        )
        return 1

    import_code, import_output = stream_command(
        [godot, "--headless", "--editor", "--path", str(project), "--quit"],
        "L0 project import and script parse",
    )
    import_errors = ("SCRIPT ERROR", "Parse Error", "Failed to load script")
    if import_code != 0 or any(marker in import_output for marker in import_errors):
        write_step_summary(
            "Godot CI failed",
            [f"Project import/parse exited with code {import_code}."],
        )
        print(
            f"ERROR: project import or script parse failed with exit code {import_code}.",
            file=sys.stderr,
        )
        return 1

    failures: list[str] = []
    runtime_error_markers = (
        "SCRIPT ERROR:",
        "\nERROR:",
        "CrashHandlerException:",
        "Program crashed with signal",
    )
    for test_path, pass_marker in BLOCKING_TESTS:
        code, output = stream_command(
            [godot, "--headless", "--path", str(project), "--script", test_path],
            test_path,
        )
        if code != 0:
            failures.append(f"{test_path}: exited with code {code}")
            if code == 124:
                break
        elif any(marker in output for marker in runtime_error_markers):
            failures.append(f"{test_path}: Godot reported a runtime error despite exit code 0")
        elif pass_marker not in output:
            failures.append(f"{test_path}: missing pass marker {pass_marker!r}")

    print("\n:: CI summary", flush=True)
    if failures:
        write_step_summary("Godot CI failed", failures)
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        print(f"{len(failures)} blocking check(s) failed.", file=sys.stderr)
        return 1

    print(f"PASS: project import and all {len(BLOCKING_TESTS)} blocking tests.")
    write_step_summary(
        "Godot CI passed",
        [f"Project import and all {len(BLOCKING_TESTS)} blocking tests passed."],
    )
    return 0


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv if argv is not None else sys.argv[1:])
    project = Path(args.project).expanduser().resolve()
    if not (project / "project.godot").is_file():
        print(f"ERROR: project.godot was not found under {project}.", file=sys.stderr)
        return 2

    try:
        godot = resolve_executable(args.godot)
    except FileNotFoundError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2
    return run_suite(godot, project)


if __name__ == "__main__":
    raise SystemExit(main())
