"""
dymo_loading.py - stage 1 of the Python pipeline: loading and the inclusion rule.

Python counterpart of three MATLAB pieces:
    Functions/TM/FindGTKMANTimes.m    -> find_times()
    Functions/TM/getCommonWindow.m    -> common_window()
    GTK_TM_26June26.m, first section  -> load_group()
      ("Load, trim, check sampling rate, and keep dyads with >= 180 s")

THE RULE, in words
  1. Every file loses its first 25 s (calibration) and last 5 s.
  2. For a dyad, the trimmed GTK and MAN durations are compared; the shorter
     one, minus 3 s at each end, is the length of the STABLE window. The
     window sits in the MIDDLE of each conversation's trimmed recording.
  3. A recording is kept if its stable window holds >= 180 s, measured from the
     file's own time column (seconds, not samples).
  4. A dyad is kept only if BOTH partners are kept.
  5. The sampling rate is measured per file as 1/median(diff(t)); the group
     uses the median over its kept recordings.
  6. Every kept recording is cut to the FIRST 180 s (floor(180*Fs) samples).

Things copied on purpose because they change which samples are kept:
  * the arithmetic is done in the SAME ORDER as the MATLAB code, so that the
    window edges are the same floating-point numbers and a sample that sits
    exactly on an edge is kept or dropped the same way;
  * the dyad-level duration uses the min/max over BOTH partners' files,
    ignoring missing files (MATLAB's min/max skip NaN);
  * medians are taken the MATLAB way (dymo_matlab.matlab_median), because
    Fs feeds floor(180*Fs) and a last-bit difference could change 9,000 samples
    into 8,999;
  * missing values are filled like MATLAB's fillmissing(X, 'linear'):
    linear in the ROW index, straight-line extrapolation at the two ends,
    and a column with fewer than 2 values is left alone.

Not in the Python version: the '% power above 2 Hz' diagnostic column (reported only, it
decides nothing) and the optional low-pass filter (off in this analysis).

Dyads and files come from the dataset index (dymo_settings.DATA_INDEX).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import numpy as np
import pandas as pd

from . import dymo_settings as S
from .dymo_matlab import matlab_median


# ---------------------------------------------------------------------------
# File names
# ---------------------------------------------------------------------------
_INDEX = None


def _index():
    global _INDEX
    if _INDEX is None:
        _INDEX = S.load_index()
    return _INDEX


def dyad_list():
    """The dyads of the dataset, in the index's order."""
    return list(_index()["dyads"])


def file_name(dyad, group, sub):
    """Marker file of one person (sub 1 or 2) in one condition, from the index."""
    entry = _index()["dyads"][dyad]["files"][S.GROUP_KEYS[group]]
    return os.path.join(os.path.dirname(os.path.abspath(S.DATA_INDEX)), entry["Person %d" % sub])


# ---------------------------------------------------------------------------
# Reading a file
# ---------------------------------------------------------------------------
def read_opt_file(path, time_only=False):
    """Read one *_opt.txt export: tab-delimited, header row skipped (plain or
    gzip-compressed: pandas reads .gz directly).

    Returns a float array, 128 columns (or only the time column).
    Anything that is not a number becomes NaN, as with MATLAB's readmatrix.

    float_precision='round_trip' makes pandas convert text to numbers exactly
    (correctly rounded), which is what MATLAB does. The default pandas parser
    can differ in the last bit, and at a window edge that could change which
    sample is kept.
    """
    usecols = [0] if time_only else list(range(S.N_COLUMNS))
    df = pd.read_csv(path, sep="\t", skiprows=1, header=None, usecols=usecols,
                     float_precision="round_trip", low_memory=False)
    df = df.apply(pd.to_numeric, errors="coerce")
    return df.to_numpy(dtype=float)


# ---------------------------------------------------------------------------
# FindGTKMANTimes.m
# ---------------------------------------------------------------------------
def find_times():
    """Original and trimmed time range of every dyad x group x subject.

    One row per (dyad, group, sub), missing files kept as rows full of NaN -
    exactly like the MATLAB table Tymz.
    """
    rows = []
    n_missing = 0
    dyads = dyad_list()
    for d, dyad in enumerate(dyads, start=1):
        for group in S.GROUPS:
            for sub in S.SUBS:
                path = file_name(dyad, group, sub)
                row = dict(Dyad=dyad, Group=group, Sub=sub,
                           MinTime=np.nan, MaxTime=np.nan, OriginalDuration=np.nan,
                           TrimMinTime=np.nan, TrimMaxTime=np.nan, TrimmedDuration=np.nan)
                if os.path.isfile(path):
                    t = read_opt_file(path, time_only=True)[:, 0]
                    min_t = np.nanmin(t)            # MATLAB min() skips NaN
                    max_t = np.nanmax(t)
                    row["MinTime"] = min_t
                    row["MaxTime"] = max_t
                    row["OriginalDuration"] = max_t - min_t
                    trim_min = min_t + S.TRIM_START_SEC
                    trim_max = max_t - S.TRIM_END_SEC
                    if trim_max > trim_min:
                        row["TrimMinTime"] = trim_min
                        row["TrimMaxTime"] = trim_max
                        row["TrimmedDuration"] = trim_max - trim_min
                else:
                    n_missing += 1
                rows.append(row)
        if d % 10 == 0 or d == len(dyads):       # progress, every 10 dyads
            print("  find_times: %d / %d dyads read" % (d, len(dyads)), flush=True)
    times = pd.DataFrame(rows)
    print("find_times: %d files listed, %d missing" % (len(times), n_missing))
    return times


