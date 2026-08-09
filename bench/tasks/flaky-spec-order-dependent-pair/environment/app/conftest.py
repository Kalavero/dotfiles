import sys
from pathlib import Path

# Make the shop package importable from the test suite.
sys.path.insert(0, str(Path(__file__).parent))
