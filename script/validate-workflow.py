#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import sys
from pathlib import Path
from typing import Any

import yaml


SEMVER = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


def error(message: str) -> None:
    raise ValueError(message)


def load_json(path: Path) -> dict[str, Any]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        error(f"{path}: expected a JSON object")
    return payload


def frontmatter(path: Path) -> dict[str, Any]:
    content = path.read_text(encoding="utf-8")
    match = re.match(r"^---\r?\n(.*?)\r?\n---(?:\r?\n|$)", content, re.DOTALL)
    if match is None:
        error(f"{path}: missing YAML frontmatter")

    payload = yaml.safe_load(match.group(1))
    if not isinstance(payload, dict):
        error(f"{path}: frontmatter must be a mapping")
    return payload


def require_string(payload: dict[str, Any], field: str, path: Path) -> str:
    value = payload.get(field)
    if not isinstance(value, str) or not value.strip():
        error(f"{path}: {field} must be a non-empty string")
    return value.strip()


def validate(repo: Path) -> None:
    plugin_root = repo / "plugins" / "kalavero"
    system_skills_path = plugin_root / "skills" / ".system"
    manifest_path = plugin_root / ".claude-plugin" / "plugin.json"
    marketplace_path = repo / ".claude-plugin" / "marketplace.json"

    if system_skills_path.exists() or system_skills_path.is_symlink():
        error(f"{system_skills_path}: plugins must not vendor host-managed system skills")

    manifest = load_json(manifest_path)
    marketplace = load_json(marketplace_path)

    plugin_name = require_string(manifest, "name", manifest_path)
    require_string(manifest, "description", manifest_path)
    version = require_string(manifest, "version", manifest_path)
    if SEMVER.fullmatch(version) is None:
        error(f"{manifest_path}: version must use semantic versioning")

    plugins = marketplace.get("plugins")
    if not isinstance(plugins, list):
        error(f"{marketplace_path}: plugins must be an array")
    matching = [entry for entry in plugins if isinstance(entry, dict) and entry.get("name") == plugin_name]
    if len(matching) != 1:
        error(f"{marketplace_path}: expected one marketplace entry for {plugin_name}")
    if matching[0].get("source") != "./plugins/kalavero":
        error(f"{marketplace_path}: {plugin_name} must source ./plugins/kalavero")

    workflows_dir = repo / ".github" / "workflows"
    workflow_paths = sorted([*workflows_dir.glob("*.yml"), *workflows_dir.glob("*.yaml")])
    for path in workflow_paths:
        workflow = yaml.safe_load(path.read_text(encoding="utf-8"))
        if not isinstance(workflow, dict) or not isinstance(workflow.get("jobs"), dict):
            error(f"{path}: workflow must define a jobs mapping")

    names: dict[str, Path] = {}
    for path in sorted((plugin_root / "agents").glob("*.md")):
        payload = frontmatter(path)
        name = require_string(payload, "name", path)
        require_string(payload, "description", path)
        if name != path.stem:
            error(f"{path}: name must match the filename")
        if name in names:
            error(f"{path}: duplicate workflow name also declared by {names[name]}")
        names[name] = path

    for path in sorted((plugin_root / "commands").glob("*.md")):
        payload = frontmatter(path)
        require_string(payload, "description", path)

    skill_names: dict[str, Path] = {}
    for path in sorted((plugin_root / "skills").glob("**/SKILL.md")):
        payload = frontmatter(path)
        name = require_string(payload, "name", path)
        require_string(payload, "description", path)
        if name != path.parent.name:
            error(f"{path}: skill name must match its directory")
        if name in skill_names:
            error(f"{path}: duplicate skill name also declared by {skill_names[name]}")
        skill_names[name] = path


def main() -> None:
    if len(sys.argv) != 2:
        print("Usage: validate-workflow.py <repository-root>", file=sys.stderr)
        raise SystemExit(2)

    try:
        validate(Path(sys.argv[1]).resolve())
    except (OSError, json.JSONDecodeError, yaml.YAMLError, ValueError) as exception:
        print(f"Workflow validation failed: {exception}", file=sys.stderr)
        raise SystemExit(1) from exception

    print("Workflow validation passed")


if __name__ == "__main__":
    main()
