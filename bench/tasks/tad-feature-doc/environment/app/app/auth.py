"""API-key authentication. Keys map to tiers; tiers will drive rate limits."""


class AuthError(Exception):
    pass


def authenticate(environ, store):
    """Resolve the caller from the WSGI environ.

    Returns {"key", "tier", "owner"} on success, raises AuthError otherwise.
    """
    key = environ.get("HTTP_X_API_KEY", "")
    if not key:
        raise AuthError("missing X-Api-Key header")
    record = store.get_api_key(key)
    if record is None:
        raise AuthError("unknown API key")
    return {
        "key": key,
        "tier": record.get("tier", "free"),
        "owner": record.get("owner", ""),
    }
