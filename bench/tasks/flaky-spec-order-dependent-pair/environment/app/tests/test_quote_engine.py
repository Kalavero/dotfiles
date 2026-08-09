from shop.registry import PluginRegistry
from shop.shipping import delivery_quote_cents


class TestStandardPluginSet:
    """Quote-engine behavior with the shop's standard shipping plugins.

    The plugin set is registered once for the whole class and every test
    exercises the shared configuration, so the state must persist between
    the tests of this class (and is removed again when the class is done).
    """

    @classmethod
    def setup_class(cls):
        # Establish exactly the standard set, whatever ran before.
        PluginRegistry.clear()
        PluginRegistry.register("express", lambda base_cents: 1000)
        PluginRegistry.register("fragile", lambda base_cents: 500)

    @classmethod
    def teardown_class(cls):
        PluginRegistry.clear()

    def test_quote_includes_all_plugin_fees(self):
        assert delivery_quote_cents(2000) == 3500

    def test_plugin_set_is_exactly_the_standard_set(self):
        assert PluginRegistry.names() == ["express", "fragile"]

    def test_fees_are_flat(self):
        # Both standard plugins charge flat fees, so the quote grows 1:1
        # with the base price.
        assert delivery_quote_cents(4000) == 5500
