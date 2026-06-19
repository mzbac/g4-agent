#!/usr/bin/env sh

set -eu

APP_NAME="g4-agent"
INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
MODEL_DIR="${MODEL_DIR:-"$HOME/.g4-agent/model"}"
BIN_NAME="${BIN_NAME:-"$APP_NAME"}"
APP_HOME="${APP_HOME:-"$HOME/.g4-agent"}"
MODIFY_PATH=1
REMOVE_MODELS=1
REMOVE_APP_HOME=1
CUSTOM_MODEL_DIR=0

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

usage() {
  cat <<USAGE
Uninstall $APP_NAME.

Usage:
  uninstall.sh [options]

Options:
  --install-dir DIR       Directory containing the installed binary. Default: \$HOME/.local/bin
  --bin-name NAME         Installed command name. Default: g4-agent
  --model-dir DIR         Remove models from DIR too. Default: \$HOME/.g4-agent/model
  --keep-models           Keep model files
  --keep-data             Keep \$HOME/.g4-agent
  --no-modify-path        Do not update shell startup files
  -h, --help              Show this help

Examples:
  curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/uninstall.sh | sh

  curl -fsSL https://raw.githubusercontent.com/mzbac/g4-agent/main/uninstall.sh \\
    | sh -s -- --install-dir "\$HOME/bin"
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install-dir)
      [ "$#" -ge 2 ] || die "--install-dir requires a value"
      INSTALL_DIR="$2"
      shift 2
      ;;
    --bin-name)
      [ "$#" -ge 2 ] || die "--bin-name requires a value"
      BIN_NAME="$2"
      shift 2
      ;;
    --model-dir)
      [ "$#" -ge 2 ] || die "--model-dir requires a value"
      MODEL_DIR="$2"
      CUSTOM_MODEL_DIR=1
      shift 2
      ;;
    --keep-models)
      REMOVE_MODELS=0
      shift
      ;;
    --keep-data)
      REMOVE_APP_HOME=0
      shift
      ;;
    --no-modify-path)
      MODIFY_PATH=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

normalize_dir() {
  case "$1" in
    "~")
      printf '%s\n' "$HOME"
      ;;
    "~/"*)
      printf '%s/%s\n' "$HOME" "${1#~/}"
      ;;
    /*)
      printf '%s\n' "$1"
      ;;
    *)
      printf '%s/%s\n' "$(pwd)" "$1"
      ;;
  esac
}

safe_rm_rf() {
  path="$1"
  [ -n "$path" ] || die "refusing to remove an empty path"
  case "$path" in
    "/"|"$HOME"|"$HOME/"|"$INSTALL_DIR"|"$INSTALL_DIR/")
      die "refusing to remove unsafe path: $path"
      ;;
  esac
  if [ -e "$path" ] || [ -L "$path" ]; then
    rm -rf "$path"
    info "Removed: $path"
  else
    info "Not present: $path"
  fi
}

remove_path_markers_file() {
  rc_file="$1"
  [ "$MODIFY_PATH" -eq 1 ] || return 0
  [ -f "$rc_file" ] || return 0

  marker="# Added by $APP_NAME installer"
  if ! grep -F "$marker" "$rc_file" >/dev/null 2>&1; then
    return 0
  fi

  tmp_file="$rc_file.$APP_NAME-uninstall.$$"
  awk -v marker="$marker" '
    $0 == marker { skip = 1; next }
    skip == 1 { skip = 0; next }
    { print }
  ' "$rc_file" > "$tmp_file"
  mv "$tmp_file" "$rc_file"
  info "Removed PATH block from: $rc_file"
}

main() {
  INSTALL_DIR="$(normalize_dir "$INSTALL_DIR")"
  MODEL_DIR="$(normalize_dir "$MODEL_DIR")"
  APP_HOME="$(normalize_dir "$APP_HOME")"

  info "Uninstalling $APP_NAME"
  info "Install dir: $INSTALL_DIR"
  info "App data dir: $APP_HOME"
  info "Model dir: $MODEL_DIR"

  rm -f "$INSTALL_DIR/$BIN_NAME"
  info "Removed binary if present: $INSTALL_DIR/$BIN_NAME"

  if [ "$REMOVE_MODELS" -eq 1 ]; then
    if [ "$REMOVE_APP_HOME" -eq 1 ]; then
      safe_rm_rf "$APP_HOME"
    fi
    if [ "$REMOVE_APP_HOME" -eq 0 ]; then
      safe_rm_rf "$MODEL_DIR"
    elif [ "$CUSTOM_MODEL_DIR" -eq 1 ]; then
      case "$MODEL_DIR/" in
        "$APP_HOME/"*) ;;
        *) safe_rm_rf "$MODEL_DIR" ;;
      esac
    fi
  fi

  remove_path_markers_file "$HOME/.zshrc"
  remove_path_markers_file "$HOME/.bashrc"
  remove_path_markers_file "$HOME/.profile"

  info ""
  info "$APP_NAME uninstall complete."
}

main "$@"
