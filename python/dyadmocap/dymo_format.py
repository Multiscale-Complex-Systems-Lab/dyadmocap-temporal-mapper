"""
dymo_format.py - how numbers are reported: the MATLAB helpers, so that a
Python table or figure says exactly what the MATLAB one says.

    round_table(df)      DYMO_roundTable.m  - 3 significant figures, never
                         coarser than whole numbers; p columns to 3 decimals,
                         floored at .001
    rounding_unit(x, c)  the size of the last digit round_table keeps, used to
                         compare Python with the rounded MATLAB tables
    ci_verdict(ci, ...)  DYMO_ciVerdict.m   - a CI as the sentence it means
    num_text(x)          DYMO_numText.m     - '.826', '-.0622', '2966'
    p_text(p)            DYMO_pText.m       - 'p = .003', 'p < .001'
    sig_color(x)         DYMO_sigColor.m    - black if significant, grey if not
                         (x is a p-value or a two-element CI)

Rounding follows MATLAB's round(): halves go away from zero (numpy's round
goes to even, which would differ on exact halves).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np

N_SIG = 3            # significant figures
P_DECIMALS = 3       # APA: p to 3 decimals ...
P_FLOOR = 0.001      # ... and "p < .001" below that
SIG_COLOUR = (0.0, 0.0, 0.0)
NS_COLOUR = (0.6, 0.6, 0.6)


def _round_half_away(x, d):
    """MATLAB round(x, d): to d decimals, halves away from zero."""
    return float(np.sign(x) * np.floor(abs(x) * 10.0 ** d + 0.5) / 10.0 ** d)


def is_p_column(name):
    """The six spellings of a p column in the tables (DYMO_roundTable)."""
    nm = name.lower()
    return nm in ("p", "pvalue", "p_value") or nm.endswith("_p") or \
        nm.endswith("_pvalue") or nm.endswith("_p_value")


def decimals_kept(x, n_sig=N_SIG):
    """Decimals that keep n_sig significant figures, never fewer than 0."""
    return max(n_sig - 1 - int(np.floor(np.log10(abs(x)))), 0)


def round_value(x, p_column=False, n_sig=N_SIG):
    """One number as DYMO_roundTable writes it. NaN, Inf and 0 pass through."""
    x = float(x)
    if not np.isfinite(x):
        return x
    if p_column:
        if 0 <= x < P_FLOOR:
            x = P_FLOOR                           # floor BEFORE rounding
        return _round_half_away(x, P_DECIMALS)
    if x == 0:
        return x
    return _round_half_away(x, decimals_kept(x, n_sig))


def rounding_unit(x, p_column=False, n_sig=N_SIG):
    """Size of the last digit DYMO_roundTable keeps for the value x."""
    if p_column:
        return 10.0 ** -P_DECIMALS
    if not np.isfinite(x) or x == 0:
        return 0.0
    return 10.0 ** -decimals_kept(x, n_sig)


def round_table(df, n_sig=N_SIG):
    """DYMO_roundTable: a copy of df with every numeric column rounded for
    reporting. Text columns pass through untouched."""
    import pandas as pd
    out = df.copy()
    for col in out.columns:
        if not pd.api.types.is_numeric_dtype(out[col]) or pd.api.types.is_bool_dtype(out[col]):
            continue
        p = is_p_column(col)
        out[col] = [round_value(v, p, n_sig) for v in out[col].astype(float)]
    return out


def write_table(df, path):
    """DYMO_writeTable after DYMO_roundTable: the rounded table as CSV, whole
    numbers without a trailing '.0' (MATLAB writes 30, not 30.0)."""
    round_table(df).to_csv(path, index=False, float_format="%.15g")


def ci_verdict(ci, above_text, below_text, ns_text="No significant difference"):
    """DYMO_ciVerdict: entirely above 0 -> above_text; entirely below 0 ->
    below_text; contains 0 -> ns_text; not computable -> 'Not testable'."""
    ci = np.asarray(ci, dtype=float).ravel()
    if ci.size != 2 or not np.all(np.isfinite(ci)):
        return "Not testable"
    if ci.min() > 0:
        return above_text
    if ci.max() < 0:
        return below_text
    return ns_text


def _strip_leading_zero(s):
    if s.startswith("0."):
        return s[1:]
    if s.startswith("-0."):
        return "-" + s[2:]
    return s


def num_text(x, n_sig=N_SIG):
    """DYMO_numText: 3 significant figures, never coarser than whole numbers,
    leading zero dropped when |x| < 1 (APA)."""
    x = float(x)
    if not np.isfinite(x):
        return "n/a"
    if x == 0:
        return "0"
    d = decimals_kept(x, n_sig)
    s = "%.*f" % (d, _round_half_away(x, d))
    return _strip_leading_zero(s) if abs(x) < 1 else s


def p_text(p):
    """DYMO_pText: 'p = .003', 'p < .001', 'p = n/a'."""
    p = float(p)
    if not np.isfinite(p):
        return "p = n/a"
    if p < 0.001:
        return "p < .001"
    return "p = " + _strip_leading_zero("%.3f" % p)       # sprintf('%.3f'), as MATLAB


def sig_color(x):
    """DYMO_sigColor: (colour, is_significant). x is a p-value (significant
    below .05) or a two-element CI (significant when it excludes 0)."""
    x = np.asarray(x, dtype=float).ravel()
    if x.size == 2 and np.all(np.isfinite(x)):
        is_sig = bool(x.min() > 0 or x.max() < 0)
    elif x.size == 1 and np.isfinite(x[0]):
        is_sig = bool(x[0] < 0.05)
    else:
        is_sig = False
    return (SIG_COLOUR if is_sig else NS_COLOUR), is_sig
