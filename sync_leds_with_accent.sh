#!/usr/bin/env bash

# NOTE: You must set "Colours" to "Accent colour from wallpaper" in System Settings.

logitech_keyboard='Logitech G915 WIRELESS RGB MECHANICAL GAMING KEYBOARD'

# $1: program name
program_exists() {
	command -v "$1" &>/dev/null
}

if ! program_exists 'asusctl' || ! program_exists 'ratbagctl'; then
	echo 'ERROR: must have both asusctl and ratbagctl in PATH' >&2
	exit 127
fi

# Returns the accent color in hexadecimal.
#
# Example output: ffffff
get_accent_hex() {
	color=$(kreadconfig6 --file kdeglobals --group General --key AccentColor)
	IFS=, read -r r g b <<<"$color"
	printf '%02x%02x%02x' "$r" "$g" "$b"
}

# Sets ASUS laptop keyboard and external Logitech keyboard colors.
#
# $1: color in hexadecimal (e.g., ffffff)
set_colors() {
	if ratbagctl "$logitech_keyboard" profile 0 get &>/dev/null; then
		ratbagctl "$logitech_keyboard" profile 0 led 0 set color "$1" # Logo
		ratbagctl "$logitech_keyboard" profile 0 led 1 set color "$1" # Keys
	else
		echo "Failed to get profile; assuming keyboard is disconnected" >&2
	fi

	# Setting color seems to reset brightness to "high"
	# so this respects the previous brightness level.
	level=$(asusctl leds get | cut -c34-)
	level=${level,,}

	# To prevent annoying flicker if the keyboard is off
	if [[ $level == "off" ]]; then
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

last_accent="$(get_accent_hex)"
set_colors "$last_accent"

# Don't watch the file (kdeglobals) itself because of renames.
while read -r _dir _event file; do
	if [[ "$file" == "kdeglobals" ]]; then
		accent="$(get_accent_hex)"

		# Only call set_colors() when the color changes.
		if [[ "$accent" != "$last_accent" ]]; then
			set_colors "$accent"
			last_accent="$accent"
		fi
	fi
done < <(inotifywait -m -e close_write,moved_to ~/.config 2>/dev/null)
