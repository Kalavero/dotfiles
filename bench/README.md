# bench/ — kalavero skills A/B benchmark

Empirical A/B benchmark for the 9 shared skills in `plugins/kalavero/skills/`.
Each task package bundles one skill verbatim; the benchmark measures the same
agent on the same task with and without that skill injected
(`--skill-mode with-skill` vs `no-skill`), on rewards **and** on token usage.

Design and tool verdict: skillsbench task format + the `benchflow` CLI
(`bench`), per the design report. Codex-only (`codex-acp`), models
`gpt-5.4-mini` and `gpt-5.5` — the account-advertised codex model ladder;
`gpt-5`/`gpt-5-codex` are rejected by the account. A Claude arm can be added
later if a credential becomes available.

## Prerequisites

- Docker running locally (`--sandbox docker` is fully local).
- `benchflow` CLI (tested on 0.6.6). This repo does not vendor it; install it
  isolated, e.g.:
  ```bash
  uv tool install --python 3.13 'benchflow>=0.6.2,<0.7'
  ```
  (Python 3.14 fails benchflow dependency resolution; use uv-managed 3.13.)
  Point `BENCH_BIN` at the binary if it is not on `PATH`.

  **Required patch for codex runs:** benchflow 0.6.6 pins
  `@agentclientprotocol/codex-acp@0.0.45`, whose bundled codex CLI no longer
  holds a connection to the current Codex backend (reconnect storms, then
  `ACP error 1001`), and its model-id format is rejected by codex-acp 1.x's
  `model` config option. After installing benchflow, run:
  ```bash
  python3 bench/dev/patch_benchflow.py   # idempotent; auto-locates the install
  ```
  It bumps the agent to `@agentclientprotocol/codex-acp@1.1.14` (bundles the
  verified-working codex 0.147) and sends the bare model id on the
  config-option path. Verified by the ACP handshake in the ceiling checks.
- A codex login (`~/.codex/auth.json`). benchflow copies it into the container
  automatically (subscription auth); no API key env vars are needed.

## Layout

- `tasks/<skill>-<slug>/` — the 17 task packages (see the table below). Each
  follows the skillsbench `task.md` package format: `task.md`,
  `environment/Dockerfile` (+ frozen fixtures), `environment/skills/<skill>/`
  (the skill, copied verbatim from `plugins/kalavero/skills/`),
  `oracle/solve.sh`, `verifier/test.sh` writing a scalar to
  `/logs/verifier/reward.txt`.
- `run.sh` — the protocol driver (below).
- `analyze.py` — aggregates jobs dirs into reward + token A/B tables.
- `dev/local-check.sh` — build a task image and run oracle + verifier exactly
  like benchflow does, without benchflow. Authoring/iteration tool.
- `jobs/`, `results/` — run artifacts (gitignored).

## Protocol (baked into `run.sh`)

1. **Oracle gate first.** Every task's oracle must score 1.0 before the task
   enters the matrix: `./run.sh oracle <task|all>`.
2. **Ceiling check second.** One no-skill run on `gpt-5.4-mini`:
   `./run.sh ceiling <task|all>`. A full-reward result means the task is too
   easy — harden it and re-check before it enters the matrix.
3. **Arms of the same task run strictly sequentially, and the docker image is
   removed between arms.** benchflow tags the image `bf__<task>:latest`, keyed
   by task name only; two arms of one task racing on that tag contaminates the
   no-skill arm with the with-skill image (pilot-verified). `run.sh matrix`
   enforces sequential arms and `docker rmi bf__<task>:latest` at every mode
   switch. Different tasks may run concurrently from separate shells.
4. **4 repetitions per arm** (single-task pass rates are noisy; use 8 for any
   headline claim): `BENCH_REPS=8 ./run.sh matrix ...`.
5. **One `--jobs-dir` per condition**: `jobs/<task>-<model>-<arm>/rep-<n>` —
   clean resume semantics and unambiguous analysis.

Then: `./run.sh analyze` writes `results/summary.md` + `results/summary.json`
— per task and model: reward mean/spread per arm, token usage per arm, the
with-skill − no-skill deltas, and a contamination warning if any no-skill
rollout touched a skill.

Pre-registered outcome buckets: (a) no-skill ceilings → task too easy,
redesign; (b) with-skill wins → skill measurable, keep; (c) with-skill loses →
investigate whether the skill misleads.

## Token-usage A/B (and its honest limits)

Per rollout, `analyze.py` reads `result.json`'s `agent_result`
(`n_input_tokens`, `n_output_tokens`, `total_tokens`, `usage_source`,
`cost_usd`) and records them per arm, alongside wall time from `timing.json`.

Under codex **subscription auth**, benchflow 0.6.6's accounting only carries
what the ACP stream exposes (`usage_source: agent_native_acp`) — in practice
the token counts can reflect only the final ACP message, or be entirely
`unavailable`, and `cost_usd` is always null. The analysis therefore:

