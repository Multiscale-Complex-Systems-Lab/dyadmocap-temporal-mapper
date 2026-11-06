"""
dymo_later_figures.py - the correlation-bar, icon and node-size figures, drawn
in the style of dymo_stats_figures.py (same fonts, line weights and saving).

Each function is written from the MATLAB function of the same purpose
(matlab/Functions/...):
    corr_whole_bar        <- STATS/plotCorrWholeBar.m
    corr_pair_bars        <- STATS/plotCorrPairBars.m
    corr_star_key         <- STATS/plotCorrStarKey.m
    add_state_pair_icons  <- SavingFigures/addStatePairIcons.m
    state_icon            <- MainScripts/NodeDistance/Pairedttest/NodeDistanceIcons_29Oct26.m
    node_size_bands       <- the first figure of NodeSizeDistribution_Purple_29Oct26.m
    node_size_histogram   <- the second figure of the same script
Colours: DYMO_conditionColorsPurple.m (COND_COLORS_PURPLE) and the category
colour map (CAT_CMAP). No grid on these figures (as SavePublicationFigure.m).
The keys are their own figures.

KNOWN SMALL DIFFERENCES: matplotlib chooses its own tick marks, and the
position of a star drawn 'bottom-aligned' depends on the font's box, so a
star can sit a little higher or lower than in MATLAB. The star key has the
same text as the MATLAB version.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from .dymo_stats_figures import COND_COLORS_PURPLE, CAT_CMAP, SAVED

GREY = (0.6, 0.6, 0.6)
EDGE_GREY = (0.5, 0.5, 0.5)
CORR_YLABEL = "Interaction style consistency\nacross contexts (Spearman ρ)"


def _stars(p):
    return "***" if p < 0.001 else "**" if p < 0.01 else "*"


def _ticks_up_to_one(ax):
    """Keep the y ticks at or below 1 (rho cannot exceed 1)."""
    lo, hi = ax.get_ylim()
    t = [v for v in ax.get_yticks() if lo - 1e-9 <= v <= min(hi, 1) + 1e-9]
    ax.set_yticks(t)
    ax.set_ylim(lo, hi)


# ---------------------------------------------------------------------------
# plotCorrWholeBar.m
# ---------------------------------------------------------------------------
def corr_whole_bar(rho, ci_lo, ci_hi, p, title_text, y_limits):
    """One purple bar: Spearman rho of the whole graph (GTK vs MAN) with its
    95 % CI; star if p < .05, grey n.s. otherwise. Saved 8 x 16 in."""
    fig, ax = plt.subplots(figsize=(8, 16))
    ax.bar(1, rho, 0.35, color=COND_COLORS_PURPLE[0], edgecolor="k", linewidth=4.5)
    ax.errorbar(1, rho, [[rho - ci_lo], [ci_hi - rho]], color="k", linestyle="none",
                linewidth=5.0, capsize=12, capthick=5.0)
    ax.plot([0, 2], [0, 0], "k-", linewidth=2.5)
    top = np.nanmax([ci_hi, rho, 0])
    if np.isfinite(p) and np.isfinite(rho):
        if p < 0.05:
            ax.text(1, top - 0.03, _stars(p), ha="center", va="bottom", fontsize=48, fontweight="bold")
        else:
            ax.text(1, top + 0.015, "n.s.", ha="center", va="bottom", fontsize=30,
                    fontweight="bold", color=GREY)
    ax.set_xlim(0.5, 1.5)
    ax.set_ylim(*y_limits)
    ax.set_xticks([1], ["Whole graph"])
    ax.set_ylabel(CORR_YLABEL, fontweight="bold")
    _ticks_up_to_one(ax)
    ax.set_title(title_text, fontweight="bold")
    return fig


# ---------------------------------------------------------------------------
# plotCorrPairBars.m
# ---------------------------------------------------------------------------
def corr_pair_bars(rho, ci_lo, ci_hi, cat_names, cmap, title_text, pairs, p_rho):
    """Per category: Spearman rho (GTK vs MAN) with its 95 % CI; a star on a
    bar if rho differs from 0 (grey n.s. otherwise); a bracket with stars over
    two categories whose rho differ (spearman_pair_delta; pairs that do not
    differ are not drawn). Saved 18 x 16 in."""
    rho, ci_lo, ci_hi, p_rho = (np.asarray(v, float).ravel() for v in (rho, ci_lo, ci_hi, p_rho))
    n = rho.size
    x = np.arange(1, n + 1)
    fig, ax = plt.subplots(figsize=(18, 16))
    ax.bar(x, rho, 0.45, color=np.asarray(cmap)[:n], edgecolor="k", linewidth=4.5)
    ax.errorbar(x, rho, [rho - ci_lo, ci_hi - rho], color="k", linestyle="none",
                linewidth=5.0, capsize=12, capthick=5.0)
    ax.plot([0, n + 1], [0, 0], "k-", linewidth=2.5)
    finite_lo = ci_lo[np.isfinite(ci_lo)]
    y_bottom = min(-0.25, finite_lo.min() - 0.10) if finite_lo.size else -0.25
    ax.set_xlim(0.5 - 0.20, n + 0.5 + 0.20)

    GAP, TICK, STAR = 0.06, 0.04, 0.11
    top = np.nanmax(np.vstack([ci_hi, rho, np.zeros(n)]), axis=0)
    top[~np.isfinite(top)] = 0
    for k in range(n):
        if not np.isfinite(p_rho[k]):
            continue
        if p_rho[k] >= 0.05:
            ax.text(x[k], top[k] + 0.015, "n.s.", ha="center", va="bottom", fontsize=30,
                    fontweight="bold", color=GREY)
            top[k] += 0.10
            continue
        ax.text(x[k], top[k] - 0.03, _stars(p_rho[k]), ha="center", va="bottom",
                fontsize=48, fontweight="bold")
        top[k] += STAR

    drawn = [q for q in pairs if q["stars"]]
    drawn.sort(key=lambda q: (abs(q["j"] - q["i"]), min(q["i"], q["j"])))   # short brackets first
    for q in drawn:
        a, c = min(q["i"], q["j"]), max(q["i"], q["j"])                     # 0-based
        y_br = top[a:c + 1].max() + GAP
        ax.plot([x[a], x[a], x[c], x[c]], [y_br - TICK, y_br, y_br, y_br - TICK], "k", linewidth=4.5)
        ax.text((x[a] + x[c]) / 2, y_br - 0.03, q["stars"], ha="center", va="bottom",
                fontsize=48, fontweight="bold")
        top[a:c + 1] = y_br + STAR

    ax.set_ylim(y_bottom, max(1.0, top.max() + 0.03))
    ax.set_xticks(x, cat_names)
    ax.set_xlabel("Behavioural Categories", fontweight="bold")
    ax.set_ylabel(CORR_YLABEL, fontweight="bold")
    _ticks_up_to_one(ax)
    ax.set_title(title_text, fontweight="bold")
    return fig


# ---------------------------------------------------------------------------
# plotCorrStarKey.m
# ---------------------------------------------------------------------------
def corr_star_key(n_dyads=None):
    """How to read the consistency bars. Saved 13 x 10 in, layout=False."""
    lines = ["Key", "",
             "Bar: Spearman ρ between Casual Chat and Conflict, over dyads",
             "Error bar: 95% CI (BCa bootstrap, 10,000 dyad resamples)", "",
             "* on a bar: ρ differs from 0",
             "No star on a bar: ρ does not differ from 0 (not significant)",
             "* on a bracket: the two states differ in consistency", "",
             "*  p < .05      **  p < .01      ***  p < .001",
             "Pairs that do not differ are not shown (6 pairs, uncorrected)"]
    fig = plt.figure(figsize=(13, 10), facecolor="w")
    ax = fig.add_axes([0, 0, 1, 1])
    ax.set_axis_off()
    ax.text(0.05, 0.5, "\n".join(lines), transform=ax.transAxes, fontsize=26,
            fontweight="bold", va="center", ha="left")
    return fig


# ---------------------------------------------------------------------------
# addStatePairIcons.m
# ---------------------------------------------------------------------------
def _text_width(fig, ax, s):
    """Width of `s` in the title's font, as a share of the figure width."""
    t = fig.text(0, 0, s, fontsize=ax.title.get_fontsize(), fontweight=ax.title.get_fontweight(),
                 fontfamily=ax.title.get_fontfamily())
    w = t.get_window_extent(fig.canvas.get_renderer()).width / fig.bbox.width
    t.remove()
    return w


