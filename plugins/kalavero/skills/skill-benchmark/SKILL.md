---
name: skill-benchmark
description: >
  Design and run controlled benchmarks to determine whether an AI coding skill improves outcomes.
  Use when evaluating a skill's usefulness, comparing skill variants, creating benchmark tasks or
  graders, or interpreting benchmark results.
---

# Benchmark AI Coding Skills

Measure the target skill's incremental effect. Compare otherwise identical runs with the skill present and absent.

## Design the task set

- Define the skill's hypothesis and the task types it should improve.
- Create at least six realistic, self-contained tasks. Use past work or seeded defects, not toy prompts.
- Give each task a user-facing prompt and a narrow, deterministic grader with objective acceptance criteria.
- Keep graders independent of the skill text and do not name the skill in prompts.

## Run paired trials

- Use fresh, isolated workspaces for every trial.
- Keep model, runner, prompt, tools, and all non-target skills identical.
- Run a control without the target skill and a treatment with it.
- Alternate control and treatment, and repeat each task three to five times to reduce run-to-run variance.

When a repository provides `script/benchmark-skill`, use it with an agent-specific runner. Read `benchmarks/README.md` for the runner contract and task format before adding tasks or running trials.

## Evaluate outcomes

Use objective task pass rate as the primary measure. Also record regressions, runner failures, time, tokens, and human interventions when available. Compare paired results by task and report the raw counts alongside any aggregate rate.

Retain a skill only when it produces a meaningful improvement without increasing regressions or supervision. Simplify, revise, or remove skills with no measurable benefit. Do not draw a retention decision from a pilot with fewer than six varied tasks.
