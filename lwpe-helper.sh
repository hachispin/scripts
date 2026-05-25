#!/usr/bin/env bash

# sort of improper
set -euo pipefail

err() {
	echo "${1:-}" >&2
}

cmd_exists() {
	command -v "$1" &>/dev/null
}

# prompts typically go to stderr
confirm() {
	read -p "$1 [y/N] " -n 1 -r >&2
	err
	if ! [[ $REPLY =~ ^[Yy]$ ]]; then
		exit 0
	fi
}

# solely comprised of 0-9 and not empty
is_digit() {
	[[ $1 =~ ^[0-9]+$ ]]
}

# pgrep is limited to 15 characters, though this is probably paranoid
for pid in $(pgrep -x 'linux-wallpaper'); do
	if [[ $(basename "$(readlink /proc/"$pid"/exe)") != 'linux-wallpaperengine' ]]; then
		continue
	fi

	err 'linux-wallpaperengine is already running!'
	confirm 'do you want to close it?'
	kill "$pid"
done

# edit this if needed
steam="$HOME/.steam/steam"

# same fallback chain as linux-wallpaperengine when finding assets
for fallback in \
	"$HOME/.local/share/Steam" \
	"$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam" \
	"$HOME/snap/steam/common/.local/share/Steam"; do

	if [[ -d $steam ]]; then
		break
	fi

	steam=$fallback
done

if ! [[ -d $steam ]]; then
	err "couldn't find steam in any of the expected locations"
	err "please install steam or edit initial value of steam variable in $0"
	exit 1
fi

wpe="$steam/steamapps/workshop/content/431960"
assets="$steam/steamapps/common/wallpaper_engine/assets"

if ! [[ -d $wpe ]]; then
	err "couldn't find wallpaper engine on steam, make sure it's installed"
	exit 1
fi

# NOTE: you can set these if you want to skip prompts
lwpe_bin='/home/rain/linux-wallpaperengine/build/output/linux-wallpaperengine'
monitor='eDP-1'

if cmd_exists 'linux-wallpaperengine'; then
	lwpe_bin='linux-wallpaperengine'
elif [[ -z $lwpe_bin ]]; then
	path=
	echo 'linux-wallpaperengine not found in PATH'
	read -rp 'please enter the path to its binary: ' path
	path="${path/#\~/$HOME}"
	lwpe_bin=$(realpath "$path" 2>/dev/null)

	# maybe use a loop. but that's annoying
	if ! cmd_exists "$lwpe_bin"; then
		echo "invalid path -- either doesn't exist or isn't an executable"
		exit 127
	fi
else
	lwpe_bin="${lwpe_bin/#\~/$HOME}"
	if ! cmd_exists "$lwpe_bin"; then
		echo "lwpe_bin is set to an invalid path"
		exit 127
	fi
fi

if ! cmd_exists 'jq'; then
	err 'jq not found, please install using your package manager :)'
	exit 127
fi

if [[ -z $monitor ]]; then
	err 'monitor variable is unset, here are the list of active monitors:'
	err
	xrandr --listactivemonitors >&2
	err
	err 'make sure to enter name (on right-most column), not index'
	read -rp 'choose one, or leave blank: ' monitor
fi

ids=()
for path in "$wpe"/*; do
	base=$(basename "$path")

	if [[ -d $path ]] && is_digit "$base"; then
		ids+=("$base")
	fi
done

num_ids=${#ids[@]}

if ! ((num_ids)); then
	err 'no wallpaper ids found, go install some!'
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

chosen_index=
while true; do
	read -rp "choose an index: " chosen_index

	if ! is_digit "$chosen_index"; then
		err "invalid index: '$chosen_index' is not a (positive) integer"
		continue
	fi

	if ! ((chosen_index >= 0 && chosen_index < num_ids)); then
		err "index ($chosen_index) out of bounds, must be in range 0-$((num_ids - 1))"
		continue
	fi

	break
done

chosen="${ids[$chosen_index]}"
info="$wpe/$chosen/project.json"
wp_type=$(jq -r '.type' "$info")

if ! [[ ${wp_type,,} == "video" ]]; then
	confirm "non-video wallpapers (type=$wp_type) can be unstable and cause crashes, continue?"
fi

# scaling is set to fill as fit (the default) is a little buggy
# add any options here
prefix="$lwpe_bin --assets-dir $assets --scaling fill --disable-mouse"

if [[ -n $monitor ]]; then
	prefix="$prefix --screen-root $monitor"
fi

$prefix "$chosen" &
