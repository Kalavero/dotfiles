"""Environment-driven configuration for the widget API."""

import os

HOST = os.environ.get("WIDGET_API_HOST", "0.0.0.0")
PORT = int(os.environ.get("WIDGET_API_PORT", "8080"))
DATA_DIR = os.environ.get("WIDGET_API_DATA_DIR", "./data")
