"""
dymo_report.py - shared helpers for the stage scripts: printing PASS/FAIL lines, and saving what is printed to a summary
file so nothing has to be copied out of the terminal.

Everything printed through these helpers is aggregate only. Any dyad ID that
slips into an error message is blanked out (dyadXXX) in the summary file.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import re
import sys
import traceback
import numpy as np


def max_rel_diff(a, b):
    """Largest |a-b| / |b| (b the MATLAB value); two NaNs are equal, one NaN is Inf."""
    a = np.asarray(a, dtype=float)
    b = np.asarray(b, dtype=float)
    both_nan = np.isnan(a) & np.isnan(b)
    one_nan = np.isnan(a) ^ np.isnan(b)
    with np.errstate(invalid="ignore", divide="ignore"):
        d = np.abs(a - b) / np.maximum(np.abs(b), 1e-300)
    d[both_nan] = 0.0
    d[one_nan] = np.inf
    return (float(np.max(d)) if d.size else 0.0), d


def report(label, ok, detail):
    """One PASS/FAIL line; returns ok so the caller can AND the verdicts."""
    print("  %-28s %-5s %s" % (label, "PASS" if ok else "FAIL", detail))
    return bool(ok)


class _Tee:
    """Send printed text both to the terminal and into a list."""
    def __init__(self, stream):
        self.stream, self.lines = stream, []

    def write(self, text):
        self.stream.write(text)
        self.lines.append(text)

    def flush(self):
        self.stream.flush()


def run_with_summary(main, summary_file, stage_name):
    """Run main(); save everything it printed (or its error) to summary_file."""
    tee = _Tee(sys.stdout)
    sys.stdout = tee
    try:
        main()
    except Exception:
        print("\n%s STOPPED WITH AN ERROR:" % stage_name)
        print(traceback.format_exc())
    finally:
        sys.stdout = tee.stream
        text = re.sub(r"dyad\d{3}", "dyadXXX", "".join(tee.lines))
        with open(summary_file, "w") as f:
            f.write(text)
        print("\nSummary saved to %s" % summary_file)
