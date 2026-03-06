#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
REQUIREMENTS_FILE="$ROOT_DIR/requirements.txt"
REQUIREMENTS_HASH_FILE="$VENV_DIR/.requirements.sha256"

requirements_hash() {
  python3 - "$REQUIREMENTS_FILE" <<'PY'
from pathlib import Path
import hashlib
import sys

path = Path(sys.argv[1])
print(hashlib.sha256(path.read_bytes()).hexdigest())
PY
}

ensure_venv() {
  local desired_hash
  local current_hash=""

  if [[ ! -x "$VENV_DIR/bin/python" ]]; then
    echo "No usable .venv found. Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
  fi

  desired_hash="$(requirements_hash)"
  if [[ -f "$REQUIREMENTS_HASH_FILE" ]]; then
    current_hash="$(<"$REQUIREMENTS_HASH_FILE")"
  fi

  if [[ "$current_hash" != "$desired_hash" ]]; then
    echo "Installing dependencies from requirements.txt..."
    "$VENV_DIR/bin/pip" install --upgrade pip
    "$VENV_DIR/bin/pip" install -r "$REQUIREMENTS_FILE"
    printf '%s\n' "$desired_hash" > "$REQUIREMENTS_HASH_FILE"
  fi
}

activate_venv() {
  echo "Activating virtual environment..."
  # shellcheck disable=SC1091
  source "$VENV_DIR/bin/activate"
}

ensure_and_activate_venv() {
  ensure_venv
  activate_venv
}
