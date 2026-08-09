"""CSV writer for usage exports.

The column order and formatting below are contractual: billing imports this
file into their invoicing system. Do not reorder, rename, or reformat.
"""

import csv

COLUMNS = ["account_id", "month", "kind", "units"]


def write_export(out_path, account_id, month, totals):
    """Write the export CSV. `totals` maps usage kind -> total units.

    Rows are sorted by kind so the output is deterministic for a given
    account/month.
    """
    with open(out_path, "w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(COLUMNS)
        for kind in sorted(totals):
            writer.writerow([account_id, month, kind, totals[kind]])
