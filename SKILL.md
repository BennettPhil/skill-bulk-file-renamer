---
name: bulk-file-renamer
description: Renames files in bulk with date prefixes, sequential numbers, find-replace, and custom patterns.
version: 0.1.0
license: Apache-2.0
---

# bulk-file-renamer

Composable Unix shell scripts for bulk file renaming. Supports sequential numbering, date prefixes from file modification time, find-and-replace in filenames, and lowercasing. Every operation supports a dry-run mode so you can preview changes before committing.

## Scripts Overview

| Script         | Purpose                                      | Key Flags                                      |
|----------------|----------------------------------------------|------------------------------------------------|
| `run.sh`       | Main entry point - orchestrates all rename ops | `--mode`, `--dir`, `--dry-run`, `--find`, `--replace`, `--start`, `--pad` |
| `preview.sh`   | Standalone dry-run preview                    | `--mode`, `--dir`, `--find`, `--replace`, `--start`, `--pad` |
| `test.sh`      | Automated test suite using temp directories   | (none)                                         |

## Modes

- **seq** - Sequential numbering: `001-file.jpg`, `002-file.jpg`, ...
- **date** - Date prefix from file mtime: `2024-01-15-file.jpg`
- **replace** - Find/replace in filenames: `--find "old" --replace "new"`
- **lower** - Lowercase all filenames

## Pipeline Examples

Preview what sequential numbering would do, then apply:

```bash
# Preview first
bash scripts/preview.sh --mode seq --dir ./photos

# Apply
bash scripts/run.sh --mode seq --dir ./photos
```

Rename with date prefix, starting from a specific directory:

```bash
bash scripts/run.sh --mode date --dir ~/Downloads/screenshots
```

Find and replace across filenames:

```bash
bash scripts/run.sh --mode replace --dir ./docs --find "draft-" --replace "final-"
```

Lowercase everything in current directory:

```bash
bash scripts/run.sh --mode lower --dir .
```

Dry-run to preview without renaming:

```bash
bash scripts/run.sh --mode seq --dir ./photos --dry-run
```

## Input / Output Contract

### Input

| Argument      | Required | Default | Description                                |
|---------------|----------|---------|--------------------------------------------|
| `--mode`      | Yes      | -       | One of: `seq`, `date`, `replace`, `lower`  |
| `--dir`       | No       | `.`     | Target directory containing files to rename |
| `--dry-run`   | No       | off     | Preview changes without renaming            |
| `--find`      | For replace | -    | Substring to find (mode=replace)            |
| `--replace`   | For replace | -    | Replacement string (mode=replace)           |
| `--start`     | No       | `1`     | Starting number for sequential mode         |
| `--pad`       | No       | `3`     | Zero-padding width for sequential mode      |

### Output

- **stdout**: One line per rename in the format `old-name -> new-name`
- **stderr**: Errors and warnings
- **exit 0**: Success (or dry-run completed)
- **exit 1**: Invalid arguments or runtime error
