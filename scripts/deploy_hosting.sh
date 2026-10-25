#!/usr/bin/env bash
# Fetch dependencies, build Flutter web, deploy to Firebase Hosting.
# Prereqs: Flutter SDK, Node/npm, and Firebase CLI (`npm i -g firebase-tools`),
# plus `firebase login` once on your machine (or FIREBASE_TOKEN for CI).

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "==> flutter pub get"
flutter pub get

echo "==> flutter build web --release"
flutter build web --release

if ! command -v firebase >/dev/null 2>&1; then
  echo "Firebase CLI not found. Install with: npm install -g firebase-tools"
  echo "Then run: firebase login"
  exit 1
fi

echo "==> firebase deploy --only hosting"
firebase deploy --only hosting

echo "Done. Site: https://registeryourcafe.web.app (default) or your custom domain in Firebase Console."
