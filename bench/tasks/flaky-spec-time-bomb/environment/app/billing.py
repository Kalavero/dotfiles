"""Billing helpers: trial-window checks for new signups."""

from datetime import datetime, timedelta

TRIAL_DAYS = 30


def trial_active(signup_at: datetime) -> bool:
    """True while ``signup_at`` is still within the TRIAL_DAYS window."""
    return datetime.now() - signup_at < timedelta(days=TRIAL_DAYS)


def trial_expired(signup_at: datetime) -> bool:
    return not trial_active(signup_at)


def days_left_in_trial(signup_at: datetime) -> int:
    """Whole days remaining in the trial window (0 once expired)."""
    remaining = timedelta(days=TRIAL_DAYS) - (datetime.now() - signup_at)
    return max(0, remaining.days)
