#!/usr/bin/env bash

# NOTE(1): This won't work if your accent colour is set to "from colour scheme".
#
# NOTE(2): Profile 0 in your Logitech keyboard will be modified. This should
# only touch keyboard lighting and not other properties (such as custom keys).

keyboard='Logitech G915 WIRELESS RGB MECHANICAL GAMING KEYBOARD'

if [[ $XDG_CURRENT_DESKTOP != 'KDE' ]]; then
	echo 'ERROR: only KDE is supported' >&2
	exit 1
fi

for program in 'kreadconfig6' 'inotifywait' 'asusctl' 'ratbagctl'; do
	if ! command -v "$program" &>/dev/null; then
		echo "ERROR: $program is not installed and in PATH" >&2
		exit 1
	fi
done

# Returns the accent color in hexadecimal.
#
# If `kreadconfig6` succeeds but returns nothing,
# this instead returns the current keyboard color.
#
# Example output: ffffff
get_accent_hex() {
	color=$(kreadconfig6 --file kdeglobals --group General --key AccentColor)

	if [[ -z $color ]]; then
		# Refer to NOTE(1) if you're seeing this.
		echo 'WARNING: no accent color found in kdeglobals' >&2
		return 1
	fi

	IFS=, read -r r g b <<<"$color"
	printf '%02x%02x%02x' "$r" "$g" "$b"
}

# Sets ASUS laptop keyboard and external Logitech keyboard colors.
#
# $1: color in hexadecimal (e.g., ffffff)
set_colors() {
	if ratbagctl "$keyboard" profile 0 get &>/dev/null; then
		ratbagctl "$keyboard" profile 0 led 0 set color "$1" # Logo
		ratbagctl "$keyboard" profile 0 led 1 set color "$1" # Keys
		# Sometimes LEDs turn off for some reason.
		ratbagctl "$keyboard" profile 0 led 0 set mode on
		ratbagctl "$keyboard" profile 0 led 1 set mode on
	else
		echo "Failed to get profile 0; assuming $keyboard is disconnected" >&2
	fi

	# Setting color seems to reset brightness to "high"
	# so this respects the previous brightness level.
	level=$(asusctl leds get | cut -c34-)
	level=${level,,}

	# To prevent annoying flicker if the keyboard is off
	if [[ $level == 'off' ]]; then
		asusctl aura power-tuf --awake false --keyboard
		asusctl aura effect static -c "$1"
		asusctl leds set "$level"
		asusctl aura power-tuf --awake true --keyboard
		return
	fi

	# Flicker still exists here but it's less noticeable
	# (low -> high -> low vs. off -> high -> off)
	asusctl aura effect static -c "$1"
	asusctl leds set "$level"
}

if last_accent="$(get_accent_hex)"; then
	set_colors "$last_accent"
fi

# Don't watch the file (kdeglobals) itself because of renames.
while read -r _dir _event file; do
	[[ $file != 'kdeglobals' ]] && continue
	! accent="$(get_accent_hex)" && continue
	[[ $accent == "$last_accent" ]] && continue

	set_colors "$accent"
	last_accent="$accent"
done < <(inotifywait -m -e close_write,moved_to ~/.config 2>/dev/null)
