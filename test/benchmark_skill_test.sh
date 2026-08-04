#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=test/test-helper.sh
source "$REPO_DIR/test/test-helper.sh"

test_root="$(mktemp -d "${TMPDIR:-/tmp}/kalavero-benchmark-test.XXXXXX")"
runner="$test_root/runner"
output_dir="$test_root/results"

cleanup() {
  rm -rf "$test_root"
}
trap cleanup EXIT

cat > "$runner" <<'RUNNER'
#!/usr/bin/env bash
set -euo pipefail

if [ "$BENCHMARK_VARIANT" = treatment ]; then
  [ -e "$BENCHMARK_SKILLS_DIR/dotfiles-package/SKILL.md" ]
  mkdir -p "$BENCHMARK_WORKSPACE/lazygit/.config/lazygit"
  printf '\nlazygit\n' >> "$BENCHMARK_WORKSPACE/stow-packages.txt"
  printf '\nbrew "lazygit"\n' >> "$BENCHMARK_WORKSPACE/Brewfile"
  printf '\n| `lazygit/` | Lazygit | Config |\n' >> "$BENCHMARK_WORKSPACE/README.md"
  printf '\n| `lazygit/` | Lazygit configuration |\n' >> "$BENCHMARK_WORKSPACE/CLAUDE.md"
  cat > "$BENCHMARK_WORKSPACE/lazygit/.config/lazygit/config.yml" <<'YAML'
gui:
  showIcons: true
os:
  editPreset: nvim
YAML
else
  [ ! -e "$BENCHMARK_SKILLS_DIR/dotfiles-package" ]
fi
RUNNER
chmod +x "$runner"

"$REPO_DIR/script/benchmark-skill" \
  --skill dotfiles-package \
  --runner "$runner" \
  --output "$output_dir"

assert_file "$output_dir/results.json"
assert_file "$output_dir/add-lazygit-package-control-1.runner.log"
assert_file "$output_dir/add-lazygit-package-treatment-1.grader.log"

"$REPO_DIR/.venv/bin/python3" - "$output_dir/results.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    result = json.load(handle)

assert result["skill"] == "dotfiles-package"
assert [(trial["variant"], trial["passed"]) for trial in result["trials"]] == [
    ("control", False),
    ("treatment", True),
]
PY

pass 'skill benchmark runs paired isolated trials and records objective results'
