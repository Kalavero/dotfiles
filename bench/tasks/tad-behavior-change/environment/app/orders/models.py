"""Order model: statuses and the legal transitions between them."""

from dataclasses import dataclass

STATUSES = (
    "pending",
    "paid",
    "fulfilled",
    "shipped",
    "delivered",
    "cancelled",
)

TRANSITIONS = {
    "pending": {"paid", "cancelled"},
    "paid": {"fulfilled", "cancelled"},
    "fulfilled": {"shipped"},
    "shipped": {"delivered"},
    "delivered": set(),
    "cancelled": set(),
}


class TransitionError(Exception):
    pass


@dataclass
class Order:
    id: str
    account_id: str
    total_cents: int
    status: str = "pending"
    refunded_cents: int = 0

    def transition(self, target):
        if target not in TRANSITIONS[self.status]:
            raise TransitionError(
                f"cannot move order {self.id} from {self.status} to {target}"
            )
        self.status = target
