"""
dymo_categories.py - stage 3 of the Python DYMO port: per-joint normalisation,
the frame-wise activity score, the threshold and the four categories.

Python counterpart of
    Functions/TM/normalizeVelocity.m   (method 'median')  -> normalize_median()
    Functions/TM/categorizeVelocity.m  (threshold 'median') -> categorize()

THE MATHS, in words (median normalisation, run tag mednorm_180s)
    speed_j(t)  = |v_j(t)|                          magnitude FIRST
    r_j(t)      = speed_j(t) / median_t(speed_j)    1 = that joint's typical speed
    a(t)        = mean over the 11 joints of r_j(t) the activity score
    tau         = median_t(a)                       per person, per recording
    Active(t)   = a(t) > tau                        strictly greater
    category    = 1 Both Inactive, 2 Both Active, 3 Person 1 Active, 4 Person 2 Active

IMPORTANT: this is ONLY the category path. The temporal mapper graph (stage 4)
is built from the z-scored SIGNED velocity, never from r or a.

Two details chosen so that no frame can be labelled differently from MATLAB:
  * the mean over the 11 joints is added up joint by joint, left to right,
    then divided by 11. numpy's own mean adds 11 numbers in a different order,
    which can change the last bit of a(t) - and a(t) is compared with tau, so
    in principle one frame could change side. Adding in MATLAB's order removes
    that possibility instead of hoping it does not happen.
  * medians use dymo_matlab.matlab_median. With 8,999 samples (odd) the median
    is a single data value, so this is only a guard.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
from .dymo_matlab import matlab_median

CATEGORY_NAMES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]


# ---------------------------------------------------------------------------
# normalizeVelocity.m, method 'median'
# ---------------------------------------------------------------------------
def normalize_median(v):
    """Speed divided by each joint's median speed. v: N x 11 signed velocity.

    Returns (r, info). info['n_guarded'] counts joints whose median speed was
    0 or not finite: those columns are set to 0 (the joint adds nothing),
    exactly as in MATLAB. info['n_filled'] counts non-finite velocity values.
    """
    v = np.array(v, dtype=float, copy=True)
    v[~np.isfinite(v)] = np.nan
    n_filled = int(np.isnan(v).sum())

    speed = np.abs(v)                                        # 1. magnitude first
    m = np.array([matlab_median(col[~np.isnan(col)]) for col in speed.T])  # 2. 'omitnan'
    guarded = ~np.isfinite(m) | (m <= 0)                     # 3. joint that does not move
    m[guarded] = 1.0
    r = speed / m                                            # 4. ratio to typical
    r[:, guarded] = 0.0

    # keep the dyad if a few values were bad (same rule as MATLAB)
    if n_filled > 0:
        all_nan = np.all(np.isnan(r), axis=0)
        r[:, all_nan] = 0.0
        if np.isnan(r).any():
            r = _fill_nearest_ends(r)
    return r, dict(n_filled=n_filled, n_guarded=int(guarded.sum()), joint_scale=m)


def _fill_nearest_ends(X):
    """fillmissing(X,'linear',1,'EndValues','nearest'): linear inside, the
    nearest good value at the two ends. Only used if velocity has NaNs, which
    stage 2 showed it does not for these data."""
    X = np.array(X, dtype=float, copy=True)
    idx = np.arange(X.shape[0], dtype=float)
    for c in range(X.shape[1]):
        good = ~np.isnan(X[:, c])
        if good.all() or good.sum() < 2:
            continue
        # np.interp holds the first/last good value beyond the ends = 'nearest'
        X[~good, c] = np.interp(idx[~good], idx[good], X[good, c])
    return X


# ---------------------------------------------------------------------------
# categorizeVelocity.m, threshold 'median'
# ---------------------------------------------------------------------------
def activity_score(r):
    """Frame-wise mean over the joints, added joint by joint (MATLAB's order)."""
    s = r[:, 0].copy()
    for j in range(1, r.shape[1]):
        s += r[:, j]
    return s / r.shape[1]


def categorize(r1, r2):
    """The four categories from both partners' normalised velocities.

    Returns a dict with colorvar (1..4 per frame), threshold1, threshold2,
    and the two activity scores.
    """
    if r1.shape[0] != r2.shape[0]:
        raise ValueError("Person 1 and Person 2 must have the same number of rows")
    a1 = activity_score(r1)
    a2 = activity_score(r2)
    tau1 = matlab_median(a1[~np.isnan(a1)])
    tau2 = matlab_median(a2[~np.isnan(a2)])
    active1 = a1 > tau1                  # strictly greater
    active2 = a2 > tau2

    colorvar = np.zeros(a1.shape[0], dtype=int)
    colorvar[~active1 & ~active2] = 1    # Both Inactive
    colorvar[active1 & active2] = 2      # Both Active
    colorvar[active1 & ~active2] = 3     # Person 1 Active
    colorvar[~active1 & active2] = 4     # Person 2 Active
    return dict(colorvar=colorvar, threshold1=tau1, threshold2=tau2,
                activity1=a1, activity2=a2)