def add_state_pair_icons(fig, pairs, folder, name):
    """Above each panel's title, a small graph of the panel's two states: the
    'from' node, a grey edge with a '>' in the middle, the 'to' node. pairs:
    one (from, to) per panel, states numbered 1-4 (Both Inactive, Both Active,
    Person 1 Active, Person 2 Active), panels in reading order. The figure
    must already have its final size and layout (save it first with
    save_pub(..., close=False)). Saves <name>.png/.pdf and closes the figure."""
    H = 0.09                                   # share of the figure height freed per panel row
    axes = [a for a in fig.axes if a.get_label() != "StatePairIcon"]
    axes.sort(key=lambda a: (-round(a.get_position().y0, 2), a.get_position().x0))
    if len(axes) != len(pairs):
        raise ValueError("add_state_pair_icons: %d panels but %d pairs." % (len(axes), len(pairs)))
    # Room for the icons. MATLAB shortens every panel by H; here the FIGURE is
    # made taller by H per row of panels instead, so the panels keep their
    # size and the star and p-value (placed in ems of the panel) do not move
    # into each other. (A deliberate difference: the _Icons figure is a
    # little taller than the plain one.)
    w_in, h_old = fig.get_size_inches()
    extra = H * h_old                          # inches added above each row
    rows = sorted({round(a.get_position().y0, 2) for a in axes})   # bottom row first
    pos = {a: a.get_position() for a in axes}
    h_in = h_old + len(rows) * extra
    fig.set_size_inches(w_in, h_in)
    for a in axes:
        p = pos[a]
        r = rows.index(round(p.y0, 2))         # rows below this panel's row
        a.set_position([p.x0, (p.y0 * h_old + r * extra) / h_in, p.width, p.height * h_old / h_in])
    H = extra / h_in                            # the same room, as a share of the new height
    fig.canvas.draw()
    inv = fig.transFigure.inverted()
    for a, (s1, s2) in zip(axes, pairs):
        bb = a.title.get_window_extent(fig.canvas.get_renderer()).transformed(inv)
        parts = [s.strip() for s in a.get_title().replace("\n", " ").split("→")]
        if len(parts) < 2:
            words = a.get_title().split()
            parts = [words[0], words[-1]]
        w_first, w_last = _text_width(fig, a, parts[0]), _text_width(fig, a, parts[-1])
        x_first = bb.x0 + w_first / 2            # middle of the first state's name
        x_last = bb.x1 - w_last / 2              # middle of the last state's name
        h = 0.70 * H
        width = x_last - x_first
        iax = fig.add_axes([x_first, bb.y1 + 0.02 * H, width, h], label="StatePairIcon")
        wi, hi = width * w_in, h * h_in        # icon size in inches
        iax.plot([0, 1], [0, 0], color=EDGE_GREY, linewidth=5, clip_on=False)
        aw, al = 0.22 / (hi / 2), 0.30 / wi    # the '>' : 0.22 in half-height, 0.30 in long
        iax.plot([0.5 + al / 2 - al, 0.5 + al / 2, 0.5 + al / 2 - al], [aw, 0, -aw],
                 color=EDGE_GREY, linewidth=5, solid_joinstyle="miter", clip_on=False)
        d = 0.5 * hi * 72                        # node diameter in points
        for xx, s in ((0, s1), (1, s2)):
            iax.scatter([xx], [0], s=d ** 2, color=CAT_CMAP[s - 1], edgecolors="k",
                        linewidths=1, zorder=3, clip_on=False)
        iax.set_xlim(0, 1)
        iax.set_ylim(-1, 1)
        iax.set_axis_off()
    os.makedirs(folder, exist_ok=True)
    fig.savefig(os.path.join(folder, name + ".png"), dpi=300, bbox_inches="tight", facecolor="w")
    fig.savefig(os.path.join(folder, name + ".pdf"), bbox_inches="tight", facecolor="w")
    plt.close(fig)
    SAVED.append(os.path.join(folder, name))


