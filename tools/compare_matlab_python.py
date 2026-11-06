"""
compare_matlab_python.py - do the MATLAB and the Python versions give the same
results? Compares every results table the two versions both write, after both
have run on the same data (by default the simulated dyads).

HOW TO RUN (from the repository folder), after
    MATLAB:  DYMO_setup; DYMO_runAll
    Python:  python -m dyadmocap.run_pipeline      (from the python folder)
then
    python tools/compare_matlab_python.py

WHAT IS COMPARED
Tables are matched by file name (both versions name them the same, with the
run tag mednorm_180s). Rows are matched on their label columns (Metric,
Condition, State, ...). The tables are written ROUNDED by both versions (3
significant figures; p to 3 decimals), so:
  * exact numbers (N, means, t, df, p, rho, dz, node counts ...) must agree to
    within one unit of that rounding;
  * bootstrap confidence limits (CI columns, and the Verdict and Stars that
    follow from them) are random resampling with a different random-number
    generator in each language, so they cannot agree exactly. They are
    reported, and flagged only if a limit differs by more than 0.05 or by more
    than 10 % of the interval's width, whichever is larger.
Only aggregate numbers are printed (the largest difference per table).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""
import configparser
import glob
import math
import os
import sys

import numpy as np
import pandas as pd

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TAG = "mednorm_180s"
LABELS = ["Metric", "Condition", "Group", "BehaviouralCategory", "BehaviouralState", "State",
          "Comparison", "Pair", "Contrast", "NodeSizeBand", "Rank", "Name"]
T_INTERVAL = {"CI95_low", "CI95_high"}          # t-based intervals: exact, not bootstrap
BOOT_TEXT = {"Verdict", "Stars"}                # follow from a bootstrap interval


def folders():
    cfg = configparser.ConfigParser(interpolation=None)
    cfg.read(os.path.join(REPO, "dymo_config.ini"), encoding="utf-8")
    paths = dict(cfg["paths"]) if cfg.has_section("paths") else {}
    py = (paths.get("results_dir", "").strip() or os.path.join(REPO, "outputs", "results"))
    ml = (paths.get("matlab_results_dir", "").strip() or os.path.join(REPO, "outputs", "matlab_results"))
    return os.path.join(py, TAG), ml


def tables(root, pattern):
    out = {}
    for f in glob.glob(os.path.join(root, pattern), recursive=True):
        name = os.path.basename(f)
        if name.startswith(("PerDyad_", "CycleMetrics_PerDyad")):
            continue                              # participant-level files are not compared
        out[name] = f
    return out


def unit(x):
    """One unit of 3-significant-figure rounding at the size of x."""
    x = abs(x)
    return 10 ** (math.floor(math.log10(x)) - 2) if x > 0 else 1e-12


def is_boot(col):
    return ("CI" in col and col not in T_INTERVAL) or col.startswith("ci")


def compare(fp, fm):
    a, b = pd.read_csv(fp), pd.read_csv(fm)
    keys = [c for c in LABELS if c in a.columns and c in b.columns]
    if keys:
        for d in (a, b):
            for k in keys:
                d[k] = d[k].astype(str).str.strip()
        m = a.merge(b, on=keys, how="outer", suffixes=("_py", "_m"), indicator=True)
        unmatched = int((m["_merge"] != "both").sum())
        m = m[m["_merge"] == "both"]
    else:
        if len(a) != len(b):
            return "rows differ (%d Python, %d MATLAB)" % (len(a), len(b)), False
        m = a.add_suffix("_py").join(b.add_suffix("_m"))
        unmatched = 0
    exact_bad, boot_bad, text_bad, boot_text = [], [], [], 0
    worst_exact, worst_boot = 0.0, 0.0
    common = [c for c in a.columns if c in b.columns and c not in keys]
    # width of each row's bootstrap interval (MATLAB's), for the tolerance
    boot_cols = [c for c in common if is_boot(c)
                 and pd.api.types.is_numeric_dtype(m[c + "_m"])]
    width = (m[[c + "_m" for c in boot_cols]].max(axis=1)
             - m[[c + "_m" for c in boot_cols]].min(axis=1)).to_numpy() if boot_cols else None
    for c in common:
        x, y = m[c + "_py"], m[c + "_m"]
        if pd.api.types.is_numeric_dtype(x) and pd.api.types.is_numeric_dtype(y):
            for r, (xi, yi) in enumerate(zip(x.astype(float), y.astype(float))):
                if np.isnan(xi) and np.isnan(yi):
                    continue
                if np.isnan(xi) != np.isnan(yi):
                    exact_bad.append("%s (NaN in one version)" % c)
                    continue
                d = abs(xi - yi)
                if is_boot(c):
                    worst_boot = max(worst_boot, d)
                    if d > max(0.05, 0.1 * width[r]):
                        boot_bad.append(c)
                else:
                    worst_exact = max(worst_exact, d / max(abs(xi), abs(yi), 1e-12))
                    tol = 0.001 if c.lower().startswith("p") else unit(max(abs(xi), abs(yi)))
                    if d > tol * 1.0001:
                        exact_bad.append(c)
        else:
            # empty cells are read as NaN, and NaN != NaN, so blank them first
            diff = int((x.fillna("").astype(str).str.strip()
                        != y.fillna("").astype(str).str.strip()).sum())
            if diff:
                if c in BOOT_TEXT:
                    boot_text += diff
                else:
                    text_bad.append(c)
    ok = not exact_bad and not text_bad and not boot_bad and unmatched == 0
    note = "%d rows; exact numbers: largest relative difference %.2g" % (len(m), worst_exact)
    note += "; bootstrap limits: largest difference %.3g" % worst_boot
    if boot_text:
        note += "; %d Verdict/Stars cells differ (bootstrap)" % boot_text
    if unmatched:
        note += "; %d rows in only one version" % unmatched
    if exact_bad:
        note += "; DIFFERENT: " + ", ".join(sorted(set(exact_bad)))
    if text_bad:
        note += "; TEXT DIFFERS: " + ", ".join(sorted(set(text_bad)))
    if boot_bad:
        note += "; bootstrap limits beyond tolerance: " + ", ".join(sorted(set(boot_bad)))
    return note, ok


def main():
    py_root, ml_root = folders()
    py = tables(py_root, "**/*_%s.csv" % TAG)
    ml = tables(ml_root, "*_Results_%s/Tables/*_%s.csv" % (TAG, TAG))
    print("Python tables: %d in %s" % (len(py), py_root))
    print("MATLAB tables: %d in %s\n" % (len(ml), ml_root))
    if not py or not ml:
        print("Run both pipelines first (see the top of this file).")
        return 1
    n_ok = n_all = 0
    for name in sorted(set(py) & set(ml)):
        note, ok = compare(py[name], ml[name])
        n_all += 1
        n_ok += ok
        print("%-4s %s\n     %s" % ("PASS" if ok else "FAIL", name, note))
    only_py, only_ml = sorted(set(py) - set(ml)), sorted(set(ml) - set(py))
    if only_py:
        print("\nOnly in Python (%d): %s" % (len(only_py), ", ".join(only_py)))
    if only_ml:
        print("\nOnly in MATLAB (%d): %s" % (len(only_ml), ", ".join(only_ml)))
    print("\n%d of %d shared tables agree." % (n_ok, n_all))
    return 0 if n_ok == n_all else 1


if __name__ == "__main__":
    sys.exit(main())
