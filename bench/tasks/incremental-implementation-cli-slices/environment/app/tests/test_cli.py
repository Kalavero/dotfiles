import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CLI = str(ROOT / "notes.py")


def run_cli(*args):
    return subprocess.run(
        [sys.executable, CLI, *args],
        capture_output=True,
        text=True,
        cwd=str(ROOT),
    )


def test_help_lists_all_subcommands():
    result = run_cli("--help")
    assert result.returncode == 0
    for command in ("add", "list", "search", "export"):
        assert command in result.stdout
