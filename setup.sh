#!/usr/bin/env bash
# Bash entry point to the setup menu. Delegates to setup.bat under cmd.exe.
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec cmd //c "$DIR/setup.bat" "$@"