- reports exactly what the artifacts record, with the `token_source` shown
  per arm — never invented numbers;
- when token counts are `unavailable`, reports mean wall time per arm as the
  only remaining proxy and marks it as such.

If exact per-run token accounting is ever required, the path is routing the
agent through benchflow's LiteLLM proxy with real API keys instead of
subscription auth (a billing decision, out of scope here).

## Task matrix

17 packages covering all 9 skills. (The design brief's "17 packages" with
variants for "incremental-implementation and planning/tad/agent-brief" is
ambiguous — those four variants on top of the matrix's 14 would make 18. We
ship variants for incremental-implementation, planning, and tad; agent-brief
keeps a single task, matching its matrix row, which lists no second
dimension.)

| Skill | Package | What it tests / verifier discriminator |
|---|---|---|
| migration-safety | `migration-safety-subtle-review` | 6 subtle issues (volatile default rewrite, immediate check-constraint/FK validation, non-concurrent index, rename vs running code, in-migration backfill); verifier requires the *mechanism* (lock/rewrite/scan) near each finding, plus 2 safe-op false-positive baits |
| migration-safety | `migration-safety-safe-migration` | Negative control: a safe migration with scary-looking bait (constant default + `null: false` on PG15); correct answer says so and lists what was checked; false-positive count is the score |
| flaky-spec | `flaky-spec-order-dependent-pair` | Two seed-dependent polluters (registry + memoized cache), failing seed given; a stateful tripwire class makes the blanket conftest-wipe answer wrong. **Ceilings on gpt-5.4-mini after 3 hardening rounds** (accepted, documented): the model runs the full characterize→localize→isolate loop unaided and writes class-aware isolation. Kept in the matrix as an efficiency/trajectory data point |
| flaky-spec | `flaky-spec-time-bomb` | `datetime.now()` boundary bomb; full credit only for freezing time, partial for re-pinning the date, capped for sleep/retry |
| debugging-and-error-recovery | `debugging-duplicate-rows-join` | JOIN produces duplicates; hidden test checks the query layer, the UI/render layer must be byte-unchanged, regression test required |
| debugging-and-error-recovery | `debugging-race-under-load` | Race that only fails under load; load test ×3 must pass; added `sleep` rejected; regression test required |
| incremental-implementation | `incremental-implementation-cli-slices` | 4-slice CLI; hidden acceptance suite + git-replay: ≥3 commits, visible suite green at every commit |
| incremental-implementation | `incremental-implementation-risk-first` | Second slicing scenario (CSV import with a risky dialect piece); same git-replay verifier mechanics |
| planning-and-task-breakdown | `planning-feature-breakdown` | Spec → plan; every task needs acceptance criteria + verification + deps + ≤5 files; checkpoints; dependency DAG valid; verticality heuristic |
| planning-and-task-breakdown | `planning-parallel-breakdown` | Adds parallelizable slices + one shared migration that must be called out as sequential/blocking |
| refactor-plan | `refactor-plan-tangled-module` | Plan must put characterization tests first, state the behavior contract (including the pinned quirk), keep the suite green per step |
| refactor-plan | `refactor-plan-execute` | Execute a provided plan; hidden behavior suite pins the quirks exactly, including one the plan deliberately omits; public API unchanged. **Ceilings on gpt-5.4-mini** (accepted, documented): the model spontaneously inventories behavior and writes characterization tests before executing; faithful plan execution is core competence at this tier. The skill delta for refactor-plan is carried by the plan task |
| tad | `tad-feature-doc` | Groundedness: every cited path must exist in the repo; feature flag in Assumptions + removal in Rollout |
| tad | `tad-behavior-change` | Behavior-change variant: Today/After mermaid pair required, same groundedness checks |
| tad-to-tickets | `tad-to-tickets-basic` | TAD → JSON ticket files; every task mapped, estimates in scale, dependencies encoded as a DAG, self-contained descriptions |
| tad-to-tickets | `tad-to-tickets-split-eight-point` | The 8-point task must be split into ≥2 tickets; no estimate-8 ticket allowed |
| agent-brief | `agent-brief-rough-idea` | Rough idea → brief; template sections, 3–7 checkable acceptance criteria, cited paths exist, non-goals present |

## Developing / hardening a task

```bash
bench/dev/local-check.sh bench/tasks/<task>   # build + oracle + verifier, no benchflow
./run.sh gate <task>                          # oracle + ceiling via benchflow
```

Verifiers score outcomes with partial credit and always exit 0; the scalar
goes to `/logs/verifier/reward.txt` and a breakdown to
`/logs/verifier/score.json`. Prompts never name or hint at the skill — the
with-skill arm must discover it, matching how the plugin is consumed.
