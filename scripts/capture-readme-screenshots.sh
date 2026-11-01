#!/bin/zsh
# Captures the notch area of the main display for the README screenshots.
#
# Usage:  ./scripts/capture-readme-screenshots.sh [shot-name ...]
#   With no arguments every shot below is captured in order. For each shot, put
#   Notchie into the described state, then press Return in this terminal; the
#   capture happens after a short delay so you can move the pointer back over
#   the notch if a hover state is needed.
#
# Requirements: macOS `screencapture`. The terminal app running this script needs
# Screen Recording permission (System Settings > Privacy & Security). This script
# never changes Notchie's settings or permissions.
set -eu
cd "${0:A:h:h}"

out_dir=docs/screenshots
mkdir -p "$out_dir"

typeset -A descriptions=(
  panoramic-notch-hub "Hover the notch: Nook home (Now Playing + calendar + tabs)"
  cinema-trailers     "Open the 🎬 Cinema tab next to the settings gear"
  meeting-controls    "Join a Google Meet/Zoom call so the meeting Live Activity expands"
  ai-usage            "Open the AI tab (Claude Code / Codex usage cards)"
  synced-lyrics       "Play a song and toggle lyrics on the Now Playing card"
  sound-mixer         "Click the computer button on Now Playing to open the sound mixer"
  unified-tray        "Open the tray tab (files / captures / transform / clipboard)"
)
order=(panoramic-notch-hub cinema-trailers meeting-controls ai-usage synced-lyrics sound-mixer unified-tray)
shots=("${@:-${order[@]}}")

# Main display size in points (screencapture -R uses points).
read -r screen_w screen_h <<<"$(osascript -l JavaScript -e '
  ObjC.import("AppKit");
  const f = $.NSScreen.mainScreen.frame;
  `${f.size.width} ${f.size.height}`')"
screen_w=${screen_w%.*}

capture_w=${CAPTURE_WIDTH:-900}
capture_h=${CAPTURE_HEIGHT:-360}
capture_x=$(( (screen_w - capture_w) / 2 ))

for shot in "${shots[@]}"; do
  desc="${descriptions[$shot]:-custom shot}"
  print -n "\n[$shot] $desc\nPress Return to capture in 2 seconds (s = skip): "
  read -r answer
  [[ "$answer" == s ]] && continue
  sleep 2
  target="$out_dir/$shot.png"
  screencapture -x -o -R "${capture_x},0,${capture_w},${capture_h}" "$target"
  print "Saved $target"
done

print "\nDone. Review the images for personal data (clipboard, messages, calendar titles) before committing."
