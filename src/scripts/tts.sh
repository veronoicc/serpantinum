#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "${BASH_SOURCE[0]%/*}" 2>/dev/null && pwd -P)"

TEXT="${1:-}"
if [[ -z "$TEXT" ]]; then
    exit 0
fi

OUT_FILE="/tmp/qs_tts_out.wav"

if command -v kokoro &>/dev/null; then
    kokoro speak "$TEXT" -o "$OUT_FILE"
elif command -v kokoro-cli &>/dev/null; then
    kokoro-cli speak "$TEXT" -o "$OUT_FILE"
else
    echo "Error: kokoro not found" >&2
    exit 1
fi

if [[ ! -f "$OUT_FILE" ]]; then
    echo "Error: Failed to generate audio output" >&2
    exit 1
fi

if command -v pw-play &>/dev/null; then
    pw-play --target tts_output "$OUT_FILE"
elif command -v paplay &>/dev/null; then
    paplay --device=tts_output "$OUT_FILE"
else
    echo "Error: neither pw-play nor paplay found" >&2
    exit 1
fi
