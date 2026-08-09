#!/usr/bin/env python3
"""Patch an installed benchflow 0.6.6 so codex-acp works against the current
Codex backend.

Two changes, both idempotent:

1. ``agents/registry.py`` — bump the pinned agent package
   ``@agentclientprotocol/codex-acp@0.0.45`` to ``@1.1.14``. The 0.0.45 bundle
   ships a codex CLI whose transport no longer holds against the current
   backend (reconnect storms, then ACP error 1001). 1.1.14 bundles
   ``@openai/codex ^0.147``, which is verified working.

2. ``acp/runtime.py`` — codex-acp 1.x advertises a ``model`` *config option*
   whose select values are bare names (``gpt-5.4-mini``), while
   ``availableModels`` keep the ``model[effort]`` form for
   ``session/set_model``. Stock benchflow's capability-first dispatch sends
   the bracketed id to the config option and gets ``-32602 Invalid params``.
   Send the bare model name on the config-option path instead.

Usage: patch_benchflow.py [path-to-site-packages/benchflow]
(auto-discovers via `bench --version` when omitted)

Scratch-only: never committed into a benchflow checkout; re-run after every
fresh `uv tool install` of benchflow 0.6.6. Delete once upstream ships a
codex-acp bump.
"""

import pathlib
import shutil
import subprocess
import sys

OLD_PIN = "@agentclientprotocol/codex-acp@0.0.45"
NEW_PIN = "@agentclientprotocol/codex-acp@1.1.14"
OLD_VALUE = """                value=acp_model_id,
                label=\"model\",
"""
NEW_VALUE = """                value=(
                    _codex_model_name(acp_model_id)
                    if agent == "codex-acp"
                    else acp_model_id
                ),
                label=\"model\",
"""


def find_benchflow_dir() -> pathlib.Path:
    if len(sys.argv) > 1:
        return pathlib.Path(sys.argv[1])
    bench = shutil.which("bench")
    if not bench:
        sys.exit("bench not on PATH; pass the benchflow package dir explicitly")
    out = subprocess.run(
        [bench, "--version"], capture_output=True, text=True, check=True
    ).stdout.strip()
    print(f"bench version: {out}")
    # <tool-dir>/bin/bench -> <tool-dir>/lib/python3.13/site-packages/benchflow
    tool_dir = pathlib.Path(bench).resolve().parent.parent
    candidates = list(tool_dir.glob("lib/python3*/site-packages/benchflow"))
    if not candidates:
        sys.exit(f"could not locate benchflow package under {tool_dir}")
    return candidates[0]


def patch_file(path: pathlib.Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        print(f"ok (already patched): {label}")
        return
    if old not in text:
        sys.exit(
            f"anchor not found for {label} in {path} — benchflow version drifted?"
        )
    path.write_text(text.replace(old, new, 1))
    print(f"patched: {label}")


def main() -> None:
    pkg = find_benchflow_dir()
    patch_file(pkg / "agents" / "registry.py", OLD_PIN, NEW_PIN, "codex-acp pin bump")
    patch_file(
        pkg / "acp" / "runtime.py", OLD_VALUE, NEW_VALUE, "bare model id on config-option path"
    )
    for pycache in pkg.rglob("__pycache__"):
        for stale in pycache.glob("*.pyc"):
            stale.unlink()
    print("done")


if __name__ == "__main__":
    main()
