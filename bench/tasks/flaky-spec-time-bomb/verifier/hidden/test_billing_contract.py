"""Hidden contract tests: the trial-window business logic must be unchanged.

Mounted only at verify time. Drives billing.trial_active / trial_expired /
days_left_in_trial with controlled "now" values (via freezegun) and asserts
the real 30-day-window behavior, including the exact boundary.
"""

from datetime import datetime

from freezegun import freeze_time

from billing import days_left_in_trial, trial_active, trial_expired

SIGNUP = datetime(2026, 7, 5, 9, 30)


@freeze_time("2026-07-05 09:30:00")
def test_trial_active_at_signup_moment():
    assert trial_active(SIGNUP)


@freeze_time("2026-07-06 09:30:00")
def test_days_left_one_day_in():
    assert trial_active(SIGNUP)
    assert days_left_in_trial(SIGNUP) == 29


@freeze_time("2026-07-20 12:00:00")
def test_trial_active_mid_window():
    assert trial_active(SIGNUP)
    assert days_left_in_trial(SIGNUP) == 14


@freeze_time("2026-08-04 09:29:00")
def test_trial_active_just_before_boundary():
    assert trial_active(SIGNUP)


@freeze_time("2026-08-04 09:30:00")
def test_trial_expired_exactly_at_boundary():
    assert trial_expired(SIGNUP)
    assert days_left_in_trial(SIGNUP) == 0


@freeze_time("2026-09-01 00:00:00")
def test_trial_expired_well_after_window():
    assert trial_expired(SIGNUP)
    assert days_left_in_trial(SIGNUP) == 0
