"""
dymo_stats_figures.py - the statistics figures of the MATLAB scripts, for the
graph metrics and the node distances, drawn in Python.

Each function is written from the MATLAB function of the same purpose
(matlab/Functions/...):
    plot_whole_paired_bar      <- STATS/plotWholePairedBar.m (and Cycles/plotCycleMetric.m)
    plot_category_paired_bars  <- STATS/plotCategoryPairedBars.m (and Cycles/plotMetric.m)
    plot_paired_comparison     <- STATS/plotPairedComparison.m (+ addPValueAnnotation.m)
    plot_spearman_comparison   <- STATS/plotSpearmanComparison.m
    plot_delta_rho             <- STATS/plotDeltaRho.m
    plot_legend_figure         <- STATS/plotLegendFigure.m
    plot_category_legend       <- STATS/plotCategoryLegendFigure.m
    save_pub                   <- SavingFigures/SavePublicationFigure.m (sizes, fonts)
Same colours, line weights, font sizes, annotation text and file names. No
legend inside a result figure; the key is its own figure.

KNOWN SMALL DIFFERENCES: the two rho values printed at the points of the
delta-rho figure are 26 pt (MATLAB leaves them at its small default). matplotlib chooses its own automatic axis limits and
tick marks, so the bracket heights and the spacing can differ slightly from
MATLAB. The regression band is the 95 % confidence interval of the fitted
line, computed with the textbook formula that MATLAB's fitlm/predict uses.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")                      # draw to files, no windows
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from scipy import stats

from .dymo_correlations import significance_text
from .dymo_format import num_text, p_text, sig_color

# DYMO_conditionColors.m: Casual Chat (GTK), Conflict (MAN)
COND_COLORS = np.array([[0.24, 0.70, 0.76],
                        [0.95, 0.47, 0.42]])
# the category colour map (C.cmap): Both Inactive, Both Active, Person 1, Person 2
CAT_CMAP = np.array([[0, 0, 0], [0, 1, 0], [0, 0, 1], [1, 0, 0]], dtype=float)
MATLAB_BLUE = np.array([0, 0.4470, 0.7410])
MATLAB_ORANGE = np.array([0.8500, 0.3250, 0.0980])
OLIVE = np.array([0.71, 0.73, 0.02])            # graph-metric correlation figures
PURPLE = np.array([0.5020, 0.0000, 0.5020])     # cycle correlation figures
# DYMO_conditionColorsPurple.m: Casual Chat solid, Conflict light
COND_COLORS_PURPLE = np.array([[0.49, 0.18, 0.56],
                               [0.82, 0.71, 0.85]])

# SavePublicationFigure.m, final values (baseFontSize 30, otherFontBump 4)
TITLE_PT, LABEL_PT, TICK_PT, FRAME_W = 34, 32, 28, 4.5


def _p_text(p):
    """DYMO_pText: 'p = .003', 'p < .001'. One format for every
    figure, the same as the tables."""
    return p_text(p)


# ---------------------------------------------------------------------------
# DYMO_emInData.m + DYMO_starAndP.m: the significance star and the p-value
# above a bracket, placed by the INK of the glyphs, not by the text box.
# Font sizes are in points and the axis in data units, so a fixed data offset
# cannot work for every axis; one em is converted to data units from the axes
# height and the y-range.
# ---------------------------------------------------------------------------
def _em_in_data(ax, font_pt):
    fig = ax.figure
    h_pt = ax.get_position().height * fig.get_size_inches()[1] * 72.0
    y0, y1 = ax.get_ylim()
    return font_pt * (y1 - y0) / h_pt


def _star_and_p(ax, x_mid, y_bar, p, star_base=30, p_size=28):
    """Star (or n.s.) and p-value above a bracket at y_bar; returns the top of
    the p-value's ink in data units. Grey when not significant; a significant
    star is 60 % larger (DYMO_sigColor)."""
    GAP_BRACKET, GAP_STARP = 0.30, 0.04          # ems of the star / of the p text
    CAP, STARTOP, XHEIGHT, DESCEND, STARBOT = 0.72, 0.68, 0.52, 0.21, 0.20
    col, is_sig = sig_color(p)
    star_size = star_base * (1 + 0.6 * is_sig)
    em_star, em_p = _em_in_data(ax, star_size), _em_in_data(ax, p_size)
    ink_bot, ink_top = (STARBOT * em_star, STARTOP * em_star) if is_sig else (0.0, XHEIGHT * em_star)
    star_base_y = y_bar + GAP_BRACKET * em_star - ink_bot
    ax.text(x_mid, star_base_y, significance_text(p), ha="center", va="baseline",
            fontsize=star_size, fontweight="bold", color=col)
    # MATLAB halves this gap (PGAP = 0.5); in matplotlib that puts the tail of
    # the 'p' into the star, so the full ink gap is used (a deliberate difference)
    p_base_y = star_base_y + ink_top + (GAP_STARP + DESCEND) * em_p
    ax.text(x_mid, p_base_y, _p_text(p), ha="center", va="baseline",
            fontsize=p_size, fontweight="bold", color=col)
    return p_base_y + CAP * em_p


# ---------------------------------------------------------------------------
# saving (SavePublicationFigure.m)
# ---------------------------------------------------------------------------
def save_pub(fig, folder, name, size=(25, 16), layout=True, grid=False, close=True):
    """Save as PNG (300 dpi) and vector PDF. size in inches: [25 16] by
    default, [13 16] for single panels, [13 10] for the legend figures.
    layout=False for the legend figures, which are placed by hand
    (UserData.SkipLayout in MATLAB).
    grid=False (the default) removes the grid from every figure, as
    SavePublicationFigure.m does; grid=True keeps the plotting function's grid.
    close=False keeps the figure open, so the state-pair icons can be added and
    the figure saved a second time (addStatePairIcons.m)."""
    os.makedirs(folder, exist_ok=True)
    fig.set_size_inches(*size)
    if not grid:
        for ax in fig.axes:
            ax.grid(False)
    if layout:
        for ax in fig.axes:
            ax.title.set_fontsize(TITLE_PT)
            ax.title.set_fontweight("bold")
            ax.xaxis.label.set_fontsize(LABEL_PT)
            ax.yaxis.label.set_fontsize(LABEL_PT)
            ax.tick_params(labelsize=TICK_PT, width=2)
            for s in ax.spines.values():
                s.set_linewidth(FRAME_W)
        # space the panels so no label runs into its neighbour (fitFigureLayout.m)
        # a figure-level title (sgtitle) needs its own band at the top
        top = 0.93 if fig._suptitle is not None else 1.0
        fig.tight_layout(w_pad=3.0, rect=(0, 0, 1, top))
    fig.savefig(os.path.join(folder, name + ".png"), dpi=300, bbox_inches="tight")
    fig.savefig(os.path.join(folder, name + ".pdf"), bbox_inches="tight")
    if close:
        plt.close(fig)
    SAVED.append(os.path.join(folder, name))


# every figure saved in this run (folder/name, no extension), so a script can
# check its OWN figures and is not confused by files an older version left
SAVED = []


def check_saved(expected, folders):
    """(n_png, n_pdf, stale): figures of this run found on disk, and files in
    `folders` that this run did not write (left by an older version)."""
    n_png = sum(os.path.isfile(f + ".png") for f in SAVED)
    n_pdf = sum(os.path.isfile(f + ".pdf") for f in SAVED)
    mine = {os.path.normcase(os.path.abspath(f)) for f in SAVED}
    stale = [os.path.join(r, fn) for d in folders for r, _, fs in os.walk(d) for fn in fs
             if fn.endswith((".png", ".pdf"))
             and os.path.normcase(os.path.abspath(os.path.join(r, fn[:-4]))) not in mine]
    return n_png, n_pdf, stale


def _sem(x):
    """MATLAB std(x)/sqrt(n): std of one value is 0."""
    return (np.std(x, ddof=1) if x.size > 1 else 0.0) / np.sqrt(x.size) if x.size else np.nan


def _paired_ttest_p(a, b):
    return stats.ttest_rel(a, b).pvalue if a.size > 1 else np.nan


# ---------------------------------------------------------------------------
# plotWholePairedBar.m
# ---------------------------------------------------------------------------
def plot_whole_paired_bar(xC, xS, p, title_text, y_label="", colors=None):
    """Two bars (Casual Chat, Conflict) with SEM, red mean lines and a bracket.
    colors: the two condition colours (default COND_COLORS; the purple
    figures pass COND_COLORS_PURPLE, as plotWholePairedBar.m's optional
    condColors input)."""
    colors = COND_COLORS if colors is None else np.asarray(colors, float)
    xC, xS = np.asarray(xC, float), np.asarray(xS, float)
    v = np.isfinite(xC) & np.isfinite(xS)
    xC, xS = xC[v], xS[v]
    m = [xC.mean(), xS.mean()]
    se = [_sem(xC), _sem(xS)]

    fig, ax = plt.subplots(figsize=(13, 16))      # the saved size, so the ems are right
    x = [0.975, 1.025]
    bw = 0.03
    for i in range(2):
        ax.bar(x[i], m[i], bw, color=colors[i], edgecolor="k", linewidth=4.5)
    ax.set_xlim(0.8, 1.2)
    yl = ax.get_ylim()
    ax.set_ylim(yl[0], yl[1] * 1.15)
    for i in range(2):                               # mean line exactly as wide as the bar
        ax.plot([x[i] - bw / 2, x[i] + bw / 2], [m[i], m[i]], "r-", linewidth=4.5)
        ax.errorbar(x[i], m[i], se[i], color="k", linestyle="none", linewidth=5.0, capsize=10, capthick=5.0)

    yl = ax.get_ylim()
    off = 0.07 * (yl[1] - yl[0])
    top = max(m[0] + se[0], m[1] + se[1])
    ybar = top + off
    if ybar + 3.2 * off > yl[1]:
        ax.set_ylim(yl[0], ybar + 3.5 * off)
        yl = ax.get_ylim()
        off = 0.07 * (yl[1] - yl[0])
        ybar = top + off
    tick = 0.25 * off
    ax.plot([x[0], x[0], x[1], x[1]], [ybar - tick, ybar, ybar, ybar - tick], "k", linewidth=4.5)
    ann_top = _star_and_p(ax, np.mean(x), ybar, p, 32, 30)
    yl = ax.get_ylim()
    if ann_top + 0.3 * off > yl[1]:
        ax.set_ylim(yl[0], ann_top + 0.3 * off)
    ax.set_xticks([])
    if y_label:
        ax.set_ylabel(y_label)
    ax.set_title(title_text)
    ax.grid(True)
    return fig


# ---------------------------------------------------------------------------
# plotCategoryPairedBars.m
# ---------------------------------------------------------------------------
def plot_category_paired_bars(XC, XS, cat_names, title_text, x_label="", y_label=""):
    """Grouped bars per category: GTK in the category colour, MAN in a lighter
    tint, SEM, mean lines, paired t-test brackets, Symmetric/Asymmetric headings."""
    nC = len(cat_names)
    mG, sG, mM, sM, pv = (np.full(nC, np.nan) for _ in range(5))
    for c in range(nC):
        a, b = XC[:, c], XS[:, c]
        v = np.isfinite(a) & np.isfinite(b)
        a, b = a[v], b[v]
        if a.size:
            mG[c], sG[c], mM[c], sM[c] = a.mean(), _sem(a), b.mean(), _sem(b)
        pv[c] = _paired_ttest_p(a, b)

    fig, ax = plt.subplots(figsize=(25, 16))
    # MATLAB bar(Y,'grouped') with 2 series: bars 0.2286 wide at +-0.1429
    off_x, bw = 0.1429, 0.2286
    xg = np.arange(1, nC + 1) - off_x
    xm = np.arange(1, nC + 1) + off_x
    gcol = CAT_CMAP[:nC]
    mcol = np.minimum(gcol + 0.7, 1)
    ax.bar(xg, np.nan_to_num(mG), bw, color=gcol, edgecolor="k", linewidth=4.5)
    ax.bar(xm, np.nan_to_num(mM), bw, color=mcol, edgecolor="k", linewidth=4.5)
    ax.errorbar(xg, mG, sG, color="k", linestyle="none", linewidth=5.0, capsize=6, capthick=5.0)
    ax.errorbar(xm, mM, sM, color="k", linestyle="none", linewidth=5.0, capsize=6, capthick=5.0)
    for xs, ms in ((xg, mG), (xm, mM)):
        for c in range(nC):
            ax.plot([xs[c] - 0.125, xs[c] + 0.125], [ms[c], ms[c]], "r-", linewidth=4.5)

    yl = ax.get_ylim()
    ax.set_ylim(yl[0], yl[1] * 1.20)
    off = 0.05 * (yl[1] - yl[0])
    tick = 0.25 * off
    ann_top = -np.inf
    for c in range(nC):
        top = max(mG[c] + sG[c], mM[c] + sM[c])
        if not np.isfinite(top):
            continue
        ybar = top + off
        yl = ax.get_ylim()
        if ybar + 3 * off > yl[1]:
            ax.set_ylim(yl[0], ybar + 5.0 * off)
            yl = ax.get_ylim()
            off = 0.05 * (yl[1] - yl[0])
            tick = 0.25 * off
            ybar = top + off
        x1, x2 = xg[c], xm[c]
        ax.plot([x1, x1, x2, x2], [ybar - tick, ybar, ybar, ybar - tick], "k", linewidth=4.5)
        ann_top = max(ann_top, _star_and_p(ax, (x1 + x2) / 2, ybar, pv[c], 30, 28))

    yl = ax.get_ylim()
    if np.isfinite(ann_top) and ann_top + 1.5 * off > yl[1]:
        ax.set_ylim(yl[0], ann_top + 1.5 * off)
    if nC == 4:                                      # group headings
        yl = ax.get_ylim()
        yG = max(ann_top + 0.6 * off, yl[1] - 0.06 * (yl[1] - yl[0]))
        if yG + 0.08 * (yl[1] - yl[0]) > yl[1]:
            ax.set_ylim(yl[0], yG + 0.10 * (yl[1] - yl[0]))
        for (x0, x1), name in (((0.7, 2.3), "Symmetric Interaction"),
                               ((2.7, 4.3), "Asymmetric Interaction")):
            ax.plot([x0, x1], [yG, yG], "k", linewidth=4.5)
            ax.text((x0 + x1) / 2, yG, name, ha="center", va="bottom", fontsize=30, fontweight="bold")
    ax.set_xlim(0.5 - 0.20, nC + 0.5 + 0.20)
    ax.set_xticks(np.arange(1, nC + 1))
    ax.set_xticklabels(cat_names)
    if x_label:
        ax.set_xlabel(x_label, fontweight="bold")
    if y_label:
        ax.set_ylabel(y_label)
    ax.set_title(title_text)
    ax.grid(True)
    return fig


# ---------------------------------------------------------------------------
# plotPairedComparison.m + addPValueAnnotation.m (node distances, one panel)
# ---------------------------------------------------------------------------
def plot_paired_comparison(ax, gtk, man, p, title_text, y_label, colors=None):
    """colors: GTKColor and MANColor of plotPairedComparison.m (default COND_COLORS)."""
    colors = COND_COLORS if colors is None else np.asarray(colors, float)
    gtk, man = np.asarray(gtk, float), np.asarray(man, float)
    v = np.isfinite(gtk) & np.isfinite(man)
    gtk, man = gtk[v], man[v]
    m = np.array([gtk.mean(), man.mean()])
    se = np.array([_sem(gtk), _sem(man)])
    top = np.max(m + se)
    if not np.isfinite(top) or top <= 0:
        top = 1
    ylim = (0, 1.15 * top)                           # yLimits = [] -> automatic

    x = [1.0, 1.45]
    for i in range(2):
        ax.bar(x[i], m[i], 0.30, color=colors[i], edgecolor="k", linewidth=4.5)
    ax.errorbar(x, m, se, color="k", linestyle="none", linewidth=5.0, capsize=10, capthick=5.0)
    for i in range(2):
        ax.plot([x[i] - 0.15, x[i] + 0.15], [m[i], m[i]], "r-", linewidth=4.5)
    ax.set_xticks([])
    ax.set_ylabel(y_label)
    ax.set_title(title_text)
    ax.set_ylim(*ylim)
    ax.grid(True)

    # addPValueAnnotation (called after ylim, as in the fixed MATLAB)
    off = 0.05 * (ylim[1] - ylim[0])
    ybar = np.max(m + se) + off
    ax.set_ylim(ylim[0], max(ylim[1], ybar + 2.2 * off))
    tick = 0.25 * off
    ax.plot([x[0], x[0], x[1], x[1]], [ybar - tick, ybar, ybar, ybar - tick], "k", linewidth=4.5)
    ann_top = _star_and_p(ax, np.mean(x), ybar, p, 32, 30)
    yl = ax.get_ylim()
    if ann_top + 0.3 * off > yl[1]:
        ax.set_ylim(yl[0], ann_top + 0.3 * off)


# ---------------------------------------------------------------------------
# the regression line and its 95 % band (fitlm + predict in MATLAB)
# ---------------------------------------------------------------------------
def _fit_with_band(x, y):
    n = x.size
    b1, b0 = np.polyfit(x, y, 1)
    xx = np.linspace(x.min(), x.max(), 100)
    yy = b0 + b1 * xx
    resid = y - (b0 + b1 * x)
    s = np.sqrt(np.sum(resid ** 2) / (n - 2))
    sxx = np.sum((x - x.mean()) ** 2)
    half = stats.t.ppf(0.975, n - 2) * s * np.sqrt(1 / n + (xx - x.mean()) ** 2 / sxx)
    return xx, yy, yy - half, yy + half


# ---------------------------------------------------------------------------
# plotSpearmanComparison.m (node distances, one panel)
# ---------------------------------------------------------------------------
def plot_spearman_comparison(ax, x, y, rho, p, title_text, x_label, y_label,
                             point_color=MATLAB_BLUE):
    x, y = np.asarray(x, float), np.asarray(y, float)
    v = np.isfinite(x) & np.isfinite(y)
    x, y = x[v], y[v]
    ax.scatter(x, y, s=45, color=point_color, alpha=0.7)
    if x.size >= 3 and np.std(x) > 0 and np.std(y) > 0:
        xx, yy, lo, hi = _fit_with_band(x, y)
        # one colour per series: band and line take the point colour
        ax.fill_between(xx, lo, hi, color=point_color, alpha=0.20, linewidth=0)
        ax.plot(xx, yy, "-", color=point_color, linewidth=2.5)
    else:
        ax.text(0.05, 0.05, "no variation: no line fitted", transform=ax.transAxes,
                fontsize=26, fontweight="bold", color=(0.4, 0.4, 0.4))
    ax.text(0.05, 0.95, "Spearman ρ = %s\n%s" % (num_text(rho), _p_text(p)), transform=ax.transAxes,
            ha="left", va="top", fontsize=30, fontweight="bold", color=sig_color(p)[0])
    ax.set_xlabel(x_label)
    ax.set_ylabel(y_label)
    ax.set_title(title_text)
    ax.grid(True)


# ---------------------------------------------------------------------------
# SpearCorr_WholeGraph_17July26.m / SpearCorr_CycWholeGraph_17July26.m, the scatter
# ---------------------------------------------------------------------------
def plot_whole_scatter(xC, xS, rho, p, title_text, color=None):
    xC, xS = np.asarray(xC, float), np.asarray(xS, float)
    v = np.isfinite(xC) & np.isfinite(xS)
    xC, xS = xC[v], xS[v]
    col = OLIVE if color is None else color
    fig, ax = plt.subplots()
    ax.scatter(xC, xS, s=50, color=col, edgecolors=col, linewidths=2.5)
    if np.std(xC) > 0 and np.std(xS) > 0:
        xx, yy, lo, hi = _fit_with_band(xC, xS)
        ax.fill_between(xx, lo, hi, color=col, alpha=0.20, linewidth=0)
        ax.plot(xx, yy, color=col, linewidth=2)
    else:
        ax.text(0.05, 0.05, "no variation: no line fitted", transform=ax.transAxes,
                fontsize=26, fontweight="bold", color=(0.4, 0.4, 0.4))
    ax.text(0.05, 0.95, "rho = %s\n%s" % (num_text(rho), _p_text(p)), transform=ax.transAxes,
            va="top", fontsize=30, fontweight="bold", color=sig_color(p)[0])
    ax.set_xlabel("Casual Chat", fontweight="bold")
    ax.set_ylabel("Conflict", fontweight="bold")
    ax.set_title(title_text)
    ax.grid(True)
    return fig


# ---------------------------------------------------------------------------
# SpearCorr_SubgraphStats_AsySymBoot_07July26.m, four-panel scatter (one metric)
# ---------------------------------------------------------------------------
def plot_category_scatter(X, Y, rhos, ps, cat_names, suptitle):
    fig, axes = plt.subplots(1, len(cat_names))
    for c, ax in enumerate(axes):
        x, y = X[:, c], Y[:, c]
        v = np.isfinite(x) & np.isfinite(y)
        x, y = x[v], y[v]
        if x.size >= 3 and np.std(x) > 0 and np.std(y) > 0:
            ax.scatter(x, y, s=50, color=CAT_CMAP[c], edgecolors="k")
            xx, yy, lo, hi = _fit_with_band(x, y)
            ax.fill_between(xx, lo, hi, color=CAT_CMAP[c], alpha=0.20, linewidth=0)
            ax.plot(xx, yy, color=CAT_CMAP[c], linewidth=2.5)
        ax.text(0.05, 0.95, "ρ = %s\n%s" % (num_text(rhos[c]), _p_text(ps[c])),
                transform=ax.transAxes, va="top", fontsize=30, fontweight="bold", color=sig_color(ps[c])[0])
        ax.set_xlabel("Casual Chat", fontweight="bold")
        ax.set_ylabel("Conflict", fontweight="bold")
        ax.set_title(cat_names[c])
        ax.grid(True)
    fig.suptitle(suptitle, fontsize=34, fontweight="bold")
    return fig


# ---------------------------------------------------------------------------
# plotDeltaRho.m
# ---------------------------------------------------------------------------
def plot_delta_rho(R, metric_label):
    fig, ax = plt.subplots()
    ax.plot([1, 2], [R["rhoG1"], R["rhoG2"]], "k-", linewidth=2)
    ax.scatter([1], [R["rhoG1"]], s=150, color=MATLAB_BLUE, zorder=3)
    ax.scatter([2], [R["rhoG2"]], s=150, color=MATLAB_ORANGE, zorder=3)
    for xi, r in ((1, R["rhoG1"]), (2, R["rhoG2"])):
        # MATLAB leaves these at the default size, which is unreadable on a
        # 13 x 16 inch figure; 26 pt here (a deliberate difference)
        ax.text(xi, r, num_text(r), ha="center", va="bottom", fontsize=26, fontweight="bold")
    # plotDeltaRho.m: delta-rho and its dyad-level BCa
    # interval, black if the interval excludes 0 and grey if not. The CI is
    # the inference.
    ax.text(0.03, 0.97, "Δρ = %s\n95%% CI = [%s, %s]"
            % (num_text(R["delta"]), num_text(R["CI"][0]), num_text(R["CI"][1])),
            transform=ax.transAxes, va="top", fontsize=30, fontweight="bold", color=sig_color(R["CI"])[0])
    ax.set_xticks([1, 2])
    ax.set_xticklabels(["Symmetric Interaction", "Asymmetric Interaction"])
    ax.set_ylabel("Spearman ρ")
    ax.set_ylim(-1, 1)
    ax.set_xlim(0.5, 2.5)
    ax.set_title(metric_label)
    ax.grid(True)
    return fig


# ---------------------------------------------------------------------------
# plotLegendFigure.m and plotCategoryLegendFigure.m (the keys)
# ---------------------------------------------------------------------------
def plot_legend_figure(names, colors, title_text=""):
    """One swatch per name; the title sits in a band above, inside the figure."""
    fig = plt.figure(facecolor="w")
    ax = fig.add_axes([0.02, 0.02, 0.96, 0.80] if title_text else [0.02, 0.02, 0.96, 0.96])
    ax.set_axis_off()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    n = len(names)
    top, bottom = 0.92, 0.08
    rowH = (top - bottom) / n
    for i, name in enumerate(names):
        yC = top - (i + 0.5) * rowH
        h = 0.55 * rowH
        ax.add_patch(Rectangle((0.08, yC - h / 2), 0.16, h, facecolor=colors[i],
                               edgecolor="k", linewidth=4.5))
        ax.text(0.28, yC, name, va="center", ha="left", fontsize=34, fontweight="bold")
    if title_text:
        fig.text(0.5, 0.905, title_text, ha="center", va="center", fontsize=34, fontweight="bold")
    return fig


def plot_category_legend(cat_names, series_names=None):
    """Categories down the side; with series_names, a grid with Casual Chat
    (category colour) and Conflict (lighter tint) across the top."""
    if not series_names:
        return plot_legend_figure(cat_names, CAT_CMAP[:len(cat_names)], "Behavioural categories")
    fig = plt.figure(facecolor="w")
    ax = fig.add_axes([0.02, 0.02, 0.96, 0.96])
    ax.set_axis_off()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    n = len(cat_names)
    top, bottom, sw = 0.84, 0.08, 0.17
    rowH = (top - bottom) / n
    colX = [0.50, 0.75]
    for k, s in enumerate(series_names[:2]):
        ax.text(colX[k] + sw / 2, 0.93, s, ha="center", va="center", fontsize=32, fontweight="bold")
    for c, name in enumerate(cat_names):
        yC = top - (c + 0.5) * rowH
        h = 0.55 * rowH
        ax.text(0.03, yC, name, va="center", ha="left", fontsize=30, fontweight="bold")
        for k, col in enumerate((CAT_CMAP[c], np.minimum(CAT_CMAP[c] + 0.7, 1))):
            ax.add_patch(Rectangle((colX[k], yC - h / 2), sw, h, facecolor=col,
                                   edgecolor="k", linewidth=4.5))
    return fig


# ---------------------------------------------------------------------------
# plotCorrLegendFigure.m: the key to the scatter figures draws
# the panels' OWN marks - translucent dot, CI band, fitted line - not swatches.
#   'whole'    : three rows (Dyads / 95% CI / Linear fit), one colour
#   'category' : one row per category (band + line + dot), and a note below
# ---------------------------------------------------------------------------
def plot_corr_legend(point_names, point_colors, title_text="", style="whole"):
    point_colors = np.atleast_2d(np.asarray(point_colors, dtype=float))
    is_cat = style == "category"
    n_rows = len(point_names) if is_cat else 3
    fig = plt.figure(facecolor="w")
    note = 0.14 if is_cat else 0.0
    ax_top = 0.80 if title_text else 0.96
    ax = fig.add_axes([0.02, 0.02 + note, 0.96, ax_top - note])
    ax.set_axis_off()
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    top, bottom = 0.92, 0.08
    row_h = (top - bottom) / n_rows
    mark_x, mark_w = 0.08, 0.16
    label_x, mark_mid = mark_x + mark_w + 0.04, mark_x + mark_w / 2
    pt_alpha, pt_edge = (1.0, "k") if is_cat else (0.7, "none")

    def row_y(r):
        return top - (r - 0.5) * row_h

    def band(yc, h, col):
        ax.add_patch(Rectangle((mark_x, yc - h / 2), mark_w, h, facecolor=col, alpha=0.20, edgecolor="none"))

    def label(y, txt):
        ax.text(label_x, y, txt, va="center", ha="left", fontsize=34, fontweight="bold")

    if is_cat:
        for i, name in enumerate(point_names):
            yc, col = row_y(i + 1), point_colors[i]
            band(yc, 0.45 * row_h, col)
            ax.plot([mark_x, mark_x + mark_w], [yc, yc], color=col, linewidth=2.5)
            ax.scatter([mark_mid], [yc], s=900, color=col, alpha=pt_alpha, edgecolors=pt_edge)
            label(yc, name)
        fig.text(0.5, 0.08, "each colour is one behavioural category\n"
                 "point = dyad    band = 95% CI    line = linear fit",
                 ha="center", va="center", fontsize=26, fontweight="bold")
    else:
        col = point_colors[0]
        yc = row_y(1)
        ax.scatter([mark_mid], [yc], s=900, color=col, alpha=pt_alpha, edgecolors=pt_edge)
        label(yc, point_names[0])
        yc = row_y(2)
        band(yc, 0.55 * row_h, col)
        label(yc, "95% CI")
        yc = row_y(3)
        ax.plot([mark_x, mark_x + mark_w], [yc, yc], color=col, linewidth=2.5)
        label(yc, "Linear fit")
    if title_text:
        fig.text(0.5, 0.905, title_text, ha="center", va="center", fontsize=34, fontweight="bold")
    return fig
