#!/usr/bin/env sh

set -eu

APP_NAME="g4-agent"
REPO="mzbac/g4-agent"
ASSET_NAME="g4-agent.zip"
HF_REPO="google/gemma-4-12B-it-qat-q4_0-gguf"
MODEL_FILE="gemma-4-12b-it-qat-q4_0.gguf"
MMPROJ_FILE="mmproj-gemma-4-12b-it-qat-q4_0.gguf"

VERSION="latest"
INSTALL_DIR="${INSTALL_DIR:-"$HOME/.local/bin"}"
MODEL_DIR="${MODEL_DIR:-"$HOME/.g4-agent/model"}"
BIN_NAME="${BIN_NAME:-"$APP_NAME"}"
MODIFY_PATH=1
DOWNLOAD_MODELS=1

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

usage() {
  cat <<USAGE
Install $APP_NAME.

Usage:
  install.sh [options]

Options:
  --version VERSION       Install a specific release tag, for example 0.0.4
  --install-dir DIR       Install into DIR. Default: \$HOME/.local/bin
  --bin-name NAME         Installed command name. Default: g4-agent
  --model-dir DIR         Download models into DIR. Default: \$HOME/.g4-agent/model
  --no-models             Install the binary only; do not download model files
  --no-modify-path        Do not update shell startup files
  -h, --help              Show this help

Examples:
  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh | sh

  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh \\
    | sh -s -- --version 0.0.4

  curl -fsSL https://raw.githubusercontent.com/$REPO/main/install.sh \\
    | sh -s -- --install-dir "\$HOME/bin"
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      [ "$#" -ge 2 ] || die "--version requires a value"
      VERSION="$2"
      shift 2
      ;;
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
      shift 2
      ;;
    --no-models)
      DOWNLOAD_MODELS=0
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

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

shell_quote() {
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}

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

download_url() {
  if [ "$VERSION" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s' "$REPO" "$ASSET_NAME"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$REPO" "$VERSION" "$ASSET_NAME"
  fi
}

hf_url() {
  printf 'https://huggingface.co/%s/resolve/main/%s' "$HF_REPO" "$1"
}

find_binary_in_zip() {
  unpack_dir="$1"

  found=""

  if [ -f "$unpack_dir/$APP_NAME" ]; then
    found="$unpack_dir/$APP_NAME"
  else
    found="$(find "$unpack_dir" \
      -type f \
      -name "$APP_NAME" \
      ! -path '*/__MACOSX/*' \
      | head -n 1 || true)"
  fi

  if [ -z "$found" ]; then
    files_list="$unpack_dir/.files"
    find "$unpack_dir" \
      -type f \
      ! -path '*/__MACOSX/*' \
      ! -name '.files' \
      > "$files_list"

    file_count="$(wc -l < "$files_list" | tr -d ' ')"

    if [ "$file_count" = "1" ]; then
      found="$(sed -n '1p' "$files_list")"
    fi
  fi

  [ -n "$found" ] || die "could not find $APP_NAME binary inside $ASSET_NAME"
  [ -f "$found" ] || die "found binary path is not a file: $found"

  printf '%s' "$found"
}

verify_gguf() {
  file="$1"
  [ -s "$file" ] || return 1
  magic="$(dd if="$file" bs=4 count=1 2>/dev/null | od -An -tx1 | tr -d ' \n')"
  [ "$magic" = "47475546" ]
}

curl_download() {
  url="$1"
  out="$2"
  if [ -n "${HF_TOKEN:-}" ]; then
    curl -fL --proto '=https' --tlsv1.2 -C - \
      -H "Authorization: Bearer $HF_TOKEN" \
      -o "$out" "$url"
  else
    curl -fL --proto '=https' --tlsv1.2 -C - -o "$out" "$url"
  fi
}

download_model_file() {
  name="$1"
  dest="$MODEL_DIR/$name"
  part="$dest.part"
  url="$(hf_url "$name")"

  if [ -f "$dest" ]; then
    if verify_gguf "$dest"; then
      info "Model already present: $dest"
      return 0
    fi
    die "existing model file failed GGUF verification: $dest"
  fi

  mkdir -p "$MODEL_DIR"
  info "Downloading model asset:"
  info "  $url"
  info "  -> $dest"
  curl_download "$url" "$part" || die "download failed for $name; run installer again to resume"
  if ! verify_gguf "$part"; then
    rm -f "$part"
    die "downloaded file failed GGUF verification: $part"
  fi
  mv "$part" "$dest"
}

append_path_if_needed() {
  [ "$MODIFY_PATH" -eq 1 ] || return 0

  case ":$PATH:" in
    *":$INSTALL_DIR:"*)
      return 0
      ;;
  esac

  shell_name="$(basename "${SHELL:-sh}")"

  case "$shell_name" in
    zsh)
      rc_file="$HOME/.zshrc"
      ;;
    bash)
      rc_file="$HOME/.bashrc"
      ;;
    *)
      rc_file="$HOME/.profile"
      ;;
  esac

  marker="# Added by $APP_NAME installer"
  path_line="export PATH=$(shell_quote "$INSTALL_DIR"):\$PATH"

  if [ -f "$rc_file" ] && grep -F "$marker" "$rc_file" >/dev/null 2>&1; then
    return 0
  fi

  {
    printf '\n%s\n' "$marker"
    printf '%s\n' "$path_line"
  } >> "$rc_file"

  info "Updated PATH in $rc_file"
}

