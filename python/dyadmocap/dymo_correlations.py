"""
dymo_correlations.py - stage 5b of the Python pipeline: the Spearman
correlations between conditions, with bootstrap intervals, and the comparison
of two correlations (symmetric vs asymmetric states).

Python counterpart of
    Functions/STATS/spearmanWithCI.m     -> spearman_with_ci()
    Functions/STATS/poolCategories.m     -> pool_categories()
    Functions/STATS/spearmanGroupDelta.m -> spearman_group_delta()
    Functions/STATS/spearmanPairDelta.m  -> spearman_pair_delta()
    Functions/STATS/getSignificanceText.m -> significance_text()

WHAT CAN MATCH MATLAB, AND WHAT CANNOT
  * rho, its p-value and N are deterministic: they must agree to 1e-9.
    rho is the Pearson correlation of tie-averaged ranks. The p-value follows
    MATLAB corr's three-way rule - see spearman() below.
  * The bootstrap intervals and the permutation p-value use random numbers.
    No port reproduces MATLAB's mt19937ar stream, so they can only agree to
    Monte Carlo error. Python uses its own fixed seed (1), so a Python run is
    reproducible on its own terms.

INTERVAL TYPES, reproduced deliberately:
  * spearmanWithCI uses bootci's default, BCa (bias-corrected and
    accelerated), resampling dyads as (x, y) PAIRS. scipy.stats.bootstrap with
    method='BCa', paired=True does the same (scipy >= 1.10).
  * spearman_group_delta and spearman_pair_delta use BCa intervals over
    dyads, as spearmanGroupDelta.m and spearmanPairDelta.m do.

group_delta() (a plain percentile interval, and p-values from Spearman on
STACKED rows, which are anti-conservative) is not used for any table.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import warnings
import numpy as np
from scipy import stats

P_NOTE = ("not valid: Spearman on stacked rows (two rows per dyad), "
          "anti-conservative")


# ---------------------------------------------------------------------------
# Spearman, deterministic part (MATLAB corr(...,'Type','Spearman'))
# ---------------------------------------------------------------------------
def _column_spearman(X, Y):
    """Spearman rho of every column pair (n x B arrays) - columnSpearman.m.
    A constant column gives NaN, as MATLAB's corr does."""
    RX = stats.rankdata(X, axis=0)
    RY = stats.rankdata(Y, axis=0)
    RX = RX - RX.mean(axis=0)
    RY = RY - RY.mean(axis=0)
    with np.errstate(invalid="ignore", divide="ignore"):
        r = (RX * RY).sum(axis=0) / np.sqrt((RX ** 2).sum(axis=0) * (RY ** 2).sum(axis=0))
    return np.where(np.isfinite(r), r, np.nan)    # works for 1-D (scalar) and 2-D input


def _as89_upper(n, S):
    """P(S >= S_obs) for Spearman's S = sum of squared rank differences:
    Best & Roberts (1975), algorithm AS 89, Edgeworth series (n >= 10).
    Written from the published algorithm; constants as published."""
    c = [0.2274, 0.2531, 0.1745, 0.0758, 0.1033, 0.3932,
         0.0879, 0.0151, 0.0072, 0.0831, 0.0131, 4.6e-4]
    b = 1.0 / n
    x = (6.0 * (S - 1) * b / (n * n - 1) - 1.0) * np.sqrt(1.0 / b - 1.0)
    y = x * x
    u = x * b * (c[0] + b * (c[1] + c[2] * b)
                 + y * (-c[3] + b * (c[4] + c[5] * b)
                        - y * b * (c[6] + c[7] * b
                                   - y * (c[8] - c[9] * b + y * b * (c[10] - c[11] * y)))))
    p = u / np.exp(y / 2.0) + stats.norm.sf(x)
    return min(max(p, 0.0), 1.0)


_EXACT_S = {}


def _exact_S_values(n):
    """S over all n! permutations (n <= 9: at most 362,880), cached."""
    if n not in _EXACT_S:
        import itertools
        base = np.arange(1, n + 1)
        perms = np.array(list(itertools.permutations(base)), dtype=np.int64)
        _EXACT_S[n] = ((perms - base) ** 2).sum(axis=1)
    return _EXACT_S[n]


