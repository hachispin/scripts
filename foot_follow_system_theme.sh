#!/usr/bin/env bash

set -euo pipefail

# 0 = none, 1 = dark, 2 = light
global_theme=$(
	dbus-send --session --print-reply \
		--dest=org.freedesktop.portal.Desktop \
		/org/freedesktop/portal/desktop \
		org.freedesktop.portal.Settings.Read \
		string:'org.freedesktop.appearance' \
		string:'color-scheme' 2>/dev/null | grep -oP 'uint32 \K\d'
)

config="$HOME/.config/foot/"

case $global_theme in
'0') config+='foot.ini' ;;
'1') config+='dark.ini' ;;
'2') config+='light.ini' ;;

*)
	echo "Unexpected global_theme=$global_theme, using defaults" >&2
	config+='foot'.ini
	;;
esac

foot --config="$config"
