from pathlib import Path

FIXTURES = Path(__file__).resolve().parents[1] / "fixtures"


def test_fixtures_exist():
    assert (FIXTURES / "people.csv").is_file()
    assert (FIXTURES / "tricky.csv").is_file()


def test_tricky_fixture_is_not_utf8():
    raw = (FIXTURES / "tricky.csv").read_bytes()
    try:
        raw.decode("utf-8")
    except UnicodeDecodeError:
        return
    raise AssertionError("tricky.csv must not be valid UTF-8")
