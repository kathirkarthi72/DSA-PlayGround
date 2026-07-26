#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/Packages/DSAKit/Sources/DSAKit"
DEST="$ROOT/DSAPlayground/Resources/DSAKitSources"
mkdir -p "$DEST"
cp "$SRC"/*.swift "$DEST/"
echo "Synced DSAKit sources → DSAPlayground/Resources/DSAKitSources"
