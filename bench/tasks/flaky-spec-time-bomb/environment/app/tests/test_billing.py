from datetime import datetime

from billing import days_left_in_trial, trial_active, trial_expired

# A customer who signed up recently.
RECENT_SIGNUP = datetime(2026, 7, 5, 9, 30)

# A customer whose trial ended long ago.
OLD_SIGNUP = datetime(2025, 11, 2, 14, 0)


def test_recent_signup_has_active_trial():
    assert trial_active(RECENT_SIGNUP)


def test_recent_signup_has_days_left():
    assert days_left_in_trial(RECENT_SIGNUP) > 0


def test_old_signup_trial_has_expired():
    assert trial_expired(OLD_SIGNUP)


def test_old_signup_has_no_days_left():
    assert days_left_in_trial(OLD_SIGNUP) == 0


def test_signup_today_is_active():
    assert trial_active(datetime.now())
