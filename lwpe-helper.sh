#!/usr/bin/env bash

set -euo pipefail

# Absolute path to linux-wallpaperengine executable.
#
# Note that tilde (~) doesn't expand here. Use $HOME instead.
lwpe_bin="$HOME/projects/linux-wallpaperengine/build/output/linux-wallpaperengine"

# Monitor name to apply wallpaper to. Leave it blank if you
# want to open a window with the wallpaper applied instead.
#
# Run `xrandr --listactivemonitors` to find monitor names.
monitor='eDP-1'

# Steam installation, which is used to find wallpaper IDs.
#
# Leave this blank unless you encounter errors (e.g., if
# you have steam installed somewhere non-conventional).
steam=''

# Echoes to stderr.
#
# $1: message
err() {
	echo "${1:-}" >&2
}

# Confirmation prompt.
#
# $1: prompt
# $2: default response ('y' or 'n')
confirm() {
	local prompt="$1"
	local default="${2:-n}"

	if [[ "$default" =~ ^[Yy]$ ]]; then
		printf '%s [Y/n] ' "$prompt" >&2
		read -rn 1
		[[ -z "$REPLY" || "$REPLY" =~ ^[Yy]$ ]] || exit 0
	else
		printf '%s [y/N] ' "$prompt" >&2
		read -rn 1
		[[ "$REPLY" =~ ^[Yy]$ ]] || exit 0
	fi

	err
}

# Solely comprised of 0-9 and not empty.
#
# $1: string
is_digit() {
	[[ $1 =~ ^[0-9]+$ ]]
}

if ! command -v 'jq' &>/dev/null; then
	err 'Required program jq not found. Install it using your system package manager.'
	exit 127
fi

# pgrep is limited to 15 characters, though this is probably paranoid
for pid in $(pgrep -x 'linux-wallpaper'); do
	[[ $(basename "$(readlink /proc/"$pid"/exe)") != 'linux-wallpaperengine' ]] &&
		continue

	err 'linux-wallpaperengine is already running!'
	confirm 'Do you want to close it?' 'y'
	kill "$pid"
done

# Uses the same fallback chain as linux-wallpaperengine.
for fallback in \
	"$HOME/.steam/steam" \
	"$HOME/.local/share/Steam" \
	"$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
	"$HOME/snap/steam/common/.local/share/Steam"; do

	[[ -d $steam ]] && break
	steam=$fallback
done

if ! [[ -d $steam ]]; then
	err "Couldn't find steam in any of the expected locations."
	err "Install Steam or, if it *is* installed, edit the steam variable in $0."
	exit 1
fi

wpe="$steam/steamapps/workshop/content/431960"
assets="$steam/steamapps/common/wallpaper_engine/assets"

if ! [[ -d $wpe && -d $assets ]]; then
	err "Couldn't find Wallpaper Engine on Steam, make sure it's installed."
	exit 1
fi

ids=()
for path in "$wpe"/*; do
	base=$(basename "$path")
	[[ -d $path ]] && is_digit "$base" && ids+=("$base")
done

num_ids=${#ids[@]}

if ! ((num_ids)); then
	err 'No wallpaper IDs found, go install some!'
	exit 1
fi

printf "Index  ID          Title\n"
for i in "${!ids[@]}"; do
	id_="${ids[$i]}"
	info="$wpe/$id_/project.json"
	title=$(jq -r '.title' "$info")

	printf "%-6s %-10s  %s\n" "$i" "$id_" "$title"
done

echo

chosen_index=''
while true; do
	read -rp "Choose an index: " chosen_index

	if ! is_digit "$chosen_index"; then
		err "Invalid index: '$chosen_index' is not a (positive) integer"
		continue
	fi

	if ! ((chosen_index >= 0 && chosen_index < num_ids)); then
		err "Index ($chosen_index) out of bounds, must be in range 0-$((num_ids - 1))"
		continue
	fi

	break
done

chosen="${ids[$chosen_index]}"
info="$wpe/$chosen/project.json"
wp_type=$(jq -r '.type' "$info")

[[ ${wp_type,,} == "video" ]] ||
	confirm "Non-video wallpapers (type=$wp_type) can cause crashes, continue?" 'n'

# scaling is set to fill as fit (the default) is a little
# buggy. you can also add/remove any options here
prefix="$lwpe_bin --assets-dir $assets --scaling fill --disable-mouse"
[[ -n $monitor ]] && prefix="$prefix --screen-root $monitor"
$prefix "$chosen" >/tmp/lwpe-helper.log 2>&1 &