def spearman(x, y):
    """rho and its two-sided p-value, the way MATLAB's corr(...,'Type','Spearman')
    computes them (checked on made-up vectors against MATLAB R2024b, to about
    15 digits):

      ties in x or y      -> t approximation, t = rho*sqrt((n-2)/(1-rho^2)), n-2 df
      no ties, n <= 9     -> exact permutation distribution of S
      no ties, n >= 10    -> AS 89 Edgeworth series (Best & Roberts 1975)

    where S = sum of squared rank differences. The two-sided p is twice the
    smaller tail, capped at 1. Only n = 9 was checked for the exact branch;
    that MATLAB switches at n = 10 exactly is assumed (no analysis here has
    n < 10).
    """
    x = np.asarray(x, dtype=float)
    y = np.asarray(y, dtype=float)
    n = x.size
    rho = float(_column_spearman(x[:, None], y[:, None])[0])
    if not np.isfinite(rho):
        return np.nan, np.nan
    ties = np.unique(x).size < n or np.unique(y).size < n

    if ties:
        if abs(rho) >= 1:
            return rho, 0.0
        t = rho * np.sqrt((n - 2) / (1 - rho ** 2))
        return rho, float(2 * stats.t.sf(abs(t), n - 2))

    d = stats.rankdata(x) - stats.rankdata(y)
    S = float(np.sum(d ** 2))
    if n <= 9:
        vals = _exact_S_values(n)
        p_low = np.mean(vals <= S)            # small S = large rho
        p_high = np.mean(vals >= S)
        return rho, float(min(1.0, 2 * min(p_low, p_high)))
    # S moves in steps of 2, so P(S <= S_obs) = 1 - P(S >= S_obs + 2)
    p_low = 1.0 - _as89_upper(n, S + 2)
    p_high = _as89_upper(n, S)
    return rho, float(min(1.0, 2 * min(p_low, p_high)))


# ---------------------------------------------------------------------------
# spearmanWithCI.m
# ---------------------------------------------------------------------------
def spearman_with_ci(x, y, n_boot=10000, seed=1):
    """rho, p, (CI low, CI high), N - finite pairs only; NaN if N < 3 or
    either variable is constant (N is still returned, as in MATLAB)."""
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    valid = np.isfinite(x) & np.isfinite(y)
    x, y = x[valid], y[valid]
    n = int(x.size)
    if n < 3 or np.unique(x).size < 2 or np.unique(y).size < 2:
        return np.nan, np.nan, (np.nan, np.nan), n
    rho, p = spearman(x, y)

    def stat(a, b, axis=-1):
        # scipy hands resamples with the resample index on the last axis
        return _column_spearman(np.moveaxis(a, axis, 0), np.moveaxis(b, axis, 0))

    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            res = stats.bootstrap((x, y), stat, paired=True, vectorized=True,
                                  method="BCa", n_resamples=n_boot,
                                  random_state=np.random.default_rng(seed))
        ci = (float(res.confidence_interval.low), float(res.confidence_interval.high))
    except Exception as err:                   # MATLAB: warning, CI set to NaN
        print("  WARNING: bootstrap failed (%s); CI set to NaN" % err)
        ci = (np.nan, np.nan)
    return rho, p, ci, n


# ---------------------------------------------------------------------------
# poolCategories.m
# ---------------------------------------------------------------------------
def pool_categories(X_gtk, X_man, idx):
    """Stack the finite (GTK, MAN) pairs of the category columns in idx
    (0-based: symmetric = [0, 1], asymmetric = [2, 3])."""
    xs, ys = [], []
    for c in idx:
        xc, yc = X_gtk[:, c], X_man[:, c]
        v = np.isfinite(xc) & np.isfinite(yc)
        xs.append(xc[v])
        ys.append(yc[v])
    return np.concatenate(xs), np.concatenate(ys)


# ---------------------------------------------------------------------------
# spearmanGroupDelta.m
# ---------------------------------------------------------------------------
def group_delta(xG1, yG1, xG2, yG2, n_boot=10000, n_perm=10000, seed=1):
    """rho per group, delta = rho1 - rho2, percentile bootstrap CI of delta
    (each group resampled on its own rows), and a two-sided permutation p."""
    n1, n2 = xG1.size, xG2.size
    R = dict(rhoG1=np.nan, pG1=np.nan, rhoG2=np.nan, pG2=np.nan, delta=np.nan,
             CI=(np.nan, np.nan), pPerm=np.nan, n1=n1, n2=n2)
    if n1 < 3 or n2 < 3:
        return R
    R["rhoG1"], R["pG1"] = spearman(xG1, yG1)
    R["rhoG2"], R["pG2"] = spearman(xG2, yG2)
    R["delta"] = R["rhoG1"] - R["rhoG2"]

    rng = np.random.default_rng(seed)
    chunk = 2000

    # bootstrap CI of the difference (percentile, MATLAB prctile = 'hazen')
    d_boot = np.empty(n_boot)
    for b0 in range(0, n_boot, chunk):
        nb = min(chunk, n_boot - b0)
        i1 = rng.integers(0, n1, size=(n1, nb))
        i2 = rng.integers(0, n2, size=(n2, nb))
        d_boot[b0:b0 + nb] = (_column_spearman(xG1[i1], yG1[i1])
                              - _column_spearman(xG2[i2], yG2[i2]))
    R["CI"] = tuple(np.nanpercentile(d_boot, [2.5, 97.5], method="hazen"))

    # permutation test: shuffle the group labels over the pooled rows
    x_pool = np.concatenate([xG1, xG2])
    y_pool = np.concatenate([yG1, yG2])
    d_perm = np.empty(n_perm)
    for p0 in range(0, n_perm, chunk):
        npm = min(chunk, n_perm - p0)
        P = np.argsort(rng.random((n1 + n2, npm)), axis=0)   # one permutation per column
        P1, P2 = P[:n1], P[n1:]
        d_perm[p0:p0 + npm] = (_column_spearman(x_pool[P1], y_pool[P1])
                               - _column_spearman(x_pool[P2], y_pool[P2]))
    with np.errstate(invalid="ignore"):
        R["pPerm"] = float(np.mean(np.abs(d_perm) >= abs(R["delta"])))   # NaN counts as not extreme
    return R