# ---------------------------------------------------------------------------
# getCommonWindow.m
# ---------------------------------------------------------------------------
def common_window(gtk_dur, man_dur, margin_sec):
    """Stable middle window shared by GTK and MAN (seconds from trimmed start)."""
    d_common = min(gtk_dur, man_dur)            # 1. the shorter conversation
    d_stable = d_common - 2 * margin_sec        # 2. minus the margin at both ends
    if d_stable <= 0:
        raise ValueError("Margin too large: no stable middle window remains.")
    mid_gtk = gtk_dur / 2                       # 3. centred in each conversation
    mid_man = man_dur / 2
    return dict(DurationCommonOriginal=d_common,
                DurationStable=d_stable,
                GtkStart=mid_gtk - d_stable / 2, GtkEnd=mid_gtk + d_stable / 2,
                ManStart=mid_man - d_stable / 2, ManEnd=mid_man + d_stable / 2)


# ---------------------------------------------------------------------------
# fillmissing(X, 'linear') - MATLAB's default behaviour
# ---------------------------------------------------------------------------
def fill_missing_linear(X):
    """Fill NaNs column by column, like MATLAB's fillmissing(X, 'linear').

    Interpolation is along the ROW index (1, 2, 3, ...), not the time column.
    Leading/trailing NaNs are extrapolated along the line through the first
    (or last) two good values. A column with fewer than 2 good values is left
    as it is.
    """
    X = np.array(X, dtype=float, copy=True)
    idx = np.arange(X.shape[0], dtype=float)
    for c in range(X.shape[1]):
        col = X[:, c]
        good = ~np.isnan(col)
        if good.all() or good.sum() < 2:
            continue
        xg, yg = idx[good], col[good]
        filled = np.interp(idx, xg, yg)
        # straight-line extrapolation at the two ends
        left = idx < xg[0]
        filled[left] = yg[0] + (idx[left] - xg[0]) * (yg[1] - yg[0]) / (xg[1] - xg[0])
        right = idx > xg[-1]
        filled[right] = yg[-1] + (idx[right] - xg[-1]) * (yg[-1] - yg[-2]) / (xg[-1] - xg[-2])
        col[~good] = filled[~good]
    return X