main() {
  need_cmd curl
  need_cmd unzip
  need_cmd find
  need_cmd head
  need_cmd sed
  need_cmd wc
  need_cmd tr
  need_cmd basename
  need_cmd mktemp
  need_cmd dd
  need_cmd od

  INSTALL_DIR="$(normalize_dir "$INSTALL_DIR")"
  MODEL_DIR="$(normalize_dir "$MODEL_DIR")"

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/g4-agent.XXXXXX")"
  trap 'rm -rf "$tmp_dir"' EXIT INT TERM

  archive_path="$tmp_dir/$ASSET_NAME"
  unpack_dir="$tmp_dir/unpack"
  url="$(download_url)"

  mkdir -p "$unpack_dir"

  info "Installing $APP_NAME"
  info "Version: $VERSION"
  info "Install dir: $INSTALL_DIR"
  info "Model dir: $MODEL_DIR"
  info "Download: $url"

  curl -fL --proto '=https' --tlsv1.2 -o "$archive_path" "$url"

  unzip -q "$archive_path" -d "$unpack_dir"

  binary_path="$(find_binary_in_zip "$unpack_dir")"

  mkdir -p "$INSTALL_DIR"

  tmp_bin="$INSTALL_DIR/$BIN_NAME.tmp.$$"

  cp "$binary_path" "$tmp_bin"
  chmod 755 "$tmp_bin"
  mv "$tmp_bin" "$INSTALL_DIR/$BIN_NAME"

  if [ "$DOWNLOAD_MODELS" -eq 1 ]; then
    download_model_file "$MODEL_FILE"
    download_model_file "$MMPROJ_FILE"
  else
    mkdir -p "$MODEL_DIR"
    info "Skipping model downloads. Default model dir is: $MODEL_DIR"
  fi

  append_path_if_needed

  info ""
  info "$APP_NAME installed successfully:"
  info "  $INSTALL_DIR/$BIN_NAME"
  info "Models:"
  info "  $MODEL_DIR"

  if command -v "$BIN_NAME" >/dev/null 2>&1; then
    info ""
    info "Try:"
    info "  $BIN_NAME"
  else
    info ""
    info "Your current shell may not see the new PATH yet."
    info "Run:"
    info "  export PATH=$(shell_quote "$INSTALL_DIR"):\$PATH"
    info ""
    info "Then try:"
    info "  $BIN_NAME"
  fi
}

main "$@"
