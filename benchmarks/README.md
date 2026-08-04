# Skill benchmarks

Each task directory contains a user-facing `prompt.md` and an executable `grade.sh`. The grader receives the trial workspace as its first argument and must exit nonzero when the task's objective acceptance criteria are not met.

Run a paired benchmark with an agent-specific runner:

```bash
./script/benchmark-skill \
  --skill dotfiles-package \
  --runner /absolute/path/to/runner \
  --runs 3
```

The harness runs every task in `benchmarks/<skill>/` in a clean, disposable Git repository. Each task is run first as a control and then as a treatment. Treatment exposes all Kalavero skills; control exposes the same set except the skill being measured. It writes logs plus `results.json` and `results.tsv` to `benchmark-results/` by default.

## Runner contract

The runner must be an executable with no required arguments. The harness invokes it with these environment variables:

| Variable | Meaning |
|----------|---------|
| `BENCHMARK_WORKSPACE` | Clean worktree the agent must modify |
| `BENCHMARK_PROMPT_FILE` | Path to the task prompt to give the agent verbatim |
| `BENCHMARK_SKILLS_DIR` | Skills visible to the trial |
| `BENCHMARK_AGENT_HOME` | Isolated home containing `.agents/skills` for the trial |
| `BENCHMARK_VARIANT` | `control` or `treatment` |

Configure the agent to work in `BENCHMARK_WORKSPACE`, use the prompt verbatim, and discover skills from `BENCHMARK_SKILLS_DIR` or `BENCHMARK_AGENT_HOME/.agents/skills`. Do not pass the variant to the agent. The runner's exit code is recorded but does not replace objective grading.

Keep prompts realistic and graders narrow, deterministic, and independent of the skill text. Add at least six tasks before using results to decide whether a skill should be retained.
