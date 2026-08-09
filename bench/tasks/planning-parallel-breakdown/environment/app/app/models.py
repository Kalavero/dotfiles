"""Domain models for the projects app."""

from __future__ import annotations

import time
from dataclasses import asdict, dataclass, field


@dataclass
class User:
    id: int
    email: str
    name: str
    created_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        return asdict(self)


@dataclass
class Project:
    id: int
    name: str
    owner_id: int
    created_at: float = field(default_factory=time.time)

    def to_dict(self) -> dict:
        return asdict(self)
