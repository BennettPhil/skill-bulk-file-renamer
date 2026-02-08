#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# bulk-file-renamer / test.sh
# Automated test suite using temporary directories.
###############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUN="$SCRIPT_DIR/run.sh"
PREVIEW="$SCRIPT_DIR/preview.sh"

PASS=0
FAIL=0
TOTAL=0

# Create a master temp dir; clean up on exit
TMPBASE="$(mktemp -d)"
trap 'rm -rf "$TMPBASE"' EXIT

###############################################################################
# Helpers
###############################################################################

setup_dir() {
    local name="$1"
    local dir="$TMPBASE/$name"
    mkdir -p "$dir"
    echo "$dir"
}

assert_file_exists() {
    local filepath="$1"
    local label="$2"
    TOTAL=$((TOTAL + 1))
    if [[ -f "$filepath" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (file not found: $filepath)"
        FAIL=$((FAIL + 1))
    fi
}

assert_file_not_exists() {
    local filepath="$1"
    local label="$2"
    TOTAL=$((TOTAL + 1))
    if [[ ! -f "$filepath" ]]; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (file unexpectedly exists: $filepath)"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_contains() {
    local output="$1"
    local expected="$2"
    local label="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$output" | grep -qF -- "$expected"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (expected output to contain: '$expected')"
        echo "        Got: $output"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit_nonzero() {
    local label="$1"
    shift
    TOTAL=$((TOTAL + 1))
    if "$@" >/dev/null 2>&1; then
        echo "  FAIL: $label (expected non-zero exit, got 0)"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

# Check that a filename with exact case exists in a directory.
# On case-insensitive FS, -f will match regardless of case, so we use ls.
assert_exact_name_exists() {
    local dir="$1"
    local name="$2"
    local label="$3"
    TOTAL=$((TOTAL + 1))
    if ls "$dir" | grep -qxF -- "$name"; then
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $label (exact name '$name' not found in $dir)"
        FAIL=$((FAIL + 1))
    fi
}

assert_exact_name_not_exists() {
    local dir="$1"
    local name="$2"
    local label="$3"
    TOTAL=$((TOTAL + 1))
    if ls "$dir" | grep -qxF -- "$name"; then
        echo "  FAIL: $label (exact name '$name' still exists in $dir)"
        FAIL=$((FAIL + 1))
    else
        echo "  PASS: $label"
        PASS=$((PASS + 1))
    fi
}

###############################################################################
# Test: Sequential numbering
###############################################################################

echo "--- Test: Sequential numbering ---"

DIR="$(setup_dir seq)"
touch "$DIR/alpha.jpg" "$DIR/beta.jpg" "$DIR/gamma.jpg"

bash "$RUN" --mode seq --dir "$DIR"

assert_file_exists "$DIR/001-alpha.jpg" "seq: 001-alpha.jpg exists"
assert_file_exists "$DIR/002-beta.jpg"  "seq: 002-beta.jpg exists"
assert_file_exists "$DIR/003-gamma.jpg" "seq: 003-gamma.jpg exists"
assert_file_not_exists "$DIR/alpha.jpg" "seq: original alpha.jpg removed"

###############################################################################
# Test: Sequential numbering with custom start and padding
###############################################################################

echo "--- Test: Sequential numbering (custom start/pad) ---"

DIR="$(setup_dir seq-custom)"
touch "$DIR/a.txt" "$DIR/b.txt"

bash "$RUN" --mode seq --dir "$DIR" --start 10 --pad 5

assert_file_exists "$DIR/00010-a.txt" "seq-custom: 00010-a.txt exists"
assert_file_exists "$DIR/00011-b.txt" "seq-custom: 00011-b.txt exists"

###############################################################################
# Test: Date prefix
###############################################################################

echo "--- Test: Date prefix ---"

DIR="$(setup_dir date)"
touch "$DIR/photo.jpg"

bash "$RUN" --mode date --dir "$DIR"

# We don't know the exact date, but the original should be gone
# and exactly one file matching ????-??-??-photo.jpg should exist
assert_file_not_exists "$DIR/photo.jpg" "date: original photo.jpg removed"

TOTAL=$((TOTAL + 1))
DATE_COUNT="$(find "$DIR" -maxdepth 1 -name '????-??-??-photo.jpg' -type f | wc -l | tr -d ' ')"
if [[ "$DATE_COUNT" -eq 1 ]]; then
    echo "  PASS: date: date-prefixed file exists"
    PASS=$((PASS + 1))
else
    echo "  FAIL: date: expected 1 date-prefixed file, found $DATE_COUNT"
    FAIL=$((FAIL + 1))
fi

###############################################################################
# Test: Find/replace
###############################################################################

echo "--- Test: Find/replace ---"

DIR="$(setup_dir replace)"
touch "$DIR/draft-report.txt" "$DIR/draft-notes.txt" "$DIR/readme.txt"

bash "$RUN" --mode replace --dir "$DIR" --find "draft-" --replace "final-"

assert_file_exists "$DIR/final-report.txt"     "replace: final-report.txt exists"
assert_file_exists "$DIR/final-notes.txt"      "replace: final-notes.txt exists"
assert_file_exists "$DIR/readme.txt"           "replace: readme.txt unchanged (no match)"
assert_file_not_exists "$DIR/draft-report.txt" "replace: original draft-report.txt removed"

###############################################################################
# Test: Lowercase
###############################################################################

echo "--- Test: Lowercase ---"

DIR="$(setup_dir lower)"
touch "$DIR/MyPhoto.JPG" "$DIR/README.TXT" "$DIR/already-lower.txt"

bash "$RUN" --mode lower --dir "$DIR"

assert_exact_name_exists "$DIR" "myphoto.jpg"       "lower: myphoto.jpg exists (exact case)"
assert_exact_name_exists "$DIR" "readme.txt"        "lower: readme.txt exists (exact case)"
assert_file_exists "$DIR/already-lower.txt"          "lower: already-lower.txt unchanged"
assert_exact_name_not_exists "$DIR" "MyPhoto.JPG"    "lower: original MyPhoto.JPG removed (exact case)"

###############################################################################
# Test: Dry-run doesn't actually rename
###############################################################################

echo "--- Test: Dry-run ---"

DIR="$(setup_dir dryrun)"
touch "$DIR/file1.txt" "$DIR/file2.txt"

OUTPUT="$(bash "$RUN" --mode seq --dir "$DIR" --dry-run)"

assert_file_exists "$DIR/file1.txt"         "dry-run: file1.txt still exists"
assert_file_exists "$DIR/file2.txt"         "dry-run: file2.txt still exists"
assert_file_not_exists "$DIR/001-file1.txt" "dry-run: 001-file1.txt NOT created"
assert_output_contains "$OUTPUT" "DRY RUN"  "dry-run: output mentions DRY RUN"
assert_output_contains "$OUTPUT" "file1.txt -> 001-file1.txt" "dry-run: output shows planned rename"

###############################################################################
# Test: preview.sh works like --dry-run
###############################################################################

echo "--- Test: preview.sh ---"

DIR="$(setup_dir preview)"
touch "$DIR/MyPic.PNG"

OUTPUT="$(bash "$PREVIEW" --mode lower --dir "$DIR")"

# File should still have its original exact name since preview doesn't rename
assert_exact_name_exists "$DIR" "MyPic.PNG"  "preview: original MyPic.PNG still exists (exact case)"
assert_output_contains "$OUTPUT" "DRY RUN"   "preview: output mentions DRY RUN"
assert_output_contains "$OUTPUT" "MyPic.PNG -> mypic.png" "preview: output shows planned rename"

###############################################################################
# Test: Missing arguments produce useful errors
###############################################################################

echo "--- Test: Missing/invalid arguments ---"

assert_exit_nonzero "error: no --mode" bash "$RUN"
assert_exit_nonzero "error: invalid mode" bash "$RUN" --mode bogus
assert_exit_nonzero "error: replace without --find" bash "$RUN" --mode replace --replace "x"
assert_exit_nonzero "error: replace without --replace" bash "$RUN" --mode replace --find "x"
assert_exit_nonzero "error: nonexistent dir" bash "$RUN" --mode seq --dir "/nonexistent/path"

###############################################################################
# Summary
###############################################################################

echo ""
echo "======================================="
echo "  Results: $PASS passed, $FAIL failed (out of $TOTAL)"
echo "======================================="

if [[ "$FAIL" -gt 0 ]]; then
    exit 1
fi

exit 0
