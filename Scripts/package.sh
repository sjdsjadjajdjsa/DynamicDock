#!/bin/bash
# Builds a universal DynamicDock.app and zips it for sharing: build/DynamicDock.zip
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UNIVERSAL=1 "$ROOT/Scripts/build-app.sh" release

rm -f "$ROOT/build/DynamicDock.zip"
ditto -c -k --keepParent "$ROOT/build/DynamicDock.app" "$ROOT/build/DynamicDock.zip"
echo "Packaged $ROOT/build/DynamicDock.zip"
