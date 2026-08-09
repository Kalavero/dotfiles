---
schema_version: '1.3'
metadata:
  author_name: kalavero
  author_email: noreply@kalavero.local
  difficulty: medium
  difficulty_explanation: >
    The hard part is dialect and encoding detection: one fixture is
    semicolon-delimited, latin-1 encoded, and has quoted fields containing
    the delimiter, so naive csv parsing misreads it; the remaining commands
    are straightforward once loading is right.
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
    - csv
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

Build out the `csvstat` command-line tool in `/app`. It is a Python 3,
stdlib-only CLI (argparse) for inspecting and querying CSV files. A test
suite lives in `/app/tests` — run it from `/app` with
`python3 -m pytest tests/ -q`. Keep that suite passing, and make every
command below work exactly as described: after you finish, an acceptance
suite will run these commands against the real CLI and check their exact
output.

Two fixture files ship in the repo and are used in the examples below:
`/app/fixtures/people.csv` (UTF-8, comma-delimited) and
`/app/fixtures/tricky.csv` (latin-1 encoded, semicolon-delimited, with quoted
fields that contain the delimiter). Your loader must detect the encoding
(`utf-8` or `latin-1`) and the delimiter (one of `,` `;` tab `|`) per file —
do not hardcode per-file behavior.

All commands are invoked as `python3 /app/csvstat.py <command> ...`:

1. `inspect FILE`
   Prints exactly three lines: the detected encoding, the detected delimiter
   in double quotes, and the header columns comma-joined in file order.
   ```
   $ python3 csvstat.py inspect fixtures/tricky.csv
   encoding: latin-1
   delimiter: ";"
   columns: name,city,score
   ```

2. `count FILE`
   Prints `rows: N` where N is the number of data rows (header excluded).
   ```
   $ python3 csvstat.py count fixtures/tricky.csv
   rows: 3
   ```

3. `stats FILE COLUMN`
   For the numeric column COLUMN, prints four lines — `count`, `min`, `max`,
   `mean` — over the non-empty values, each number formatted with two
   decimals:
   ```
   $ python3 csvstat.py stats fixtures/tricky.csv score
   count: 3
   min: 7.25
   max: 9.50
   mean: 8.25
   ```

4. `filter FILE COLUMN VALUE`
   Prints the header row plus every data row where COLUMN equals VALUE
   (exact string match), as comma-separated CSV on stdout (standard
   minimal quoting, one row per line).
   ```
   $ python3 csvstat.py filter fixtures/people.csv department Engineering
   name,department,salary
   Alice,Engineering,95000
   Carol,Engineering,88000
   ```
