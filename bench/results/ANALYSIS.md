# Kalavero Shared Skills — A/B Benchmark Analysis

280 rollouts across 17 task packages and 9 shared skills, tested on `gpt-5.4-mini` and `gpt-5.5` with and without each skill injected.

## Verdict summary

| Skill | gpt-5.4-mini delta | gpt-5.5 delta | Verdict |
|---|---|---|---|
| agent-brief | +0.11 | +0.30 | **Strong helper** |
| planning-and-task-breakdown (feature) | +0.21 | +0.44 | **Strong helper** |
| planning-and-task-breakdown (parallel) | +0.13 | +0.38 | **Strong helper** |
| tad-behavior-change | +0.05 | +0.32 | **Helper on gpt-5.5** |
| tad-feature-doc | +0.10 | +0.21 | **Helper** |
| migration-safety-safe-migration | +0.06 | +0.16 | **Helper** |
| refactoring-plan (execute) | 0.00 | +0.03 | **Ceiling effect** — task too easy |
| refactoring-plan (tangled) | -0.10 | +0.19 | **Mixed** — hurts on mini |
| debugging-duplicate-rows-join | -0.02 | +0.16 | **Mixed** — helps on gpt-5.5 only |
| debugging-race-under-load | +0.03 | -0.03 | **Neutral** |
| flaky-spec-order-dependent-pair | 0.00 | 0.00 | **Ceiling effect** — task too easy |
| flaky-spec-time-bomb | 0.00 | +0.12 | **Helper on gpt-5.5 only** |
| incremental-implementation (cli-slices) | 0.00 | 0.00 | **No measurable effect** |
| incremental-implementation (risk-first) | +0.01 | 0.00 | **No measurable effect** |
| tad-to-tickets-basic | -0.17 | -0.02 | **Hurts on gpt-5.4-mini** |
| tad-to-tickets-split-eight-point | -0.13 | 0.00 | **Hurts on gpt-5.4-mini** |
| migration-safety-subtle-review | -0.01 | 0.00 | **Neutral** |

## Key findings

### 1. Skills that deliver clear value

- **agent-brief** is the biggest winner, especially on gpt-5.5 (+0.30 mean reward). It turns rough ideas into well-formed briefs with acceptance criteria and cited paths.
- **planning-and-task-breakdown** shows the largest and most consistent lift across both models (+0.13 to +0.44). Both the feature-breakdown and parallel-breakdown variants benefit from the skill.
- **tad** (behavior-change and feature-doc) and **migration-safety-safe-migration** show modest but consistent gains.

### 2. Skills with no measurable effect

- **incremental-implementation** shows essentially zero delta on both tasks and both models. The skill is not being invoked by the agent in the benchmark (`n_skill_invocations: 0` across the board), so it cannot influence behavior. The current trigger/description does not cause the agent to self-select it for implementation tasks.
- **refactor-plan-execute** hits a ceiling: both arms score near 1.0, so the skill cannot demonstrate value on this task. The skill delta is carried by the plan-writing task (`refactor-plan-tangled-module`).
- **flaky-spec-order-dependent-pair** also ceilings at 1.0 in both arms.

### 3. Skills that hurt on the smaller model

- **tad-to-tickets** is negative on gpt-5.4-mini for both tasks (-0.17 and -0.13). The skill's hard requirement to ask for user approval before creating tickets conflicts with autonomous benchmark tasks that expect JSON ticket files to be written directly. The skill is also not reliably self-invoked.
- **refactor-plan-tangled-module** is -0.10 on gpt-5.4-mini. The skill is not reliably invoked, and when the model tries to follow it the extra planning structure appears to distract from the concrete task of writing the plan to the requested file path.
- **debugging-duplicate-rows-join** is -0.02 on gpt-5.4-mini (but +0.16 on gpt-5.5), suggesting the smaller model does not benefit from the structured triage.

### 4. Token-usage picture

Token deltas are small relative to the absolute task cost (most arms sit around 17–28k total tokens). The notable exceptions:

- **migration-safety-safe-migration with-skill** uses ~5k more tokens on gpt-5.4-mini, but also scores +0.06 higher.
- **planning-parallel-breakdown with-skill** uses ~3k more tokens on gpt-5.4-mini for a +0.13 reward gain.
- **refactor-plan-tangled-module with-skill** on gpt-5.5 uses ~10k more input tokens for a +0.19 reward gain.

Wall-time generally tracks model size and token volume; no skill introduces a dramatic slowdown except when the agent gets stuck in a long planning loop.

## Recommendations (for a future iteration)

1. **incremental-implementation**: Rewrite the front-matter trigger so the agent self-invokes it on implementation tasks. Add explicit "commit after every slice" and "run tests before continuing" language tied to the verifier's cadence check.
2. **tad-to-tickets**: Remove or conditionalize the "ask for approval before creating" rule when the environment expects local JSON files. Add an auto-trigger checklist.
3. **refactor-plan**: Add an explicit "write the plan to the file path requested by the task" phase and an auto-trigger checklist.
4. **debugging-and-error-recovery**: Add a stronger auto-trigger and consider condensing the triage checklist for the smaller model.
5. **Task hardening**: `refactor-plan-execute` and `flaky-spec-order-dependent-pair` both ceiling without the skill; if measuring skill value on them matters, the tasks need to be made harder for the no-skill arm.

## Caveats

- One planning-feature-breakdown gpt-5.5 with-skill rep and one backfill rep were still running when the captain asked to stop; the final analysis is based on 280 completed rollouts.
- `n_skill_invocations` is 0 for most with-skill rollouts. Benchflow exposes skills to the agent, but the agent often does not explicitly invoke them. Some skills still show reward gains, likely because the skill content leaks into the system context. Skills with zero invocations and zero deltas are not being used at all.
