#!/usr/bin/env bash

source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/caching.sh"
alt="$HOME/.local/share/serpantinum/src/quickshell/Shell.qml"
if [ -n "$MAIN_QML" ] && quickshell -p "$MAIN_QML" ipc call main forceReload 2>/dev/null; then
    exit 0
fi
if [ -f "$alt" ] && quickshell -p "$alt" ipc call main forceReload 2>/dev/null; then
    exit 0
fi
quickshell ipc call main forceReload
