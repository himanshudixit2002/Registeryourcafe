#!/usr/bin/env python3
"""
Idempotently patch Flutter SDK packages/flutter/lib/src/gestures/converter.dart
so PointerHover/Move/Down/Up/Cancel/Removed never receive PointerDeviceKind.trackpad.

The framework asserts !trackpad for those events; the web engine can still attach
trackpad to synthesized moves (flutter/flutter#174215).

Usage:
  FLUTTER_ROOT=/path/to/flutter python3 tool/patch_flutter_framework_converter_trackpad.py
"""
from __future__ import annotations

import os
import sys

MARKER = "pointerEventsKind"
INSERT_AFTER = "final PointerDeviceKind kind = datum.kind;"
INSERT_BLOCK = """          final PointerDeviceKind pointerEventsKind =
              identical(kind, PointerDeviceKind.trackpad)
                  ? PointerDeviceKind.mouse
                  : kind;
"""


def main() -> int:
    root = os.environ.get("FLUTTER_ROOT")
    if not root:
        print("Set FLUTTER_ROOT to your Flutter SDK root.", file=sys.stderr)
        return 1
    path = os.path.join(
        root,
        "packages",
        "flutter",
        "lib",
        "src",
        "gestures",
        "converter.dart",
    )
    if not os.path.isfile(path):
        print(f"Not found: {path}", file=sys.stderr)
        return 1

    with open(path, encoding="utf-8") as f:
        content = f.read()

    if MARKER in content:
        print(f"Already patched: {path}")
        return 0

    if INSERT_AFTER not in content:
        print(
            "Could not find insertion point; your Flutter SDK may differ from expected.",
            file=sys.stderr,
        )
        return 1

    insert_at = content.index(INSERT_AFTER) + len(INSERT_AFTER)
    content = content[:insert_at] + "\n" + INSERT_BLOCK + content[insert_at:]

    inner_start = content.find("            case ui.PointerSignalKind.none:")
    inner_end = content.find("            case ui.PointerSignalKind.scroll:", inner_start)
    if inner_start < 0 or inner_end < 0 or inner_start >= inner_end:
        print("Could not locate PointerSignalKind.none / scroll cases.", file=sys.stderr)
        return 1

    head = content[:inner_start]
    mid = content[inner_start:inner_end]
    tail = content[inner_end:]
    mid = mid.replace("kind: kind,", f"kind: {MARKER},")
    content = head + mid + tail

    with open(path, "w", encoding="utf-8") as f:
        f.write(content)

    print(f"Patched: {path}")
    print("Run: flutter clean")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
