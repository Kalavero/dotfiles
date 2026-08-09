"""Existing ad-hoc usage summary, used by the `summary` CLI command."""

from __future__ import annotations

from .storage import Storage


def usage_summary(storage: Storage) -> dict:
    users = storage.all("users")
    projects = storage.all("projects")
    by_owner: dict = {}
    for project in projects:
        by_owner[project["owner_id"]] = by_owner.get(project["owner_id"], 0) + 1
    return {
        "users": len(users),
        "projects": len(projects),
        "projects_by_owner": by_owner,
    }
