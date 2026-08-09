"""Delivery quotes built on top of the registered shipping plugins."""

from shop.registry import PluginRegistry


def delivery_quote_cents(base_cents):
    """Base price plus the fee of every registered shipping plugin."""
    fees = sum(
        PluginRegistry.get(name)(base_cents) for name in PluginRegistry.names()
    )
    return base_cents + fees
