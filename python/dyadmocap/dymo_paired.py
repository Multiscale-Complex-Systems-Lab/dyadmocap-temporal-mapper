"""
dymo_paired.py - paired comparisons of the two conversations, as the MATLAB
pipeline reports them.

    paired_diff_stats(a, b)               pairedDiffStats.m
        paired t-test, Cohen's dz and a BCa bootstrap CI of the mean
        difference (a - b), resampling DYADS (whole pairs).
    paired_group_delta(aG1, bG1, aG2, bG2)  pairedGroupDelta.m
        is the condition effect (GTK - MAN) different in group 1 than in
        group 2? Per dyad: (aG1-bG1) - (aG2-bG2); BCa CI of its mean.

One procedure for every interval in the pipeline, so one methods sentence
covers both languages: BCa, 10,000 resamples, the dyad as the unit, a private
generator seeded 1. The CI is the inference, not the p-value.

Not computed: the sign-flip permutation p and the sign test of
pairedDiffStats.m, and the permutation p of pairedGroupDelta.m. MATLAB
computes them but no table reports them.

Random numbers: MATLAB's bootci and scipy's bootstrap draw different
resamples, so the intervals agree with MATLAB only within Monte Carlo error.
The jackknife and the BCa formula are the same.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import warnings
import numpy as np
from scipy import stats

N_BOOT = 10000
SEED = 1


def bca_mean(d, n_boot=N_BOOT, seed=SEED):
    """bootci(nBoot, {@mean, d}): BCa 95 % CI of mean(d), resampling the
    elements of d (one per dyad). If BCa fails, warn and fall back to the
    percentile interval, as MATLAB's catch block does."""
    d = np.asarray(d, dtype=float)
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            res = stats.bootstrap((d,), np.mean, method="BCa", n_resamples=n_boot,
                                  random_state=np.random.default_rng(seed))
        return (float(res.confidence_interval.low), float(res.confidence_interval.high))
    except Exception as err:
        print("  WARNING: BCa bootstrap failed (%s); percentile interval used instead" % err)
        rng = np.random.default_rng(seed)
        idx = rng.integers(0, d.size, size=(n_boot, d.size))
        bm = d[idx].mean(axis=1)
        return (float(np.quantile(bm, 0.025)), float(np.quantile(bm, 0.975)))


def paired_diff_stats(a, b, n_boot=N_BOOT, seed=SEED):
    """pairedDiffStats.m. a, b: one value per dyad, same dyad order. Pairs
    where either value is not finite are dropped (never zero-filled).

    Returns dict: N, meanA, meanB, meanDiff, sdDiff, dz, t, df, p, ciT, ciBoot,
    pWilcoxon.
    pWilcoxon is the Wilcoxon signed rank p of pairedDiffStats.m
    (signrank(a, b)): zero differences dropped; exact for up to 15 pairs,
    normal approximation above, as MATLAB's default. The approximation (more
    than 15 pairs) has not been compared with MATLAB's signrank.
    """
    a = np.asarray(a, dtype=float).ravel()
    b = np.asarray(b, dtype=float).ravel()
    if a.size != b.size:
        raise ValueError("a and b must have one value per dyad (got %d and %d)" % (a.size, b.size))
    v = np.isfinite(a) & np.isfinite(b)
    a, b = a[v], b[v]
    d = a - b
    S = dict(N=int(d.size), meanA=np.nan, meanB=np.nan, meanDiff=np.nan, sdDiff=np.nan,
             dz=np.nan, t=np.nan, df=np.nan, p=np.nan, ciT=(np.nan, np.nan), ciBoot=(np.nan, np.nan),
             pWilcoxon=np.nan)
    if S["N"] < 2:
        return S                                   # nothing to test: every field NaN

    S["meanA"], S["meanB"], S["meanDiff"] = a.mean(), b.mean(), d.mean()
    S["sdDiff"] = float(np.std(d, ddof=1))         # N-1, as MATLAB's std
    if S["sdDiff"] > 0:
        S["dz"] = S["meanDiff"] / S["sdDiff"]      # Cohen's dz for a paired design

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")            # MATLAB's ttest gives NaN silently
        r = stats.ttest_rel(a, b)
    S["t"], S["p"], S["df"] = float(r.statistic), float(r.pvalue), S["N"] - 1
    if S["sdDiff"] > 0:
        half = stats.t.ppf(0.975, S["df"]) * S["sdDiff"] / np.sqrt(S["N"])
        S["ciT"] = (S["meanDiff"] - half, S["meanDiff"] + half)
        S["ciBoot"] = bca_mean(d, n_boot, seed)    # dyads resampled: the pairs stay together
    else:
        S["ciBoot"] = (S["meanDiff"], S["meanDiff"])   # every difference identical
    nz = int(np.sum(d != 0))
    if nz > 0:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            S["pWilcoxon"] = float(stats.wilcoxon(a, b, zero_method="wilcox",
                                                  method="exact" if nz <= 15 else "approx",
                                                  correction=nz > 15).pvalue)
    return S


def paired_group_delta(aG1, bG1, aG2, bG2, n_boot=N_BOOT, seed=SEED):
    """pairedGroupDelta.m. Group 1 (aG1 GTK, bG1 MAN) and group 2 (aG2, bG2),
    one value per dyad, the SAME dyads in the same order. A dyad is used only
    if all four of its values are finite.

    Returns dict: N, diffG1, diffG2, delta (= diffG1 - diffG2), CI, pPaired.
    """
    arrs = [np.asarray(x, dtype=float).ravel() for x in (aG1, bG1, aG2, bG2)]
    if len({x.size for x in arrs}) > 1:
        raise ValueError("all four inputs must have one value per dyad")
    v = np.all([np.isfinite(x) for x in arrs], axis=0)
    aG1, bG1, aG2, bG2 = [x[v] for x in arrs]
    d1, d2 = aG1 - bG1, aG2 - bG2              # condition effect per dyad, per group
    delta = d1 - d2                            # difference of differences, per dyad
    R = dict(N=int(delta.size), diffG1=np.nan, diffG2=np.nan, delta=np.nan,
             CI=(np.nan, np.nan), pPaired=np.nan)
    if R["N"] < 2:
        print("  WARNING: fewer than 2 dyads have all four values; returning NaN")
        return R
    R["diffG1"], R["diffG2"], R["delta"] = d1.mean(), d2.mean(), delta.mean()
    if np.std(delta, ddof=1) == 0:
        R["CI"], R["pPaired"] = (R["delta"], R["delta"]), 1.0
        return R
    R["pPaired"] = float(stats.ttest_1samp(delta, 0).pvalue)
    R["CI"] = bca_mean(delta, n_boot, seed)
    return R


def group_means(X, cols):
    """mean(X(:, cols), 2, 'omitnan'): one value per dyad, the mean across a
    group's categories (NaN only if all of them are NaN)."""
    X = np.asarray(X, dtype=float)[:, cols]
    n = np.isfinite(X).sum(axis=1)
    s = np.where(np.isfinite(X), X, 0.0).sum(axis=1)
    with np.errstate(invalid="ignore", divide="ignore"):
        return np.where(n > 0, s / np.maximum(n, 1), np.nan)
