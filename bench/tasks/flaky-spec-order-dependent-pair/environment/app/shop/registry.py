"""Process-wide plugin registry used by the shop's shipping extensions."""


class PluginRegistry:
    """Simple name -> callable registry shared across the whole process."""

    _plugins: dict = {}

    @classmethod
    def register(cls, name, plugin):
        cls._plugins[name] = plugin

    @classmethod
    def get(cls, name):
        return cls._plugins[name]

    @classmethod
    def names(cls):
        return sorted(cls._plugins)

    @classmethod
    def clear(cls):
        cls._plugins = {}
