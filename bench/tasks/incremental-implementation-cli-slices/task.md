---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The feature itself is a small stdlib CLI, but the end state spans four
    capabilities with exact output formats, checked by a hidden acceptance
    suite that exercises the real CLI; landing it as one untested blob can
    pass final-state checks while leaving intermediate states unverifiable.
  category: software-engineering
  subcategory: cli-feature-implementation
  category_confidence: high
  task_type:
    - implementation
  modality:
    - source-code
  interface:
    - terminal
  skill_type:
    - domain-procedure
    - tool-workflow
  tags:
    - python
    - cli
    - json
    - pytest
    - git
verifier:
  type: test-script
  timeout_sec: 900.0
agent:
  timeout_sec: 3600.0
sandbox:
  network_mode: public
  build_timeout_sec: 600.0
  os: linux
  cpus: 1
  memory_mb: 4096
  storage_mb: 10240
  gpus: 0
---

Build out the `notes` command-line tool in `/app`. It is a Python 3,
stdlib-only CLI (argparse) that stores notes in a JSON file. A test suite
lives in `/app/tests` — run it from `/app` with `python3 -m pytest tests/ -q`.
Keep that suite passing, and make every command below work exactly as
described: after you finish, an acceptance suite will run these commands
against the real CLI and check their exact output.

Storage: notes are kept as a JSON array in the file given by the global
`--file PATH` option (default `./notes.json`). Each note is an object with
keys `id` (integer, 1-based, incrementing), `text` (string), `tags` (array of
strings), and `created_at` (ISO 8601 timestamp). The storage helpers in
`/app/store.py` (`load_notes`, `save_notes`) already work.

All commands are invoked as `python3 /app/notes.py [--file PATH] <command> ...`:

1. `add TEXT [--tag TAG]...`
   Appends a note and prints exactly `added note <id>` (nothing else).
   Example: `python3 notes.py --file /tmp/n.json add "Buy milk"` prints
   `added note 1`; a second `add` prints `added note 2`.

2. `list [--tag TAG]`
   Prints one line per note, ordered by `id`: `<id>: <text>`. If the note has
   tags, append a space and the tags in square brackets, comma-joined with no
   spaces. With `--tag TAG`, print only notes carrying that tag.
   Example output:
   ```
   1: Buy milk
   2: Call the bank [errands,urgent]
   ```

3. `search QUERY`
   Prints the notes whose `text` contains QUERY as a case-insensitive
   substring, in the same line format as `list`, ordered by `id`.

4. `export`
   Prints the entire JSON array of notes to stdout, pretty-printed with an
   indent of 2.