# ---------------------------------------------------------------------------
# NodeDistanceIcons_29Oct26.m: the 16 state-pair icons on their own
# ---------------------------------------------------------------------------
ICON_FILE_NAMES = ["BothInactive", "BothActive", "Person1Active", "Person2Active"]


def state_icon(s1, s2):
    """One icon, 4 x 4 in: node s1 -> node s2 (states 1-4)."""
    fig, ax = plt.subplots(figsize=(4, 4))
    ax.plot([0, 2], [0, 0], color=EDGE_GREY, linewidth=4)
    xm, al, aw = 1.0, 0.16, 0.10
    ax.plot([xm - al / 2, xm, xm - al / 2], [aw, 0, -aw], color=EDGE_GREY, linewidth=4)
    for xx, s in ((0, s1), (2, s2)):
        ax.scatter([xx], [0], s=80 ** 2 / 4, color=CAT_CMAP[s - 1], edgecolors="k", zorder=3)
    ax.set_axis_off()
    ax.set_aspect("equal")
    ax.set_xlim(-0.2, 2.2)
    ax.set_ylim(-0.3, 0.3)
    return fig


def save_tight(fig, folder, name):
    """exportgraphics: PNG (300 dpi) and PDF, cropped to the content."""
    os.makedirs(folder, exist_ok=True)
    fig.savefig(os.path.join(folder, name + ".png"), dpi=300, bbox_inches="tight", facecolor="w")
    fig.savefig(os.path.join(folder, name + ".pdf"), bbox_inches="tight", facecolor="w")
    plt.close(fig)
    SAVED.append(os.path.join(folder, name))


