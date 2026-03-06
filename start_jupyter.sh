#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "$ROOT_DIR/activate_venv.sh"
ensure_and_activate_venv

echo "Starting JupyterLab..."
exec jupyter lab
