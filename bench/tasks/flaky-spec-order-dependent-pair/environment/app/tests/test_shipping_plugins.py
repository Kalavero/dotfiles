from shop.registry import PluginRegistry


def _flat_fee(fee_cents):
    return lambda base_cents: fee_cents


class TestShippingPlugins:
    def test_register_express_plugin(self):
        PluginRegistry.register("express", _flat_fee(1000))
        assert "express" in PluginRegistry.names()

    def test_fragile_plugin_fee(self):
        PluginRegistry.register("fragile", _flat_fee(500))
        assert PluginRegistry.get("fragile")(100) == 500

    def test_registered_plugins_are_callable(self):
        PluginRegistry.register("overnight", _flat_fee(2500))
        for name in PluginRegistry.names():
            assert callable(PluginRegistry.get(name))
