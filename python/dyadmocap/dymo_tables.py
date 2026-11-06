"""
dymo_tables.py - small table helpers shared by the stage scripts.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""
import numpy as np
import pandas as pd
from scipy import stats

from .dymo_matlab import matlab_median

# ---- cycles ----
CATEGORY_NAMES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]
WHOLE = ["CycleCount", "CycleLenMean", "meanEntropy", "cycleDensity"]
PERCAT = ["winnerProp", "CycleLenMean", "meanEntropy", "cycleDensity", "cycleCategoryCounts"]

# ---- node distances ----
# which of our stored keys is the distance from category A to category B
KEY = {("Both Active", "Both Inactive"): "BA_12", ("Both Inactive", "Both Active"): "BA_21",
       ("Both Active", "Both Active"): "BA_11", ("Both Inactive", "Both Inactive"): "BA_22",
       ("Person 1 Active", "Person 2 Active"): "P_12", ("Person 2 Active", "Person 1 Active"): "P_21",
       ("Person 1 Active", "Person 1 Active"): "P_11", ("Person 2 Active", "Person 2 Active"): "P_22"}


def paired_row(name, a, b):
    """One row of the MATLAB paired table: GTK first, so MeanDiff > 0 = larger in GTK."""
    d = a - b
    n = a.size
    t_res = stats.ttest_rel(a, b)
    se = np.std(d, ddof=1) / np.sqrt(n)
    half = stats.t.ppf(0.975, n - 1) * se
    return dict(Comparison=name, N_dyads=n, MeanGTK=a.mean(), MeanMAN=b.mean(),
                MeanDiff_GTKminusMAN=d.mean(), t=t_res.statistic, df=n - 1, p=t_res.pvalue,
                CI95_low=d.mean() - half, CI95_high=d.mean() + half)


def tables_for_pair(dist, dyads, c1, c2):
    """The paired (6 rows) and correlation (4 rows) tables for one category pair,
    in the paired scripts' naming (c1 = catName1)."""
    from .dymo_correlations import spearman

    def arr(group, frm, to):
        return np.array([dist[group][d][KEY[(frm, to)]] for d in dyads], dtype=float)

    pairs = [(c1, c2), (c2, c1), (c1, c1), (c2, c2)]
    g = {p: arr("GTK", *p) for p in pairs}
    m = {p: arr("MAN", *p) for p in pairs}

    paired, corr = [], []
    for p in pairs:
        v = np.isfinite(g[p]) & np.isfinite(m[p])                   # pairwise deletion
        name = "%s -> %s" % p
        paired.append(paired_row(name, g[p][v], m[p][v]))
        rho, pval = spearman(g[p][v], m[p][v])
        corr.append(dict(Comparison=name, N_dyads=int(v.sum()),
                         MedianGTK=matlab_median(g[p][v]), MedianMAN=matlab_median(m[p][v]),
                         SpearmanRho_GTK_vs_MAN=rho, p=pval))

    # the two averaged rows: need all four inputs finite
    b1, b2, w1, w2 = pairs
    vb = np.isfinite(g[b1]) & np.isfinite(m[b1]) & np.isfinite(g[b2]) & np.isfinite(m[b2])
    paired.append(paired_row("Mean of the two between-category directions",
                             (g[b1][vb] + g[b2][vb]) / 2, (m[b1][vb] + m[b2][vb]) / 2))
    vw = np.isfinite(g[w1]) & np.isfinite(g[w2]) & np.isfinite(m[w1]) & np.isfinite(m[w2])
    paired.append(paired_row("Mean of the two within-category directions",
                             (g[w1][vw] + g[w2][vw]) / 2, (m[w1][vw] + m[w2][vw]) / 2))
    return pd.DataFrame(paired), pd.DataFrame(corr)