# ---------------------------------------------------------------------------
# NodeSizeDistribution_Purple_29Oct26.m, the two figures
# ---------------------------------------------------------------------------
def node_size_bands(pct_nodes, pct_time, band_names, colors=COND_COLORS_PURPLE):
    """Two panels of grouped bars, the same size bands counted by nodes (left)
    and by recording time (right). pct_*: bands x conditions. Saved 25 x 16."""
    fig, axes = plt.subplots(1, 2, figsize=(25, 16))
    nb, nc = np.asarray(pct_nodes).shape
    x = np.arange(1, nb + 1)
    w = 0.8 / nc                                 # MATLAB's grouped bar width
    for ax, M, ylab, title in ((axes[0], pct_nodes, "Percent of all nodes", "Share of nodes"),
                               (axes[1], pct_time, "Percent of recording time", "Share of recording time")):
        for q in range(nc):
            ax.bar(x + (q - (nc - 1) / 2) * w, np.asarray(M)[:, q], w, color=colors[q], edgecolor="k")
        ax.set_xticks(x, band_names)
        ax.set_xlabel("Node size (No. of time points)")
        ax.set_ylabel(ylab)
        ax.set_title(title)
        ax.set_ylim(0, 100)
    return fig


def node_size_histogram(sizes, colors=COND_COLORS_PURPLE):
    """Number of nodes per node size, log-log, one stair line per condition.
    sizes: list of arrays (pooled node sizes per condition). Saved 16 x 13."""
    max_s = max(np.max(s) for s in sizes)
    ed = np.unique(np.concatenate([[1], 10 ** np.arange(0, np.ceil(np.log10(max_s)) + 1e-9, 0.1)]))
    fig, ax = plt.subplots(figsize=(16, 13))
    for s, c in zip(sizes, colors):
        cnt, _ = np.histogram(s, ed)             # histcounts: the last bin includes its right edge
        cnt = np.where(cnt > 0, cnt, np.nan)     # a log axis cannot show 0 (MATLAB leaves a gap)
        ax.step(ed[:-1], cnt, where="post", linewidth=3, color=c)
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Node size (No. of time points)")
    ax.set_ylabel("Number of nodes")
    ax.set_title("Node size distribution")
    ax.set_xlim(1, max_s)
    return fig
