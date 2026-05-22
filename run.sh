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

SESSION_TYPE="${XDG_SESSION_TYPE:-}"
HAS_DISPLAY=0
HAS_WAYLAND=0
[[ -n "${DISPLAY:-}" ]] && HAS_DISPLAY=1
[[ -n "${WAYLAND_DISPLAY:-}" ]] && HAS_WAYLAND=1

if [[ "$SESSION_TYPE" == "wayland" || $HAS_WAYLAND -eq 1 ]]; then
  echo "Detected Wayland session."
  if [[ $HAS_DISPLAY -eq 1 ]]; then
    print_ok "XWayland bridge detected (DISPLAY is set)."
  else
    print_ok "Native Wayland mode detected."
    command -v wtype >/dev/null 2>&1 || { print_error "wtype not found (required for key injection on native Wayland). Install with: sudo pacman -S wtype"; exit 1; }
    command -v grim >/dev/null 2>&1 || { print_error "grim not found (required for pixel capture on native Wayland). Install with: sudo pacman -S grim"; exit 1; }
    if ! command -v hyprctl >/dev/null 2>&1 && ! command -v swaymsg >/dev/null 2>&1; then
      print_error "hyprctl/swaymsg not found (required for native Wayland active-window detection on Hyprland/Sway)."
      exit 1
    fi
  fi
else
  # X11 session — ensure xdotool is available as a fallback for window detection
  if ! command -v xdotool >/dev/null 2>&1; then
    print_warn "xdotool not found. Install for better X11 window-title detection: sudo pacman -S xdotool"
  fi
fi

# On Arch Linux, pyautogui requires the 'tk' and 'python-xlib' system packages.
# Install them if missing: sudo pacman -S tk python-xlib
if command -v pacman >/dev/null 2>&1; then
  if ! python3 -c "import tkinter" >/dev/null 2>&1; then
    print_warn "tkinter not available. Install with: sudo pacman -S tk"
  fi
fi

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
  if [[ "${retry,,}" == y* ]]; then
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
