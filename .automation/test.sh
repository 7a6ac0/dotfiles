#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

"$ROOT_DIR/.automation/render-readme.sh" --check
"$ROOT_DIR/.automation/test-install.sh"
