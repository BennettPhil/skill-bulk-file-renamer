#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# bulk-file-renamer / run.sh
# Main entry point for bulk file renaming operations.
#
# Usage:
#   bash run.sh --mode <seq|date|replace|lower> [--dir DIR] [--dry-run]
#               [--find PATTERN] [--replace REPLACEMENT]
#               [--start N] [--pad WIDTH]
###############################################################################

# Defaults
MODE=""
DIR="."
DRY_RUN=false
FIND_STR=""
REPLACE_STR=""
START=1
PAD=3

usage() {
    cat <<'EOF'
Usage: run.sh --mode <seq|date|replace|lower> [OPTIONS]

Modes:
  seq       Sequential numbering (001-file.jpg, 002-file.jpg, ...)
  date      Date prefix from file mtime (2024-01-15-file.jpg)
  replace   Find/replace in filenames
  lower     Lowercase all filenames

Options:
  --dir DIR          Target directory (default: current directory)
  --dry-run          Preview changes without renaming
  --find PATTERN     Substring to find (required for replace mode)
  --replace STRING   Replacement string (required for replace mode)
  --start N          Starting number for seq mode (default: 1)
  --pad WIDTH        Zero-padding width for seq mode (default: 3)
  -h, --help         Show this help
EOF
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)    MODE="$2"; shift 2 ;;
        --dir)     DIR="$2"; shift 2 ;;
        --dry-run) DRY_RUN=true; shift ;;
        --find)    FIND_STR="$2"; shift 2 ;;
        --replace) REPLACE_STR="$2"; shift 2 ;;
        --start)   START="$2"; shift 2 ;;
        --pad)     PAD="$2"; shift 2 ;;
        -h|--help) usage ;;
        *)
            echo "Error: Unknown argument '$1'" >&2
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$MODE" ]]; then
    echo "Error: --mode is required" >&2
    usage
fi

if [[ ! -d "$DIR" ]]; then
    echo "Error: Directory '$DIR' does not exist" >&2
    exit 1
fi

if [[ "$MODE" == "replace" ]]; then
    if [[ -z "$FIND_STR" ]]; then
        echo "Error: --find is required for replace mode" >&2
        exit 1
    fi
    if [[ -z "$REPLACE_STR" ]]; then
        echo "Error: --replace is required for replace mode" >&2
        exit 1
    fi
fi

# Validate mode
case "$MODE" in
    seq|date|replace|lower) ;;
    *)
        echo "Error: Invalid mode '$MODE'. Must be one of: seq, date, replace, lower" >&2
        exit 1
        ;;
esac

###############################################################################
# Rename functions
###############################################################################

rename_sequential() {
    local dir="$1"
    local dry_run="$2"
    local counter="$START"
    local renamed=0

    # Sort files by name for deterministic ordering
    while IFS= read -r -d '' filepath; do
        local filename
        filename="$(basename "$filepath")"
        local padded
        padded="$(printf "%0${PAD}d" "$counter")"
        local new_name="${padded}-${filename}"

        if [[ "$filename" == "$new_name" ]]; then
            counter=$((counter + 1))
            continue
        fi

        echo "${filename} -> ${new_name}"

        if [[ "$dry_run" == "false" ]]; then
            mv "$dir/$filename" "$dir/$new_name"
        fi

        counter=$((counter + 1))
        renamed=$((renamed + 1))
    done < <(find "$dir" -maxdepth 1 -type f -not -name '.*' -print0 | sort -z)

    if [[ "$renamed" -eq 0 ]]; then
        echo "(no files to rename)"
    fi
}

rename_date_prefix() {
    local dir="$1"
    local dry_run="$2"
    local renamed=0

    while IFS= read -r -d '' filepath; do
        local filename
        filename="$(basename "$filepath")"

        # Get file modification date
        local mdate
        if [[ "$(uname)" == "Darwin" ]]; then
            mdate="$(stat -f '%Sm' -t '%Y-%m-%d' "$filepath")"
        else
            mdate="$(date -r "$filepath" '+%Y-%m-%d' 2>/dev/null || stat -c '%y' "$filepath" | cut -d' ' -f1)"
        fi

        local new_name="${mdate}-${filename}"

        if [[ "$filename" == "$new_name" ]]; then
            continue
        fi

        echo "${filename} -> ${new_name}"

        if [[ "$dry_run" == "false" ]]; then
            mv "$dir/$filename" "$dir/$new_name"
        fi

        renamed=$((renamed + 1))
    done < <(find "$dir" -maxdepth 1 -type f -not -name '.*' -print0 | sort -z)

    if [[ "$renamed" -eq 0 ]]; then
        echo "(no files to rename)"
    fi
}

rename_find_replace() {
    local dir="$1"
    local dry_run="$2"
    local find_str="$3"
    local replace_str="$4"
    local renamed=0

    while IFS= read -r -d '' filepath; do
        local filename
        filename="$(basename "$filepath")"
        local new_name="${filename//$find_str/$replace_str}"

        if [[ "$filename" == "$new_name" ]]; then
            continue
        fi

        echo "${filename} -> ${new_name}"

        if [[ "$dry_run" == "false" ]]; then
            mv "$dir/$filename" "$dir/$new_name"
        fi

        renamed=$((renamed + 1))
    done < <(find "$dir" -maxdepth 1 -type f -not -name '.*' -print0 | sort -z)

    if [[ "$renamed" -eq 0 ]]; then
        echo "(no files matching '$find_str' to rename)"
    fi
}

rename_lowercase() {
    local dir="$1"
    local dry_run="$2"
    local renamed=0

    while IFS= read -r -d '' filepath; do
        local filename
        filename="$(basename "$filepath")"
        local new_name
        new_name="$(echo "$filename" | tr '[:upper:]' '[:lower:]')"

        if [[ "$filename" == "$new_name" ]]; then
            continue
        fi

        echo "${filename} -> ${new_name}"

        if [[ "$dry_run" == "false" ]]; then
            # Two-step rename to handle case-insensitive filesystems (macOS)
            local tmpname=".bulk-rename-tmp-$$-${RANDOM}"
            mv "$dir/$filename" "$dir/$tmpname"
            mv "$dir/$tmpname" "$dir/$new_name"
        fi

        renamed=$((renamed + 1))
    done < <(find "$dir" -maxdepth 1 -type f -not -name '.*' -print0 | sort -z)

    if [[ "$renamed" -eq 0 ]]; then
        echo "(no files to rename)"
    fi
}

###############################################################################
# Main dispatch
###############################################################################

if [[ "$DRY_RUN" == "true" ]]; then
    echo "[DRY RUN] Previewing changes in: $DIR"
else
    echo "Renaming files in: $DIR"
fi

case "$MODE" in
    seq)     rename_sequential "$DIR" "$DRY_RUN" ;;
    date)    rename_date_prefix "$DIR" "$DRY_RUN" ;;
    replace) rename_find_replace "$DIR" "$DRY_RUN" "$FIND_STR" "$REPLACE_STR" ;;
    lower)   rename_lowercase "$DIR" "$DRY_RUN" ;;
esac
