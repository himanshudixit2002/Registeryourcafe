#!/usr/bin/env bash
# Re-apply Flutter web trackpad workarounds after `flutter upgrade`.
#
# 1) Framework: packages/flutter/lib/src/gestures/converter.dart — remap
#    trackpad→mouse for PointerHover/Move/Down/Up/… (fixes events.dart asserts).
# 2) Engine (optional): flutter_web_sdk/.../pointer_converter.dart — if a bundled
#    patch exists for older SDKs.
#
# After patching: run `flutter clean` and restart the browser / dev server.
#
# Usage:
#   ./tool/apply_flutter_web_trackpad_fix.sh
#   FLUTTER_ROOT=/path/to/flutter ./tool/apply_flutter_web_trackpad_fix.sh
#   DRY_RUN=1 ./tool/apply_flutter_web_trackpad_fix.sh   # print FLUTTER_ROOT only

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

resolve_flutter_root() {
  if [[ -n "${FLUTTER_ROOT:-}" ]]; then
    printf '%s' "$FLUTTER_ROOT"
    return
  fi
  local flutter_bin
  flutter_bin="$(command -v flutter)" || {
    echo "flutter not on PATH; set FLUTTER_ROOT" >&2
    exit 1
  }
  python3 -c "import os, sys; p=os.path.realpath(sys.argv[1]); print(os.path.dirname(os.path.dirname(p)))" \
    "$flutter_bin"
}

ROOT="$(resolve_flutter_root)"

if [[ "${DRY_RUN:-}" == "1" ]]; then
  echo "$ROOT"
  exit 0
fi

echo "Using FLUTTER_ROOT=$ROOT"

# Primary fix: framework PointerEventConverter (fixes !identical(kind, trackpad) on web).
python3 "$SCRIPT_DIR/patch_flutter_framework_converter_trackpad.py" || {
  echo "Framework patch failed." >&2
  exit 1
}

CANDIDATE="$ROOT/bin/cache/flutter_web_sdk/lib/_engine/engine/pointer_converter.dart"
if [[ -f "$CANDIDATE" ]]; then
  if grep -q "syntheticMoveKind\|preUpMoveKind\|PointerMoveEvent forbids" "$CANDIDATE" 2>/dev/null; then
    echo "OK: engine pointer_converter.dart already has trackpad remapping."
  else
    PATCH_FILE="$SCRIPT_DIR/patches/flutter_web_pointer_converter.patch"
    if [[ -f "$PATCH_FILE" ]]; then
      echo "Applying engine patch $PATCH_FILE ..."
      patch --backup --forward "$CANDIDATE" <"$PATCH_FILE" || {
        echo "Engine patch failed (optional)." >&2
      }
    else
      echo "Note: no bundled engine patch; framework fix above is usually enough."
    fi
  fi
else
  echo "Note: flutter_web_sdk not found (run: flutter precache --web)."
fi

echo "Done. Run: flutter clean"
exit 0
