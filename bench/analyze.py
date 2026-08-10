#!/usr/bin/env python3
"""Aggregate benchflow jobs into reward + token A/B tables.

Walks a jobs root for rollout `result.json` files, groups them by
(task, model, skill_mode), and emits:

- summary.json: full per-rollout records and grouped stats
- summary.md:   human-readable per-task A/B tables (reward and tokens)

Token accounting note (design-report gotcha 4): under subscription auth,
benchflow reports only the token counts the agent's ACP stream exposes
(`agent_result.usage_source`), which for codex-acp can be just the final
message or nothing at all. We record exactly what the artifacts carry and
mark each group's `token_source`; when counts are missing we report wall
time instead and say so. No invented numbers.
"""

import argparse
import json
import pathlib
import statistics
import sys


def load_rollouts(jobs_root: pathlib.Path):
    rollouts = []
    for result_path in sorted(jobs_root.rglob("result.json")):
        try:
            data = json.loads(result_path.read_text())
        except (json.JSONDecodeError, OSError):
            continue
        agent = data.get("agent_result") or {}
        timing_path = result_path.with_name("timing.json")
        wall_sec = None
        if timing_path.exists():
            try:
                timing = json.loads(timing_path.read_text())
                wall_sec = timing.get("total_sec") or timing.get("wall_sec")
                if wall_sec is None and isinstance(timing, dict):
                    nums = [v for v in timing.values() if isinstance(v, (int, float))]
                    wall_sec = sum(nums) if nums else None
            except (json.JSONDecodeError, OSError):
                pass
        rewards = data.get("rewards") or {}
        # Did the agent obtain the bundled skill's content? codex-acp reads it
        # as prompt-visible files, so look for a completed tool call touching
        # SKILL.md in the trajectory (skill_invocations stays 0 for codex).
        got_skill = None
        if data.get("skill_mode") == "with-skill":
            got_skill = False
            for traj in result_path.parent.glob("*/acp_trajectory.jsonl"):
                try:
                    for line in traj.open():
                        ev = json.loads(line)
                        if (
                            ev.get("type") == "tool_call"
                            and ev.get("status") == "completed"
                            and "SKILL.md" in str(ev.get("title", ""))
                        ):
                            got_skill = True
                            break
                except OSError:
                    continue
                if got_skill:
                    break
        rollouts.append(
            {
                "task": data.get("task_name"),
                "agent": data.get("agent_name") or data.get("agent"),
                "model": data.get("model"),
                "arm": data.get("skill_mode"),
                "reward": rewards.get("reward"),
                "skill_invocations": data.get("n_skill_invocations", 0),
                "got_skill": got_skill,
                "input_tokens": agent.get("n_input_tokens") or 0,
                "output_tokens": agent.get("n_output_tokens") or 0,
                "total_tokens": agent.get("total_tokens") or 0,
                "cost_usd": agent.get("cost_usd"),
                "token_source": agent.get("usage_source") or "unavailable",
                "wall_sec": wall_sec,
                "error": data.get("error"),
                "path": str(result_path.relative_to(jobs_root)),
            }
        )
    return rollouts


def group_stats(records):
    # Errored rollouts (hung agent, ACP failure) carry no reward and no
    # honest token counts — exclude them from every statistic and report
    # them separately.
    n_errors = sum(1 for r in records if r["error"])
    records = [r for r in records if not r["error"]]
    rewards = [r["reward"] for r in records if isinstance(r["reward"], (int, float))]
    totals = [r["total_tokens"] for r in records if r["token_source"] != "unavailable"]
    inputs = [r["input_tokens"] for r in records if r["token_source"] != "unavailable"]
    outputs = [r["output_tokens"] for r in records if r["token_source"] != "unavailable"]
    walls = [r["wall_sec"] for r in records if isinstance(r["wall_sec"], (int, float))]
    return {
        "n": len(records),
        "rewards": rewards,
        "reward_mean": statistics.mean(rewards) if rewards else None,
        "reward_min": min(rewards) if rewards else None,
        "reward_max": max(rewards) if rewards else None,
        "total_tokens": totals,
        "total_tokens_mean": statistics.mean(totals) if totals else None,
        "input_tokens_mean": statistics.mean(inputs) if inputs else None,
        "output_tokens_mean": statistics.mean(outputs) if outputs else None,
        "token_source": sorted({r["token_source"] for r in records}),
        "wall_sec_mean": statistics.mean(walls) if walls else None,
        "errors": n_errors,
        "skill_invocations": [r["skill_invocations"] for r in records],
        "skill_acquired": sum(1 for r in records if r["got_skill"]),
    }


