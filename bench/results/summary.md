# Skills A/B benchmark — full matrix results

Date: 2026-08-09. Agent `codex-acp` (patched to 1.1.14, see bench/README.md),
models `gpt-5.4-mini` and `gpt-5.5`, 17 tasks × 2 arms × 4 reps × 2 models =
272 scored rollouts (68/68 conditions at exactly 4 scored reps; errored
rollouts excluded from every statistic). Raw artifacts stay local
(`bench/jobs/`, gitignored); `summary.md` / `summary.json` here are generated
by `bench/analyze.py`.

## Two caveats that shape every number

1. **Skill-delivery lottery (with-skill arm).** codex-acp's file-read tool
   fails intermittently on `/skills/...` (transient tool-channel failures and
   wrong-path first attempts). gpt-5.5 almost always recovers (retries / shell
   `sed`): skill content acquired in **~92%** of its with-skill runs.
   gpt-5.4-mini recovers only **~45%** of the time. The `with-skill` rows are
   therefore attenuated on mini; the `with-skill (acquired)` rows restrict to
   runs where the skill content was actually read (completed SKILL.md read in
   the trajectory) and are the cleaner mini signal. No-skill arms show zero
   skill contact everywhere (no contamination; the sequential-arms +
   image-rmi protocol held).
2. **Token accounting** is `agent_native_acp` (what the codex ACP stream
   reports; `cost_usd` is null under subscription auth). Totals are
   consistent within this dataset but should be read as approximate.

## Headline: reward, with-skill vs no-skill (mean over the skill's tasks, n=8 per cell, mini n=4 for agent-brief)

| Skill | mini: no-skill → with-skill (acquired-only) | 5.5: no-skill → with-skill | Verdict |
|---|---|---|---|
| planning-and-task-breakdown | 0.47 → 0.64 (0.86) | 0.48 → **0.89** | **(b) strong win** |
| tad | 0.68 → 0.76 (0.86) | 0.63 → **0.89** | **(b) strong win** |
| agent-brief | 0.84 → 0.95 (1.00, n=2) | 0.69 → **0.99** | **(b) strong win** |
| refactor-plan | 0.84 → 0.79 (0.92) | 0.79 → **0.90** | (b) win |
| debugging-and-error-recovery | 0.63 → 0.63 (0.62) | 0.79 → 0.86 | (b) weak win |
| flaky-spec | 0.75 → 0.75 (0.88) | 0.75 → 0.81 | (b) weak win |
| migration-safety | 0.72 → 0.75 (0.92) | 0.50 → 0.57 | (b) weak win |
| **incremental-implementation** | 0.39 → 0.40 (0.40) | 0.40 → 0.40 | **(c) no delta — flag** |
| **tad-to-tickets** | 0.74 → 0.59 (0.51) | 0.80 → 0.79 | **(c) no delta / loses on mini — flag** |

## Token usage, with-skill vs no-skill (mean total tokens per run)

The with-skill arm carries the skill text plus whatever reasoning it triggers:
**+0.5k to +4.2k tokens/run (+2–13%)** in most cells. Notable cells:

| Skill | mini Δ tokens | 5.5 Δ tokens |
|---|---|---|
| migration-safety | +4218 | +900 |
| flaky-spec | **−3532** | +1282 |
| debugging-and-error-recovery | +1141 | +1772 |
| incremental-implementation | +2075 | +452 |
| planning-and-task-breakdown | +2168 | +919 |
| refactor-plan | +1352 | +241 |
| tad | +1594 | +2744 |
| tad-to-tickets | +69 | +1267 |
| agent-brief | +482 | +532 |

Reading: skills cost a small token premium everywhere; the one negative cell
(flaky-spec on mini) comes from the ceilinged order-dependent-pair task where
the no-skill arm wandered longer before landing the fix. On the three
strong-win skills the premium buys +0.2 to +0.4 reward — a good trade. There
is no cell where the skill both costs meaningfully more and wins nothing
except tad-to-tickets on mini (see below).

## Per-skill verdicts (pre-registered buckets)

- **(a) no-skill ceilings — flag loudly:** `migration-safety-subtle-review`
  (5.5 no-skill 1.00), `flaky-spec-order-dependent-pair` (1.00 both models,
  accepted post-hardening), `refactor-plan-execute` (mini 1.00, accepted
  post-hardening). These three tasks measure nothing at this model tier; the
  skills' deltas live on their sibling tasks.
- **(b) with-skill wins — skill measurably helps:**
  - *planning-and-task-breakdown*: the largest effect in the bench
    (+0.41 on 5.5). No-skill plans are horizontal, checkpoint-free, and skip
    acceptance criteria; with-skill plans hit the structural rubric.
  - *tad*: +0.26 on 5.5; the groundedness and feature-flag rules are exactly
    what no-skill runs miss (fabricated paths, no flag in Assumptions).
  - *agent-brief*: +0.30 on 5.5 (0.69 → 0.99).
  - *refactor-plan*: +0.11 on 5.5, carried by the plan task (0.61 → 0.80).
  - *debugging / flaky-spec / migration-safety*: weak positive (+0.06–0.07
    on 5.5). Real but small at 4 reps; treat as directional.
- **(c) no delta or with-skill loses — flag for the improvement phase:**
  - *incremental-implementation*: **0.40 both arms, both models, all 16
    with-skill runs.** Trajectories show the agents never run a single `git`
    command — even the runs that read the skill end-to-end. The skill's core
    behavior (commit per slice) does not transfer to codex-acp at all. This
    is the bench's clearest improvement target: either the skill needs an
    explicit "commit with `git` even when no one asked" instruction, or
    codex-acp's defaults suppress committing and the skill must counter it.
  - *tad-to-tickets*: no delta on 5.5 (0.80 → 0.79) and a **loss** on mini
    (0.74 → 0.59; acquired-only 0.51). The 8-point-split task lands 0.60 in
    both arms — the split rule is not transferring, and on mini the skill
    correlates with worse output. Investigate whether the skill's ticket
    guidance misleads smaller models.

## Reproducibility

`bench/run.sh matrix <task>` per task (or the whole set), then
`python3 bench/analyze.py --jobs-root bench/jobs --out-dir bench/results`.
Protocol and gotchas: `bench/README.md`. The four-worker sweep completed in
~5.5 h wall; two hung gpt-5.5 rollouts were killed and backfilled to keep
every condition at 4 scored reps.
