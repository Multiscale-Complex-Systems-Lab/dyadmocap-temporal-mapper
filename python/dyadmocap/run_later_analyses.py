"""
run_later_analyses.py - the correlation bars, the purple and icon figures,
the node-size distribution, the 8-panel node distance figure and the largest
nodes, starting from the per-dyad files the earlier stages wrote. The numbers
are the same analyses as the earlier stages; what differs is mostly the
drawing (purple, state-pair icons, correlation bars).

    Step  MATLAB script                                 figures (below Stats_Figures)
    1     CorrPairBars_PerCategory_28Oct26              GraphMetrics_Correlation/Subgraph_CorrBars_Pairwise
                                                        Cycles_Correlation/PerCategory_CorrBars_Pairwise
    2     SpearCorr_WholeGraph_Bars_29Oct26             GraphMetrics_Correlation/WholeGraph_Bars
    3     SpearCorr_CycWholeGraph_Bars_29Oct26          Cycles_Correlation/WholeGraph_Bars
    4     GTK_MAN_WholeStats_Purple_29Oct26             GraphMetrics_PairedTtest/WholeGraph_Purple
    5     WholeGraphsCycles_Purple_29Oct26              Cycles_PairedTtest/WholeGraph_Purple
    6     NodeSizeDistribution_Purple_29Oct26           GraphMetrics_PairedTtest/NodeSizeDistribution_Purple
    7     BothActive_Inactive_Purple_Icons_29Oct26      NodeDistance_PairedTtest/BothActive_BothInactive_Purple_WithIcons
    8     Person1_Person2_Active_Purple_Icons_29Oct26   NodeDistance_PairedTtest/Person1_Person2_Purple_WithIcons
    9     BothActiveBothInactive_SpCorr_Icons_29Oct26   NodeDistance_Correlation/BothActive_BothInactive_WithIcons
    10    Person1Person2_SpCorr_Icons_29Oct26           NodeDistance_Correlation/Person1_Person2_WithIcons
    11    NodeDistanceIcons_29Oct26                     NodeDistance_PairedTtest/StateIcons
    12    NodeDistance_8Panel_Purple_30Oct26            NodeDistance_PairedTtest/EightPanel_Purple
    13    TopNodes_26Oct26                              GraphMetrics_PairedTtest/TopNodes

Tables: step 1 writes the two pairwise tables (CorrPairwise_Subgraph,
CorrPairwise_CyclesPerCategory), as in MATLAB; step 6 writes the node-size
summary and bands (NodeSizeSummary, NodeSizeBands, the tables that
NodeSizeDistribution_Purple_29Oct26.m displays); step 13 writes TopNodes and
LargestNodeByState. The other steps print their numbers.

HOW TO RUN, after the four earlier stages (or with run_pipeline.py):
    python -m dyadmocap.run_later_analyses
Bootstraps use 10,000 resamples, seed 1, as the MATLAB scripts.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import time
import numpy as np
import pandas as pd
from scipy import stats

from . import dymo_settings as S
from .dymo_report import report, run_with_summary

N_BOOT = 10000
OUT = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
FIG = os.path.join(OUT, "Stats_Figures")
GM_DIR = os.path.join(OUT, "Stats_GraphMetrics")
ND_DIR = os.path.join(OUT, "Stats_NodeDistance")
CYC_DIR = os.path.join(OUT, "Stats_Cycles")

STATES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]   # icon numbers 1-4
ARROW = " → "
W_LABEL = "Weighted mean distance"
# which stored distance is "from -> to" (the keys of dymo_tables.KEY)
DIST_KEY = {(2, 1): "BA_12", (1, 2): "BA_21", (2, 2): "BA_11", (1, 1): "BA_22",
            (3, 4): "P_12", (4, 3): "P_21", (3, 3): "P_11", (4, 4): "P_22"}


# ---------------------------------------------------------------------------
# reading the per-dyad files
# ---------------------------------------------------------------------------
def _read(path):
    if not os.path.isfile(path):
        raise FileNotFoundError("%s not found - run the earlier stages first "
                                "(python -m dyadmocap.run_pipeline)." % path)
    return pd.read_csv(path)


def _paired(per):
    """dict group -> table indexed by dyad, the dyads present in both conditions."""
    per = per.copy()
    per["Dyad"] = per["Dyad"].astype(str)
    dyads = sorted(set(per[per.Condition == "GTK"].Dyad) & set(per[per.Condition == "MAN"].Dyad))
    return {g: per[per.Condition == g].set_index("Dyad").loc[dyads] for g in S.GROUPS}, dyads


def _cat_matrix(tab, metric):
    return tab[["%s_%d" % (metric, c) for c in range(1, 5)]].to_numpy(dtype=float)


def _ttest(a, b):
    v = np.isfinite(a) & np.isfinite(b)
    r = stats.ttest_rel(a[v], b[v])
    return r.pvalue, r.statistic, int(v.sum()) - 1, a[v].mean(), b[v].mean()


def main():
    from .dymo_graph_metrics import REPORTED_METRICS, LABELS_WHOLE, node_labels
    from .dymo_correlations import spearman_with_ci, spearman_pair_delta
    from .dymo_paired import paired_diff_stats
    from .dymo_format import write_table
    from .run_cycles import add_cycles_per_node
    from .run_pipeline_to_tm import load_tm
    from . import dymo_stats_figures as F
    from . import dymo_later_figures as L
    import matplotlib.pyplot as plt

    F.SAVED.clear()   # count only this stage's figures (stages can share one process)
    t_all = time.time()
    timing = {}
    tag = S.PY_TAG
    PURPLE = F.COND_COLORS_PURPLE
    print("Later analyses: run %s\n" % tag)

    whole, dyads = _paired(_read(os.path.join(GM_DIR, "PerDyad_WholeGraphMetrics_%s.csv" % tag)))
    percat, d2 = _paired(_read(os.path.join(GM_DIR, "PerDyad_CategoryMetrics_%s.csv" % tag)))
    dist, d3 = _paired(_read(os.path.join(ND_DIR, "PerDyad_CategoryDistances_%s.csv" % tag)))
    cyc_per = add_cycles_per_node(_read(os.path.join(CYC_DIR, "CycleMetrics_PerDyad_%s.csv" % tag)))
    cyc, d4 = _paired(cyc_per)
    ok = report("same dyads in every file", dyads == d2 == d3 == d4 and len(dyads) > 2, "%d dyads" % len(dyads))
    n_dyads = len(dyads)

    def legend(folder, size=(7, 5)):
        F.save_pub(F.plot_legend_figure(["Casual Chat", "Conflict"], PURPLE, "Condition"),
                   folder, "ConditionLegend", size, layout=False)

    def star_key(folder):
        F.save_pub(L.corr_star_key(n_dyads), folder, "StarKey", (13, 10), layout=False)

    disagree = []

    def check(label, p, ci):
        if np.isfinite(p) and (p < 0.05) != (ci[0] > 0 or ci[1] < 0):
            disagree.append("%s: p = %.3f but CI [%.3f, %.3f]" % (label, p, ci[0], ci[1]))

    # ---- step 1: correlation bars by category, with the pairwise tests ----
    t = time.time()
    pair_idx = [(i, j) for i in range(4) for j in range(i + 1, 4)]
    cyc_metrics = ["winnerProp", "CycleLenMean", "meanEntropy", "cycleCategoryCounts", "cyclesPerNode"]
    cyc_labels = ["Share of cycles won", "CycleLenMean", "meanEntropy", "cycleCategoryCounts", "Cycle Density"]
    runs = [("Subgraphs", percat, REPORTED_METRICS, LABELS_WHOLE,
             os.path.join(FIG, "GraphMetrics_Correlation", "Subgraph_CorrBars_Pairwise"),
             os.path.join(GM_DIR, "CorrPairwise_Subgraph_%s.csv" % tag)),
            ("Cycles", cyc, cyc_metrics, cyc_labels,
             os.path.join(FIG, "Cycles_Correlation", "PerCategory_CorrBars_Pairwise"),
             os.path.join(CYC_DIR, "CorrPairwise_CyclesPerCategory_%s.csv" % tag))]
    print("\nStep 1: correlation bars by category (pairwise)")
    for run, tabs, metrics, labels, folder, table_file in runs:
        star_key(folder)
        rows = []
        for metric, label in zip(metrics, labels):
            XG, XM = _cat_matrix(tabs["GTK"], metric), _cat_matrix(tabs["MAN"], metric)
            rho, lo, hi, pr = (np.full(4, np.nan) for _ in range(4))
            for c in range(4):
                rho[c], pr[c], ci, _ = spearman_with_ci(XG[:, c], XM[:, c], N_BOOT)
                lo[c], hi[c] = ci
                check("%s, %s" % (label, STATES[c]), pr[c], ci)
            pairs = [spearman_pair_delta(XG, XM, i, j, N_BOOT) for i, j in pair_idx]
            for P in pairs:
                rows.append(dict(Metric=label, Pair="%s vs %s" % (STATES[P["i"]], STATES[P["j"]]),
                                 N_dyads=P["nDyads"], Rho_first=P["rhoI"], Rho_second=P["rhoJ"],
                                 Delta_rho=P["delta"], CI95_Lower=P["CI95"][0], CI95_Upper=P["CI95"][1],
                                 Stars=P["stars"]))
            F.save_pub(L.corr_pair_bars(rho, lo, hi, STATES, F.CAT_CMAP, label, pairs, pr),
                       folder, metric, (18, 16), grid=False)
            sig = ["%s-%s %s" % (STATES[q["i"]], STATES[q["j"]], q["stars"]) for q in pairs if q["stars"]]
            print("  %-10s %-32s significant pairs: %s" % (run, label, "; ".join(sig) or "none"))
        write_table(pd.DataFrame(rows), table_file)
    timing["1 pairwise bars"] = time.time() - t

    # ---- steps 2 and 3: whole-graph correlation bars ----
    t = time.time()
    cyc_whole = ["CycleLenMean", "meanEntropy", "cycleDensity", "CycleCount"]
    cyc_whole_labels = ["Cycle Mean Length", "mean Entropy", "Cycle Density", "CycleCount"]
    for step, tabs, metrics, labels, sub in (
            (2, whole, REPORTED_METRICS, LABELS_WHOLE, "GraphMetrics_Correlation"),
            (3, cyc, cyc_whole, cyc_whole_labels, "Cycles_Correlation")):
        folder = os.path.join(FIG, sub, "WholeGraph_Bars")
        star_key(folder)
        print("\nStep %d: whole-graph correlation bars (%s)" % (step, sub.split("_")[0]))
        for metric, label in zip(metrics, labels):
            x, y = tabs["GTK"][metric].to_numpy(float), tabs["MAN"][metric].to_numpy(float)
            rho, p, ci, n = spearman_with_ci(x, y, N_BOOT)
            print("  %-32s rho = %.3f, p = %.3f, 95%% CI [%.3f, %.3f], N = %d" % (label, rho, p, ci[0], ci[1], n))
            if not np.isfinite(rho):
                continue
            check(label + ", whole graph", p, ci)
            ylim = (min(-0.25, ci[0] - 0.10), max(1.0, ci[1] + 0.15))
            F.save_pub(L.corr_whole_bar(rho, ci[0], ci[1], p, label, ylim), folder, metric, (8, 16), grid=False)
    timing["2+3 whole-graph bars"] = time.time() - t

    # ---- steps 4 and 5: purple paired bars, whole graph ----
    t = time.time()
    cyc_purple = ["CycleCount", "CycleLenMean", "meanEntropy", "cycleDensity"]
    cyc_purple_labels = ["CycleCount", "Cycle Mean Length", "mean Entropy", "Cycle Density"]
    for step, tabs, metrics, labels, sub, prefix in (
            (4, whole, REPORTED_METRICS, LABELS_WHOLE, "GraphMetrics_PairedTtest", "WG1_"),
            (5, cyc, cyc_purple, cyc_purple_labels, "Cycles_PairedTtest", "WGCycle_")):
        folder = os.path.join(FIG, sub, "WholeGraph_Purple")
        legend(folder)
        print("\nStep %d: paired t-tests, whole graph (%s), purple" % (step, sub.split("_")[0]))
        for metric, label in zip(metrics, labels):
            x, y = tabs["GTK"][metric].to_numpy(float), tabs["MAN"][metric].to_numpy(float)
            P = paired_diff_stats(x, y)
            print("  %-32s t(%d) = %.3f, p = %.4f, dz = %.3f" % (label, P["df"], P["t"], P["p"], P["dz"]))
            F.save_pub(F.plot_whole_paired_bar(x, y, P["p"], label, "", PURPLE),
                       folder, prefix + metric, (13, 16), grid=False)
    timing["4+5 purple whole"] = time.time() - t

    # ---- step 6: node size distribution ----
    t = time.time()
    print("\nStep 6: node size distribution (pooled over dyads)")
    edges = [1, 2, 5, 10, 50, np.inf]
    band_names = ["1", "2-4", "5-9", "10-49", "50+"]
    names = {"GTK": "Casual Chat", "MAN": "Conflict"}
    sizes, rows_s, rows_b = [], [], []
    pct_nodes, pct_time = np.full((5, 2), np.nan), np.full((5, 2), np.nan)
    for q, group in enumerate(S.GROUPS):
        tm = load_tm(group)
        s = np.concatenate([np.asarray(tm[d]["nodesize"], float).ravel() for d in dyads])
        sizes.append(s)
        rows_s.append(dict(Condition=names[group], N_dyads=len(dyads), N_nodes=s.size, N_samples=s.sum(),
                           MeanNodeSize=s.mean(), MedianNodeSize=np.median(s), MaxNodeSize=s.max(),
                           PctNodes_Size1=100 * np.mean(s == 1), PctTime_Size1=100 * s[s == 1].sum() / s.sum(),
                           FrameWeightedMeanSize=np.sum(s ** 2) / s.sum()))
        for b in range(5):
            inb = (s >= edges[b]) & (s < edges[b + 1])
            pct_nodes[b, q] = 100 * inb.sum() / s.size
            pct_time[b, q] = 100 * s[inb].sum() / s.sum()
            rows_b.append(dict(Condition=names[group], NodeSizeBand=band_names[b],
                               PctOfNodes=pct_nodes[b, q], PctOfTime=pct_time[b, q]))
        print("  %-11s %d nodes, %.1f %% of nodes are single time points, holding %.1f %% of the time"
              % (names[group], s.size, rows_s[-1]["PctNodes_Size1"], rows_s[-1]["PctTime_Size1"]))
        del tm
    write_table(pd.DataFrame(rows_s), os.path.join(GM_DIR, "NodeSizeSummary_%s.csv" % tag))
    write_table(pd.DataFrame(rows_b), os.path.join(GM_DIR, "NodeSizeBands_%s.csv" % tag))
    folder = os.path.join(FIG, "GraphMetrics_PairedTtest", "NodeSizeDistribution_Purple")
    legend(folder)
    F.save_pub(L.node_size_bands(pct_nodes, pct_time, band_names), folder, "NodeSize_NodesVsTime",
               (25, 16), grid=False)
    F.save_pub(L.node_size_histogram(sizes), folder, "NodeSize_Histogram", (16, 13), grid=False)
    timing["6 node sizes"] = time.time() - t

    # ---- steps 7-12: node distances ----
    t = time.time()

    def dv(group, frm, to):
        return dist[group][DIST_KEY[(frm, to)]].to_numpy(float)

    def title(frm, to):
        return STATES[frm - 1] + ARROW + STATES[to - 1]

    def paired_fig(folder, name, panels, size=(25, 16), shape=(1, 2)):
        """plotPairedComparison panels, purple; saved plain, then with icons."""
        fig, axes = plt.subplots(*shape, figsize=size)
        for ax, (frm, to) in zip(np.ravel(axes), panels):
            g, m = dv("GTK", frm, to), dv("MAN", frm, to)
            p, tt, df, mg, mm = _ttest(g, m)
            print("  %-34s t(%d) = %.2f, p = %.3f, mean Casual Chat = %.3f, mean Conflict = %.3f"
                  % (title(frm, to).replace(ARROW, " -> "), df, tt, p, mg, mm))
            F.plot_paired_comparison(ax, g, m, p, title(frm, to), W_LABEL, PURPLE)
        F.save_pub(fig, folder, name, size, grid=False, close=False)
        L.add_state_pair_icons(fig, panels, folder, name + "_Icons")

    def spear_fig(folder, name, panels):
        fig, axes = plt.subplots(1, 2, figsize=(25, 16))
        for ax, (frm, to) in zip(axes, panels):
            g, m = dv("GTK", frm, to), dv("MAN", frm, to)
            rho, p, ci, n = spearman_with_ci(g, m, N_BOOT)
            print("  %-34s rho = %.4f, p = %.4f, 95%% CI [%.3f, %.3f], N = %d"
                  % (title(frm, to).replace(ARROW, " -> "), rho, p, ci[0], ci[1], n))
            F.plot_spearman_comparison(ax, g, m, rho, p, title(frm, to), "Casual Chat", "Conflict")
        F.save_pub(fig, folder, name, (25, 16), grid=False, close=False)
        L.add_state_pair_icons(fig, panels, folder, name + "_Icons")

    print("\nStep 7: node distance, Both Active / Both Inactive, purple with icons")
    f = os.path.join(FIG, "NodeDistance_PairedTtest", "BothActive_BothInactive_Purple_WithIcons")
    legend(f)
    paired_fig(f, "VPSubplot_P12_Paired_Dyad_Comparison", [(1, 2), (2, 1)])
    paired_fig(f, "VPSubplot_SameCategory_Paired_Dyad_Comparison", [(1, 1), (2, 2)])

    print("\nStep 8: node distance, Person 1 / Person 2, purple with icons")
    f = os.path.join(FIG, "NodeDistance_PairedTtest", "Person1_Person2_Purple_WithIcons")
    legend(f)
    paired_fig(f, "VPSbplt_P12_UnPaired_Dyad_Comparison", [(3, 4), (4, 3)])
    paired_fig(f, "VPSbplt_P22_UnPaired_Dyad_Comparison", [(3, 3), (4, 4)])
    # the two averages (no icons: each panel averages two state pairs);
    # each average over the dyads with all four values finite
    g12, g21, m12, m21 = dv("GTK", 3, 4), dv("GTK", 4, 3), dv("MAN", 3, 4), dv("MAN", 4, 3)
    vb = np.isfinite(g12) & np.isfinite(m12) & np.isfinite(g21) & np.isfinite(m21)
    g11, g22, m11, m22 = dv("GTK", 3, 3), dv("GTK", 4, 4), dv("MAN", 3, 3), dv("MAN", 4, 4)
    vw = np.isfinite(g11) & np.isfinite(g22) & np.isfinite(m11) & np.isfinite(m22)
    fig, axes = plt.subplots(1, 2, figsize=(25, 16))
    for ax, (ttl, g, m, ylab) in zip(axes, (
            ("Paired dyad comparison of Average\ninter-category node distance",
             (g12[vb] + g21[vb]) / 2, (m12[vb] + m21[vb]) / 2, "Averaged inter-category Weighted\nmean distance"),
            ("Paired dyad comparison of Averaged\nintra-category node distance",
             (g11[vw] + g22[vw]) / 2, (m11[vw] + m22[vw]) / 2, "Averaged within inter-category\nWeighted mean distance"))):
        F.plot_paired_comparison(ax, g, m, _ttest(g, m)[0], ttl, ylab, PURPLE)
    F.save_pub(fig, f, "VPPaired_same_Dyad_Unpair_Comparison", (25, 16), grid=False)

    print("\nStep 9: node distance correlation, Both Active / Both Inactive, with icons")
    f = os.path.join(FIG, "NodeDistance_Correlation", "BothActive_BothInactive_WithIcons")
    F.save_pub(F.plot_corr_legend(["Dyads"], [F.MATLAB_BLUE]), f, "SeriesLegend", (13, 10), layout=False)
    spear_fig(f, "VPSubplot_P12_Paired_Dyad_Comparison", [(1, 2), (2, 1)])
    spear_fig(f, "VPSubplot_P22_Paired_Dyad_Comparison", [(1, 1), (2, 2)])

    print("\nStep 10: node distance correlation, Person 1 / Person 2, with icons")
    f = os.path.join(FIG, "NodeDistance_Correlation", "Person1_Person2_WithIcons")
    F.save_pub(F.plot_corr_legend(["Dyads"], [F.MATLAB_BLUE]), f, "SeriesLegend", (13, 10), layout=False)
    spear_fig(f, "VPSubplot_P12_Paired_Dyad_Comparison", [(3, 4), (4, 3)])
    spear_fig(f, "VPSubplot_P22_Paired_Dyad_Comparison", [(3, 3), (4, 4)])

    print("\nStep 11: the 16 state-pair icons")
    f = os.path.join(FIG, "NodeDistance_PairedTtest", "StateIcons")
    k = 0
    for s1 in range(1, 5):
        for s2 in range(1, 5):
            k += 1
            L.save_tight(L.state_icon(s1, s2), f, "StateIcon_%02d_%s_to_%s"
                         % (k, L.ICON_FILE_NAMES[s1 - 1], L.ICON_FILE_NAMES[s2 - 1]))
    print("  %d icons" % k)

    print("\nStep 12: node distance, 8 panels, purple")
    f = os.path.join(FIG, "NodeDistance_PairedTtest", "EightPanel_Purple")
    legend(f)
    eight = [(1, 1), (2, 2), (3, 3), (4, 4), (1, 2), (2, 1), (3, 4), (4, 3)]
    paired_fig(f, "NodeDistance_8Panel_Purple", eight, size=(40, 26), shape=(2, 4))
    timing["7-12 node distances"] = time.time() - t

    # ---- step 13: the largest nodes, and are they one stay or many returns? ----
    # TopNodes_26Oct26.m. Part 1: the 4 largest nodes of each state in each
    # condition, pooled over dyads, with their span and their number of
    # "visits" (runs of consecutive time points). Part 2: one dyad (the one
    # holding the largest casual-chat node), both conversations, the largest
    # node of each state as a raster. Members are 0-based sample indices here
    # (1-based in MATLAB): span and visits do not depend on that, and the
    # raster time is m / Fs (MATLAB (m - 1) / Fs).
    t = time.time()
    FS, TOP_N = 50.0, 4                # recording rate (Hz) as in the MATLAB script; nodes per state
    print("\nStep 13: the largest nodes of each state")
    tms = {g: load_tm(g) for g in S.GROUPS}
    rows_top = []
    for group in S.GROUPS:
        sz, cat, span, blk, tot = [], [], [], [], []
        for d in dyads:                                  # the dyad order of the other steps
            T = tms[group][d]
            s = np.asarray(T["nodesize"], float).ravel()
            for m in T["members"]:
                m = np.sort(np.asarray(m))
                span.append(m[-1] - m[0] + 1 if m.size else np.nan)
                blk.append(1 + int(np.sum(np.diff(m) > 1)) if m.size else np.nan)
            sz.append(s)
            cat.append(np.asarray(node_labels(T["members"], T["colorvar"])).ravel())
            tot.append(np.full(s.size, s.sum()))
        sz, cat, tot = np.concatenate(sz), np.concatenate(cat), np.concatenate(tot)
        span, blk = np.asarray(span, float), np.asarray(blk, float)
        for c in range(1, 5):
            idx = np.flatnonzero(cat == c)
            if idx.size == 0:
                continue
            pick = idx[np.argsort(-sz[idx], kind="stable")[:TOP_N]]   # MATLAB sort 'descend' is stable
            for j, i in enumerate(pick, start=1):
                rows_top.append(dict(Condition=names[group], BehaviouralState=STATES[c - 1], Rank=j,
                                     Size_points=sz[i], Size_seconds=sz[i] / FS, Span_seconds=span[i] / FS,
                                     Visits=blk[i], PctOfRecording=100 * sz[i] / tot[i]))
    top = pd.DataFrame(rows_top)
    print(top[top.Rank == 1][["Condition", "BehaviouralState", "Size_points", "Visits",
                              "PctOfRecording"]].round(1).to_string(index=False))
    write_table(top, os.path.join(GM_DIR, "TopNodes_%s.csv" % tag))

    # part 2: the dyad holding the largest casual-chat node (first such dyad on a tie)
    pick_d = max(dyads, key=lambda d: (np.max(tms["GTK"][d]["nodesize"]), -dyads.index(d)))
    fig, axes = plt.subplots(4, 2, figsize=(25, 16))
    rows_v = []
    for k, group in enumerate(S.GROUPS):
        T = tms[group][pick_d]
        s = np.asarray(T["nodesize"], float).ravel()
        cat = np.asarray(node_labels(T["members"], T["colorvar"])).ravel()
        dur = s.sum() / FS
        for c in range(1, 5):
            ax = axes[c - 1, k]
            idx = np.flatnonzero(cat == c)
            if idx.size == 0:
                ax.set_axis_off()
                continue
            m = np.sort(np.asarray(T["members"][idx[np.argmax(s[idx])]]))
            brk = np.flatnonzero(np.diff(m) > 1)
            lens = np.r_[brk, m.size - 1] - np.r_[0, brk + 1] + 1      # length of each visit
            ax.plot(m / FS, np.zeros(m.size), "|", color=F.CAT_CMAP[c - 1], markersize=20, markeredgewidth=1.5)
            ax.set_xlim(0, dur)
            ax.set_ylim(-1, 3)
            ax.set_yticks([])
            ax.text(0.015, 0.96, "%s - %d points, %d visits" % (STATES[c - 1], m.size, lens.size),
                    transform=ax.transAxes, fontsize=22, fontweight="bold", va="top")
            if c == 1:
                ax.set_title(names[group])
            if c == 4:
                ax.set_xlabel("Time in the conversation (s)")
            rows_v.append(dict(Condition=names[group], BehaviouralState=STATES[c - 1], TimePoints=m.size,
                               Visits=lens.size, MeanVisit_points=m.size / lens.size,
                               LongestVisit_points=int(lens.max()), PctOfRecording=100 * m.size / s.sum()))
    F.save_pub(fig, os.path.join(FIG, "GraphMetrics_PairedTtest", "TopNodes"), "TopNode_Raster_BothConditions",
               (25, 16), grid=False)
    write_table(pd.DataFrame(rows_v), os.path.join(GM_DIR, "LargestNodeByState_%s.csv" % tag))
    del tms
    timing["13 top nodes"] = time.time() - t

    # ---- checks ----
    print()
    if disagree:
        print("Bars where the p-value and the 95% CI disagree:")
        for s in disagree:
            print("  " + s)
    else:
        print("p-values and CIs agree for every bar.")
    n_png = sum(os.path.isfile(s + ".png") for s in F.SAVED)
    n_pdf = sum(os.path.isfile(s + ".pdf") for s in F.SAVED)
    ok &= report("figures saved, PNG + PDF", n_png == len(F.SAVED) == n_pdf, "%d figures" % len(F.SAVED))

    total = time.time() - t_all
    print("\nTIMING")
    for key, v in timing.items():
        print("  %-22s %7.0f s" % (key, v))
    print("  %-22s %7.1f min" % ("TOTAL", total / 60))
    print("\nLATER ANALYSES: %s   (%.1f min)" % ("PASS" if ok else "FAIL", total / 60))
    print("Figures: %s" % FIG)


if __name__ == "__main__":
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    run_with_summary(main, os.path.join(here, "LaterAnalyses_Summary_%s.txt" % S.PY_TAG), "LATER ANALYSES")
