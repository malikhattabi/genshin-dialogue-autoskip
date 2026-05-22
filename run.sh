#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

print_ok() {
  printf '[OK] %s\n' "$1"
}

print_error() {
  printf '[ERROR] %s\n' "$1" >&2
}

print_warn() {
  printf '[WARN] %s\n' "$1"
}

echo "Checking Python..."
if command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python3"
elif command -v python >/dev/null 2>&1; then
  PYTHON_BIN="python"
else
  print_error "Python is not installed or not in PATH."
  exit 1
fi
print_ok "$("$PYTHON_BIN" --version 2>&1)"

echo "Checking pip..."
if "$PYTHON_BIN" -m pip --version >/dev/null 2>&1; then
  PIP_CMD=("$PYTHON_BIN" -m pip)
  print_ok "pip is available."
else
  print_error "pip is not available for $PYTHON_BIN."
  exit 1
fi

echo "Checking uv..."
if command -v uv >/dev/null 2>&1; then
  print_ok "$(uv --version 2>&1)"
else
  print_warn "uv not found. Installing with pip..."
  if ! "${PIP_CMD[@]}" install uv; then
    print_error "Failed to install uv."
    exit 1
  fi
  print_ok "uv installed successfully."
fi

echo "Installing dependencies..."
if ! uv sync; then
  print_error "Dependency installation failed."
  exit 1
fi

run_app() {
  echo "Running Genshin Dialogue Auto-Skip..."
  uv run autoskip_dialogue.py
}

run_app
status=$?
if [[ $status -eq 0 ]]; then
  print_ok "Script completed successfully."
  exit 0
fi

print_error "Script exited with error code: $status"

if [[ -t 0 && -t 1 ]]; then
  read -r -p "Would you like to retry? (y/N): " retry
  if [[ "$retry" == "y" || "$retry" == "Y" || "$retry" == "yes" || "$retry" == "YES" ]]; then
    run_app
    status=$?
    if [[ $status -eq 0 ]]; then
      print_ok "Script completed successfully."
      exit 0
    fi
    print_error "Script exited with error code: $status"
  fi
fi

exit "$status"
