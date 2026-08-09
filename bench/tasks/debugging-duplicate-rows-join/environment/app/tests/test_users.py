"""Tests for the user directory listing."""

import seed
from queries import list_users_with_roles
from render import render_user_list


def test_seed_creates_all_users(db_path):
    users = list_users_with_roles(db_path)
    names = {u["name"] for u in users}
    for _, name, _ in seed.USERS:
        assert name in names


def test_render_includes_every_user(db_path):
    output = render_user_list(db_path)
    for _, name, _ in seed.USERS:
        assert name in output


def test_user_with_single_role_renders_once(db_path):
    # Grace Hopper only has the "editor" role.
    output = render_user_list(db_path)
    assert output.count("Grace Hopper") == 1


def test_render_lists_each_user_exactly_once(db_path):
    output = render_user_list(db_path)
    for _, name, _ in seed.USERS:
        occurrences = output.count(name)
        assert occurrences == 1, (
            f"{name} appears {occurrences} times in the rendered user list"
        )
