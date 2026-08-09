# Idea: exports are slow

Users keep complaining that running a usage export takes forever, especially
the billing folks who export the same accounts every single month. Feels like
we recompute everything from scratch each time?? Maybe we could cache
something — the monthly totals or whatever — so repeat exports are fast.

One hard rule: whatever we do, DO NOT change the CSV format. Billing imports
that file into their invoicing system and last time a column moved it was a
whole incident. Same columns, same order, same everything.

Also let's not bolt on a bunch of new dependencies for this, it's a tiny
tool. And nobody wants a cache admin UI or config knobs — just make repeat
exports fast and keep the numbers right when the underlying usage changes.
