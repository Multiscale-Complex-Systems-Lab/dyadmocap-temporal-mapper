"""
dymo_matlab.py - small helpers that make numpy behave like MATLAB where the
difference could change a DISCRETE decision (a sample kept or dropped, a
label, a count), not just the last digit of a number.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np


def matlab_median(x):
    """Median as MATLAB's median.m computes it (NaN if x contains NaN).

    For an even number of values MATLAB takes the two middle values a <= b and
    returns a + (b - a)/2 (its helper 'meanof'); numpy returns (a + b)/2.
    The two can differ in the last bit. That matters here because the
    sampling rate Fs = 1/median(dt) feeds floor(180 * Fs): a last-bit change
    can turn 9,000 samples into 8,999.
    """
    x = np.sort(np.asarray(x, dtype=float).ravel())
    n = x.size
    if n == 0 or np.isnan(x).any():
        return np.nan
    if n % 2 == 1:
        return float(x[n // 2])
    a, b = x[n // 2 - 1], x[n // 2]
    if np.sign(a) != np.sign(b) or np.isinf(a) or np.isinf(b):
        return float((a + b) / 2)
    return float(a + (b - a) / 2)
