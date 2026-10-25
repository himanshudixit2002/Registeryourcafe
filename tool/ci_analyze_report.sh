#!/usr/bin/env bash
# Runs static analysis and writes JSON/CSV trend files under tool/analyzer_reports/.
# Mirrors the Flutter CI job; run from repo root.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter analyze
dart run tool/analyze_lib_report.dart
