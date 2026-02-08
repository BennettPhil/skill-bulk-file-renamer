#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# bulk-file-renamer / preview.sh
# Standalone dry-run preview. Shows what would be renamed without doing it.
# Delegates to run.sh with --dry-run always enabled.
#
# Usage:
#   bash preview.sh --mode <seq|date|replace|lower> [--dir DIR] [OPTIONS]
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Strip out any --dry-run the user may have passed (we force it on)
ARGS=()
for arg in "$@"; do
    if [[ "$arg" != "--dry-run" ]]; then
        ARGS+=("$arg")
    fi
done

exec bash "$SCRIPT_DIR/run.sh" --dry-run "${ARGS[@]}"
