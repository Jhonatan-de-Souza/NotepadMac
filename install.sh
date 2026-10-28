#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
APP_PATH="/Applications/NotepadMac.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

# Let a running app preserve its session before replacing the executable.
if pgrep -f '^/Applications/NotepadMac.app/Contents/MacOS/NotepadMac($| )' >/dev/null; then
    osascript -e 'tell application id "com.local.notepadmac" to quit'
    for attempt in {1..20}; do
        if ! pgrep -f '^/Applications/NotepadMac.app/Contents/MacOS/NotepadMac($| )' >/dev/null; then
            break
        fi
        sleep 0.5
    done
    if pgrep -f '^/Applications/NotepadMac.app/Contents/MacOS/NotepadMac($| )' >/dev/null; then
        echo "NotepadMac is still running. Finish saving or closing it, then run ./install.sh again." >&2
        exit 1
    fi
fi

ditto build/NotepadMac.app "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
touch "$APP_PATH"
# Prefer the installed copy over the development build in Launch Services.
"$LSREGISTER" -u "$PWD/build/NotepadMac.app" || true
"$LSREGISTER" -f "$APP_PATH"
mdimport -i "$APP_PATH"
echo "Installed $APP_PATH. Open Spotlight (Command+Space) and search for Notepad."
