#!/bin/zsh
# Test, build, notarize, and publish a new release without credential prompts.

set -euo pipefail

PROJECT_DIR="${0:A:h:h}"

"$PROJECT_DIR/Scripts/setup-release.sh" --check

cd "$PROJECT_DIR"
swift test
"$PROJECT_DIR/Scripts/build-dmg.sh"
"$PROJECT_DIR/Scripts/deploy-release.sh"