# ---------------------------------------------------------------------------
# spearmanGroupDelta.m: used for every reported table (group_delta() above
# is not).
# ---------------------------------------------------------------------------
def _stack_cats(X_gtk, X_man, cols, rows):
    """stackCats.m: the (GTK, MAN) pairs of categories `cols` for the dyads in
    `rows`, stacked, finite pairs only. A dyad drawn twice is stacked twice."""
    x = np.concatenate([X_gtk[rows, c] for c in cols])
    y = np.concatenate([X_man[rows, c] for c in cols])
    ok = np.isfinite(x) & np.isfinite(y)
    return x[ok], y[ok]


def _rho_or_nan(x, y):
    """Spearman rho, or NaN with fewer than 3 pairs or a constant side."""
    if x.size < 3 or np.unique(x).size < 2 or np.unique(y).size < 2:
        return np.nan
    return float(_column_spearman(x, y))


def _bca_over_dyads(statfun, dyad_idx, n_boot, seed):
    """bcaOverDyads: BCa interval of statfun(rows), resampling the DYADS.
    The data handed to the bootstrap is the dyad index vector, so the BCa
    jackknife leaves out one dyad at a time. A fresh generator with the same
    seed on every call gives every interval the same 10,000 dyad draws, as
    MATLAB's fresh RandStream does. A failure gives (NaN, NaN) for this
    interval only, as MATLAB's try/catch does."""
    def stat(ii):
        return statfun(np.asarray(ii, dtype=int))
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            res = stats.bootstrap((dyad_idx,), stat, vectorized=False, method="BCa",
                                  n_resamples=n_boot,
                                  random_state=np.random.default_rng(seed))
        return (float(res.confidence_interval.low), float(res.confidence_interval.high))
    except Exception as err:
        print("  WARNING: bootstrap failed (%s); this interval set to NaN" % err)
        return (np.nan, np.nan)


def spearman_group_delta(X_gtk, X_man, idx_g1, idx_g2, n_boot=10000, seed=1):
    """Symmetric (categories idx_g1) vs asymmetric (idx_g2) Spearman rho,
    GTK against MAN, with dyad-level BCa intervals. X_gtk, X_man: dyads x 4.

    Returns dict: rhoG1, ciG1, rhoG2, ciG2, delta (= rhoG1 - rhoG2), CI,
    nDyads. No p-values: the interval is the inference.
    """
    X_gtk = np.asarray(X_gtk, dtype=float)
    X_man = np.asarray(X_man, dtype=float)
    out = dict(rhoG1=np.nan, ciG1=(np.nan, np.nan), rhoG2=np.nan, ciG2=(np.nan, np.nan),
               delta=np.nan, CI=(np.nan, np.nan), nDyads=0)

    # the frame: dyads with at least one usable pair in the categories used
    use = sorted(set(idx_g1) | set(idx_g2))
    usable = np.any(np.isfinite(X_gtk[:, use]) & np.isfinite(X_man[:, use]), axis=1)
    dyad_idx = np.flatnonzero(usable)
    out["nDyads"] = int(dyad_idx.size)
    if dyad_idx.size < 3:
        print("  WARNING: fewer than 3 dyads in the frame; all NaN")
        return out

    def rho1(rows):
        return _rho_or_nan(*_stack_cats(X_gtk, X_man, idx_g1, rows))

    def rho2(rows):
        return _rho_or_nan(*_stack_cats(X_gtk, X_man, idx_g2, rows))

    def delta(rows):
        return rho1(rows) - rho2(rows)        # NaN if either is NaN

    out["rhoG1"], out["rhoG2"] = rho1(dyad_idx), rho2(dyad_idx)
    out["delta"] = out["rhoG1"] - out["rhoG2"]
    out["ciG1"] = _bca_over_dyads(rho1, dyad_idx, n_boot, seed)
    out["ciG2"] = _bca_over_dyads(rho2, dyad_idx, n_boot, seed)
    out["CI"] = _bca_over_dyads(delta, dyad_idx, n_boot, seed)
    return out


