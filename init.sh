#!/usr/bin/env bash
# Bash counterpart to init.bat.
#
# Usage:
#   source ./init.sh      # update PATH in the current bash session
#   ./init.sh             # spawn a new interactive bash with PATH set
#
# Either way, tools/ is prepended to PATH so the wrappers (php.sh, node.sh,
# php8.4.sh, phpactor.sh, ...) become callable as bare commands.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$DIR/tools:$PATH"

# If executed rather than sourced, spawn a new interactive bash so the PATH
# change persists for the user's session — mirrors what init.bat does in cmd.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    exec bash -i
fi