def fmt(value, digits=2):
    if value is None:
        return "—"
    if isinstance(value, float):
        return f"{value:.{digits}f}"
    return str(value)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jobs-root", required=True, type=pathlib.Path)
    parser.add_argument("--out-dir", required=True, type=pathlib.Path)
    args = parser.parse_args()

    rollouts = load_rollouts(args.jobs_root)
    if not rollouts:
        print(f"no result.json files under {args.jobs_root}", file=sys.stderr)
        return 1

    groups = {}
    for r in rollouts:
        groups.setdefault((r["task"], r["model"], r["arm"]), []).append(r)
        # Shadow group: with-skill rollouts where the skill content was
        # actually obtained (a completed SKILL.md read in the trajectory).
        if r["arm"] == "with-skill" and r["got_skill"]:
            groups.setdefault((r["task"], r["model"], "with-skill (acquired)"), []).append(r)
    stats = {key: group_stats(recs) for key, recs in groups.items()}

    tasks = sorted({k[0] for k in groups})
    models = sorted({k[1] for k in groups if k[1]})

    lines = ["# Skills A/B results", ""]
    lines.append(
        "Token columns report exactly what benchflow recorded under "
        "subscription auth; `token_source` shows the provenance per arm. "
        "When the source is `unavailable`, wall time is the only honest "
        "proxy (see bench/README.md)."
    )
    lines.append("")
    contamination = []
    for task in tasks:
        lines.append(f"## {task}")
        lines.append("")
        lines.append(
            "| model | arm | n | reward mean | reward spread | tokens mean (in/out/total) | wall mean (s) | token source |"
        )
        lines.append("|---|---|---|---|---|---|---|---|")
        for model in models + ([None] if (task, None, "no-skill") in groups or any(k[0] == task and k[1] is None for k in groups) else []):
            for arm in ("no-skill", "with-skill", "with-skill (acquired)"):
                key = (task, model, arm)
                if key not in stats:
                    continue
                s = stats[key]
                if arm == "no-skill" and any(v > 0 for v in s["skill_invocations"]):
                    contamination.append((task, model))
                arm_label = arm
                if arm == "with-skill":
                    arm_label = f"with-skill (skill read {s['skill_acquired']}/{s['n']})"
                lines.append(
                    "| {model} | {arm} | {n} | {mean} | {lo}–{hi} | {tin}/{tout}/{ttot} | {wall} | {src} |".format(
                        model=model or "oracle",
                        arm=arm_label,
                        n=s["n"],
                        mean=fmt(s["reward_mean"]),
                        lo=fmt(s["reward_min"]),
                        hi=fmt(s["reward_max"]),
                        tin=fmt(s["input_tokens_mean"], 0),
                        tout=fmt(s["output_tokens_mean"], 0),
                        ttot=fmt(s["total_tokens_mean"], 0),
                        wall=fmt(s["wall_sec_mean"], 0),
                        src=",".join(s["token_source"]),
                    )
                )
        # delta rows
        for model in models:
            for with_key, label in (
                ("with-skill", "with − without"),
                ("with-skill (acquired)", "acquired-only with − without"),
            ):
                a = stats.get((task, model, with_key))
                b = stats.get((task, model, "no-skill"))
                if a and b and a["reward_mean"] is not None and b["reward_mean"] is not None:
                    d_reward = a["reward_mean"] - b["reward_mean"]
                    d_tokens = None
                    if a["total_tokens_mean"] and b["total_tokens_mean"]:
                        d_tokens = a["total_tokens_mean"] - b["total_tokens_mean"]
                    lines.append("")
                    lines.append(
                        f"**{model} delta ({label}):** reward {d_reward:+.2f}, "
                        f"total tokens {fmt(d_tokens, 0) if d_tokens is not None else 'unavailable'}"
                    )
        lines.append("")

    if contamination:
        lines.append("## WARNING: possible skill contamination in no-skill arms")
        for task, model in contamination:
            lines.append(f"- {task} ({model}): no-skill rollout invoked a skill")
        lines.append("")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    (args.out_dir / "summary.json").write_text(
        json.dumps(
            {
                "rollouts": rollouts,
                "groups": {
                    "|".join(str(p) for p in key): value for key, value in stats.items()
                },
            },
            indent=2,
        )
    )
    (args.out_dir / "summary.md").write_text("\n".join(lines) + "\n")
    print(f"wrote {args.out_dir / 'summary.md'} ({len(rollouts)} rollouts)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