# ---------------------------------------------------------------------------
# The first section of GTK_TM_26June26.m / MAN_TM_26June26.m
# ---------------------------------------------------------------------------
def load_group(group, times):
    """Load, trim, measure Fs and apply the inclusion rule for one condition.

    Returns
      data : dict  dyad id -> [array Person 1, array Person 2], each cut to the
             uniform window (N x 128). Only included dyads appear.
      log  : DataFrame, one row per recording, the same columns as the MATLAB
             <grp>_DyadInclusionLog_<tag>.csv (except PowerAbove_pct).
      fs   : sampling rate used for the group (median over kept recordings).
      n_keep : samples per recording in the uniform window.
    """
    log_rows = []
    data = {}

    dyads = sorted(times.loc[times.Group == group, "Dyad"].unique())
    for i_dyad, dyad in enumerate(dyads, start=1):
        g_rows = times[(times.Dyad == dyad) & (times.Group == "GTK")]
        m_rows = times[(times.Dyad == dyad) & (times.Group == "MAN")]

        # Dyad-level duration of each conversation: over BOTH partners' files.
        # max()/min() of an all-NaN column give NaN, which fails the test below.
        dur_gtk = g_rows.TrimMaxTime.max() - g_rows.TrimMinTime.min()
        dur_man = m_rows.TrimMaxTime.max() - m_rows.TrimMinTime.min()
        window_ok = (len(g_rows) > 0 and len(m_rows) > 0
                     and np.isfinite(dur_gtk) and np.isfinite(dur_man)
                     and min(dur_gtk, dur_man) > 2 * S.MARGIN_SEC)
        if window_ok:
            W = common_window(dur_gtk, dur_man, S.MARGIN_SEC)
            w_start = W["GtkStart"] if group == "GTK" else W["ManStart"]
            w_end   = W["GtkEnd"]   if group == "GTK" else W["ManEnd"]

        kept = [None, None]
        for s_i, sub in enumerate(S.SUBS):
            row = dict(Dyad=dyad, Group=group, Sub=sub, FileFound=False,
                       CommonWindow_s=np.nan, StableDuration_s=np.nan,
                       Samples=0, FsMeasured_Hz=np.nan, Included=False, Reason="")
            log_rows.append(row)

            if not window_ok:
                row["Reason"] = "no usable GTK/MAN common window (a condition missing or too short)"
                continue
            row["CommonWindow_s"] = W["DurationStable"]

            path = file_name(dyad, group, sub)
            if not os.path.isfile(path):
                row["Reason"] = "file missing"
                continue
            row["FileFound"] = True

            X = read_opt_file(path)

            # calibration trimming, then the stable window measured from the
            # trimmed start of THIS file (same order of operations as MATLAB)
            r = times[(times.Dyad == dyad) & (times.Group == group) & (times.Sub == sub)]
            t_trim_start = r.TrimMinTime.min()
            t_trim_end   = r.TrimMaxTime.max()
            t_start = t_trim_start + w_start
            t_end   = t_trim_start + w_end

            t = X[:, 0]
            keep = (t >= t_trim_start) & (t <= t_trim_end) & (t >= t_start) & (t <= t_end)
            X = X[keep, :]            # NaN times compare False, so they drop out
            if X.shape[0] < 2:
                row["Reason"] = "no samples inside the stable window"
                continue

            X = fill_missing_linear(X)

            stable_dur = np.max(X[:, 0]) - np.min(X[:, 0])
            row["StableDuration_s"] = stable_dur
            row["Samples"] = X.shape[0]

            dt = np.diff(X[:, 0])
            row["FsMeasured_Hz"] = 1.0 / matlab_median(dt[dt > 0])

            if stable_dur < S.MIN_STABLE_SEC:
                # same wording as MATLAB: sprintf("stable duration %.1f s < %d s")
                row["Reason"] = "stable duration %.1f s < %d s" % (stable_dur, S.MIN_STABLE_SEC)
                continue

            row["Included"] = True
            row["Reason"] = "included"
            kept[s_i] = X

        # dyad-level rule: both partners must pass
        got = [k is not None for k in kept]
        if any(got) and not all(got):
            kept = [None, None]
            for row in log_rows[-len(S.SUBS):]:
                if row["Included"]:
                    row["Included"] = False
                    row["Reason"] = "partner excluded (both partners must pass)"
        if all(got):
            data[dyad] = kept
        if i_dyad % 10 == 0 or i_dyad == len(dyads):   # progress, every 10 dyads
            print("  %s: %d / %d dyads loaded" % (group, i_dyad, len(dyads)), flush=True)

    log = pd.DataFrame(log_rows)

    # ---- sampling rate used for the whole group ----
    fs_incl = log.loc[log.Included, "FsMeasured_Hz"].to_numpy()
    if fs_incl.size == 0:
        raise RuntimeError("No recording passed the inclusion rule.")
    fs = matlab_median(fs_incl)
    if fs_incl.max() - fs_incl.min() > 0.01 * fs:
        print("WARNING: measured sampling rate differs between files "
              "(%.3f to %.3f Hz)" % (fs_incl.min(), fs_incl.max()))

    # ---- cut every kept recording to the uniform window ----
    # 9,000 at 50 Hz. + 1e-6, so that a rate measured as 49.99999999999999 Hz
    # (round-off in a time column written with 4 decimals, as in the simulated
    # files) still gives 9,000 and not 8,999. At exactly 50 Hz this changes
    # nothing.
    n_want = int(np.floor(S.UNIFORM_WINDOW_SEC * fs + 1e-6))
    have = [x.shape[0] for pair in data.values() for x in pair]
    n_keep = min([n_want] + have)
    if n_keep < n_want and not getattr(S, "CUT_EACH_TO_OWN_LENGTH", False):
        print("WARNING: the shortest kept recording has %d samples, fewer than %d; "
              "every recording is cut to %d." % (min(have), n_want, n_keep))

    log["Analysed_Samples"] = np.nan
    log["Analysed_Duration_s"] = np.nan
    for dyad, pair in data.items():
        # one length for every dyad (the reported analysis), or, for the
        # 25 Hz all-dyads comparison, this dyad's own length up to 180 s
        # (the shorter partner sets it, so both partners stay aligned)
        n_d = (min(n_want, pair[0].shape[0], pair[1].shape[0])
               if getattr(S, "CUT_EACH_TO_OWN_LENGTH", False) else n_keep)
        for s_i, sub in enumerate(S.SUBS):
            X = pair[s_i]
            if S.UNIFORM_WINDOW_POS == "first":
                i0 = 0
            elif S.UNIFORM_WINDOW_POS == "centre":
                i0 = (X.shape[0] - n_d) // 2
            elif S.UNIFORM_WINDOW_POS == "last":
                i0 = X.shape[0] - n_d
            else:
                raise ValueError("UNIFORM_WINDOW_POS must be 'first', 'centre' or 'last'")
            pair[s_i] = X[i0:i0 + n_d, :]
            m = (log.Dyad == dyad) & (log.Sub == sub)
            log.loc[m, "Analysed_Samples"] = n_d
            log.loc[m, "Analysed_Duration_s"] = pair[s_i][-1, 0] - pair[s_i][0, 0]

    print("%s: Fs = %.3f Hz, %d dyads included, %d samples per recording"
          % (group, fs, len(data), n_keep))
    return data, log, fs, n_keep