# ---------------------------------------------------------------------------
# DYMO_ciVerdict.m: a confidence interval turned into a sentence
# ---------------------------------------------------------------------------
def ci_verdict(ci, above_text, below_text, ns_text="No significant difference"):
    lo, hi = ci
    if not (np.isfinite(lo) and np.isfinite(hi)):
        return "Not testable"
    if lo > 0:
        return above_text
    if hi < 0:
        return below_text
    return ns_text


def correlation_verdict(ci):
    """A single correlation against zero."""
    return ci_verdict(ci, "Positive association", "Negative association",
                      "No significant association")


def delta_verdict(ci):
    """Symmetric minus asymmetric rho."""
    return ci_verdict(ci, "Symmetric correlation stronger", "Asymmetric correlation stronger")


# ---------------------------------------------------------------------------
# getSignificanceText.m
# ---------------------------------------------------------------------------
def significance_text(p):
    if np.isnan(p):
        return "n.s."
    if p < 0.001:
        return "***"
    if p < 0.01:
        return "**"
    if p < 0.05:
        return "*"
    return "n.s."


# ---------------------------------------------------------------------------
# spearmanPairDelta.m: do two categories differ in consistency? Written from
# the MATLAB function; the bootstrap is the one of _bca_over_dyads above.
# ---------------------------------------------------------------------------
def _rho_of(X_gtk, X_man, c, rows):
    """rhoOf: Spearman rho of category c over the dyads `rows` (finite pairs)."""
    x, y = X_gtk[rows, c], X_man[rows, c]
    v = np.isfinite(x) & np.isfinite(y)
    return _rho_or_nan(x[v], y[v])


def spearman_pair_delta(X_gtk, X_man, i, j, n_boot=10000, seed=1):
    """delta rho = rho(category i) - rho(category j), each rho = Spearman between
    GTK and MAN over dyads. BCa intervals at 95, 99 and 99.9 %, resampling the
    dyads (one draw builds both categories). stars '*', '**', '***' when the
    95 / 99 / 99.9 % interval excludes 0; '' otherwise. i, j: 0-based columns.
    Returns dict i, j, rhoI, rhoJ, delta, CI95, CI99, CI999, stars, nDyads."""
    X_gtk = np.asarray(X_gtk, dtype=float)
    X_man = np.asarray(X_man, dtype=float)
    P = dict(i=i, j=j, rhoI=np.nan, rhoJ=np.nan, delta=np.nan, CI95=(np.nan, np.nan),
             CI99=(np.nan, np.nan), CI999=(np.nan, np.nan), stars="", nDyads=0)
    usable = np.any(np.isfinite(X_gtk[:, [i, j]]) & np.isfinite(X_man[:, [i, j]]), axis=1)
    dyad_idx = np.flatnonzero(usable)
    P["nDyads"] = int(dyad_idx.size)
    if dyad_idx.size < 3:
        return P
    P["rhoI"] = _rho_of(X_gtk, X_man, i, dyad_idx)
    P["rhoJ"] = _rho_of(X_gtk, X_man, j, dyad_idx)
    P["delta"] = P["rhoI"] - P["rhoJ"]
    if not np.isfinite(P["delta"]):
        return P

    def stat(ii):
        ii = np.asarray(ii, dtype=int)
        return _rho_of(X_gtk, X_man, i, ii) - _rho_of(X_gtk, X_man, j, ii)

    for level, key, star in ((0.95, "CI95", "*"), (0.99, "CI99", "**"), (0.999, "CI999", "***")):
        try:
            with warnings.catch_warnings():
                warnings.simplefilter("ignore")
                res = stats.bootstrap((dyad_idx,), stat, vectorized=False, method="BCa",
                                      n_resamples=n_boot, confidence_level=level,
                                      random_state=np.random.default_rng(seed))
            ci = (float(res.confidence_interval.low), float(res.confidence_interval.high))
        except Exception as err:
            print("  WARNING: bootstrap failed (%s)" % err)
            ci = (np.nan, np.nan)
        P[key] = ci
        if np.all(np.isfinite(ci)) and (ci[0] > 0 or ci[1] < 0):
            P["stars"] = star
        else:
            break          # a stricter interval cannot exclude 0 if this one did not
    return P
