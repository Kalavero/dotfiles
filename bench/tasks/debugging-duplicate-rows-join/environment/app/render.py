"""Presentation layer: render the user directory as plain text."""

from queries import list_users_with_roles


def render_user_list(db_path="app.db"):
    """Render one line per user: "Name <email> - roles"."""
    lines = []
    for user in list_users_with_roles(db_path):
        lines.append(f"{user['name']} <{user['email']}> - {user['role']}")
    return "\n".join(lines)


if __name__ == "__main__":
    print(render_user_list())
