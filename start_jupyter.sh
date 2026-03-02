#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REQUIREMENTS_FILE="$ROOT_DIR/requirements.txt"

if [[ ! -d "$VENV_DIR" ]]; then
  echo "No .venv found. Creating virtual environment..."
  python3 -m venv "$VENV_DIR"

  echo "Installing dependencies from requirements.txt..."
  "$VENV_DIR/bin/pip" install --upgrade pip
  "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE"
fi

echo "Activating virtual environment..."
# shellcheck disable=SC1091
source "$VENV_DIR/bin/activate"

echo "Starting JupyterLab..."
exec jupyter lab
