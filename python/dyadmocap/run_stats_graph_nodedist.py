"""
run_stats_graph_nodedist.py - graph metrics and node distances, their
statistics, and the statistics figures, starting from the saved TM graphs
(run_pipeline_to_tm.py). Every step is timed.

    Step 1  load the saved TM graphs (TM_Graphs\\TM_GTK/MAN_<PY_TAG>.pkl)
    Step 2  graph metrics of every dyad (whole graph and per category)
    Step 3  node distances of every dyad (D_simp, 8 weighted category distances)
    Step 4  statistics tables, as the eight MATLAB scripts write them:
              graph metrics  - paired t-tests (whole, per category),
                               Spearman (whole, per category) with bootstrap CI,
                               symmetric vs asymmetric delta-rho
              node distances - paired t-tests and Spearman, for
                               Both Active / Both Inactive and Person 1 / Person 2
    Step 6  the figures: subgraph metrics per category and the mean path
            distance by state, 11 figures, PNG + PDF (the superseded figures of
            the eight MATLAB scripts only with OLD_FIGURES = True, see below).
The correlations use 10,000 bootstrap resamples, seed 1.

HOW TO RUN (from the python folder of the repository), after run_pipeline_to_tm:
    conda activate dyadmocap-tm
    python -m dyadmocap.run_stats_graph_nodedist
or run every stage in order with  python -m dyadmocap.run_pipeline
Expected about 10-20 minutes for the study data (node distances and figures take most of it).

OUTPUT, below <Python results folder>\\<PY_TAG>\\:
    Stats_GraphMetrics\\   the graph-metric and hubness tables (aggregate) +
                          per-dyad metrics (whole graph and per category)
    Stats_NodeDistance\\   the 4 node-distance tables (aggregate) + per-dyad distances
    Stats_Figures\\        the figures, in the MATLAB scripts' folder names
Per-dyad files and figures are participant-level: they stay on this machine.
WHAT IT PRINTS: PASS/FAIL lines and times only, saved to
Stats_GraphNodeDist_Summary_<PY_TAG>.txt in this folder.

The per-dyad per-category metrics are also saved, for run_later_analyses.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import glob
import os
import time
import numpy as np
import pandas as pd
from scipy import stats

from . import dymo_settings as S
from .dymo_report import report, run_with_summary

# SUPERSEDED FIGURES. The final figure set: whole-graph comparisons in purple,
# correlations as bar plots (only the node distances as scatter plots, with
# state-pair icons), node distances in purple with icons - all drawn in
# run_later_analyses.py. The older versions of those figures (condition
# colours teal/salmon, correlation scatters, delta-rho plots) are made only if
# OLD_FIGURES = True. The TABLES are unchanged. The MATLAB scripts have the
# same switch (makeFigures).
OLD_FIGURES = False

N_BOOT = 10000
OUT = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
FIG = os.path.join(OUT, "Stats_Figures")


def _p_pair(a, b):
    """Paired t-test p on the pairs finite in both (NaN with fewer than 2)."""
    v = np.isfinite(a) & np.isfinite(b)
    return stats.ttest_rel(a[v], b[v]).pvalue if v.sum() > 1 else np.nan


def _spear(a, b):
    from .dymo_correlations import spearman
    v = np.isfinite(a) & np.isfinite(b)
    return spearman(a[v], b[v]) if v.sum() >= 3 else (np.nan, np.nan)


def main():
    from .run_pipeline_to_tm import load_tm
    from .dymo_graph_metrics import (whole_graph_metrics, category_metrics, node_labels, paired_row,
                                    REPORTED_METRICS, LABELS_WHOLE, LABELS_CATEGORY, CATEGORY_NAMES)
    from .dymo_node_distance import compute_dsimp, four_distances
    from .dymo_correlations import (spearman_with_ci, spearman_group_delta,
                                   correlation_verdict, delta_verdict)
    from .dymo_tables import tables_for_pair, KEY
    from .dymo_matlab import matlab_median
    from .dymo_paired import paired_diff_stats, paired_group_delta, group_means
    from .dymo_hubness import node_closeness_by_category, hubness_tables
    from .dymo_format import write_table, ci_verdict
    from . import dymo_stats_figures as F

    F.SAVED.clear()   # count only this stage's figures (stages can share one process)
    t_all = time.time()
    timing = {}
    print("Graph metrics and node distances: statistics and figures\n")

    # ---- step 1: the saved TM graphs ----
    t = time.time()
    tm = {g: load_tm(g) for g in S.GROUPS}
    dyads = sorted(set(tm["GTK"]) & set(tm["MAN"]))
    timing["1 load TM graphs"] = time.time() - t
    print("Step 1: %d dyads in both conditions (%.0f s)" % (len(dyads), timing["1 load TM graphs"]))

    # ---- steps 2 and 3: metrics and distances of every dyad ----
    whole, percat, dist, close = {}, {}, {}, {}
    t_gm = t_nd = 0.0
    for group in S.GROUPS:
        whole[group], percat[group], dist[group], close[group] = {}, {}, {}, {}
        for i, d in enumerate(dyads, start=1):
            T = tm[group][d]
            t = time.time()
            whole[group][d] = whole_graph_metrics(T["g_simp"], T["nodesize"])
            percat[group][d] = category_metrics(T["g_simp"], T["members"], T["nodesize"], T["colorvar"])
            t_gm += time.time() - t

            t = time.time()
            labels = node_labels(T["members"], T["colorvar"])
            D = compute_dsimp(T["g"], T["members"])
            nsz = np.asarray(T["nodesize"])
            ba = four_distances(D, labels, nsz, 2, 1)   # 1 = Both Active (2), 2 = Both Inactive (1)
            pp = four_distances(D, labels, nsz, 3, 4)   # 1 = Person 1 Active, 2 = Person 2 Active
            dist[group][d] = {"BA_" + k[1:]: v for k, v in ba.items()}
            dist[group][d].update({"P_" + k[1:]: v for k, v in pp.items()})
            close[group][d] = node_closeness_by_category(D, labels)[0]   # hubness
            t_nd += time.time() - t
            if i % 10 == 0 or i == len(dyads):
                print("  %s: %d / %d dyads done" % (group, i, len(dyads)), flush=True)
    timing["2 graph metrics"] = t_gm
    timing["3 node distances"] = t_nd
    print("Step 2: graph metrics (%.0f s)" % t_gm)
    print("Step 3: node distances (%.0f s)" % t_nd)

    # ---- step 4: the tables ----
    t = time.time()
    gm_dir = os.path.join(OUT, "Stats_GraphMetrics")
    nd_dir = os.path.join(OUT, "Stats_NodeDistance")
    os.makedirs(gm_dir, exist_ok=True)
    os.makedirs(nd_dir, exist_ok=True)

    def arrays(metric):
        xw = np.array([whole["GTK"][d][metric] for d in dyads], dtype=float)
        yw = np.array([whole["MAN"][d][metric] for d in dyads], dtype=float)
        Xc = np.array([percat["GTK"][d][metric] for d in dyads], dtype=float)
        Yc = np.array([percat["MAN"][d][metric] for d in dyads], dtype=float)
        return xw, yw, Xc, Yc

    # graph metrics, paired (GTK_MAN_WholeStats / Subgraphstats_Pairedttest)
    # Whole graph: pairedDiffStats adds the mean difference, t, df,
    # Cohen's dz and a BCa bootstrap CI of the difference (dyads resampled).
    rows_pw, rows_pc, rows_pg = [], [], []
    for metric, lw, lc in zip(REPORTED_METRICS, LABELS_WHOLE, LABELS_CATEGORY):
        xw, yw, Xc, Yc = arrays(metric)
        r = paired_row(xw, yw)                        # N, means and SEMs
        P = paired_diff_stats(xw, yw)                 # t-test, dz, BCa CI
        rows_pw.append(dict(Metric=lw, N=r["N"], GTK_Mean=r["GTK_Mean"], GTK_SEM=r["GTK_SEM"],
                            MAN_Mean=r["MAN_Mean"], MAN_SEM=r["MAN_SEM"], MeanDiff_GTKminusMAN=P["meanDiff"],
                            t=P["t"], df=P["df"], dz=P["dz"], CI_Lower=P["ciBoot"][0], CI_Upper=P["ciBoot"][1],
                            P_Value=P["p"]))
        for c, cname in enumerate(CATEGORY_NAMES):
            rows_pc.append(dict(Metric=lc, Group="Symmetric Interaction" if c < 2 else "Asymmetric Interaction",
                                BehaviouralCategory=cname, **paired_row(Xc[:, c], Yc[:, c])))
        # symmetric vs asymmetric: is the condition effect (GTK - MAN) different?
        # One value per dyad per group: the mean of that group's two categories.
        R = paired_group_delta(group_means(Xc, [0, 1]), group_means(Yc, [0, 1]),
                               group_means(Xc, [2, 3]), group_means(Yc, [2, 3]))
        rows_pg.append(dict(Metric=lc, N=R["N"], Symmetric_MeanDiff=R["diffG1"], Asymmetric_MeanDiff=R["diffG2"],
                            Delta_MeanDiff=R["delta"], CI_Lower=R["CI"][0], CI_Upper=R["CI"][1],
                            Verdict=ci_verdict(R["CI"], "Effect larger in symmetric", "Effect larger in asymmetric")))
    t_pw, t_pc, t_pg = pd.DataFrame(rows_pw), pd.DataFrame(rows_pc), pd.DataFrame(rows_pg)

    # graph metrics, correlations (SpearCorr_WholeGraph / SpearCorr_SubgraphStats_AsySymBoot)
    # Correlation tables in the MATLAB format:
    # <identifier>, N_dyads, SpearmanRho, CI_Lower, CI_Upper, Verdict. No p-value:
    # the BCa interval (dyads resampled, 10,000, seed 1) is the inference. rho and
    # p are kept in local variables only, for the scatter annotations.
    rows_w, rows_c, rows_d, delta = [], [], [], {}
    cat_rho, whole_rp = {}, {}
    for metric, label in zip(REPORTED_METRICS, LABELS_WHOLE):
        xw, yw, Xc, Yc = arrays(metric)
        rho, p, ci, n = spearman_with_ci(xw, yw, N_BOOT)
        whole_rp[metric] = (rho, p)
        rows_w.append(dict(Metric=label, N_dyads=n, SpearmanRho=rho, CI_Lower=ci[0], CI_Upper=ci[1],
                           Verdict=correlation_verdict(ci)))
        cat_rho[metric] = []
        for c, cname in enumerate(CATEGORY_NAMES):
            rho, p, ci, n = spearman_with_ci(Xc[:, c], Yc[:, c], N_BOOT)
            cat_rho[metric].append((rho, p))
            rows_c.append(dict(Metric=label, BehaviouralCategory=cname, N_dyads=n,
                               SpearmanRho=rho, CI_Lower=ci[0], CI_Upper=ci[1],
                               Verdict=correlation_verdict(ci)))
        # symmetric (categories 1-2) vs asymmetric (3-4), dyads resampled
        R = spearman_group_delta(Xc, Yc, [0, 1], [2, 3], N_BOOT)
        R["verdict"] = delta_verdict(R["CI"])
        delta[metric] = R
        rows_d.append(dict(Metric=label, N_dyads=R["nDyads"],
                           Symmetric_rho=R["rhoG1"], Symmetric_CI_Lower=R["ciG1"][0], Symmetric_CI_Upper=R["ciG1"][1],
                           Asymmetric_rho=R["rhoG2"], Asymmetric_CI_Lower=R["ciG2"][0], Asymmetric_CI_Upper=R["ciG2"][1],
                           Delta_rho=R["delta"], Delta_CI_Lower=R["CI"][0], Delta_CI_Upper=R["CI"][1],
                           Verdict=R["verdict"]))
    t_w, t_c, t_d = pd.DataFrame(rows_w), pd.DataFrame(rows_c), pd.DataFrame(rows_d)

    # node distances (the four NodeDistance scripts): paired tables as before;
    # the correlation tables now carry a BCa interval (spearmanWithCI), as MATLAB
    ba_p, _ = tables_for_pair(dist, dyads, "Both Active", "Both Inactive")
    pp_p, _ = tables_for_pair(dist, dyads, "Person 1 Active", "Person 2 Active")

    def nd_corr(c1, c2):
        rows = []
        for frm, to in [(c1, c2), (c2, c1), (c1, c1), (c2, c2)]:
            g = np.array([dist["GTK"][d][KEY[(frm, to)]] for d in dyads], dtype=float)
            m = np.array([dist["MAN"][d][KEY[(frm, to)]] for d in dyads], dtype=float)
            v = np.isfinite(g) & np.isfinite(m)
            rho, p, ci, n = spearman_with_ci(g[v], m[v], N_BOOT)
            rows.append(dict(Comparison="%s -> %s" % (frm, to), N_dyads=int(v.sum()),
                             MedianGTK=matlab_median(g[v]), MedianMAN=matlab_median(m[v]),
                             SpearmanRho=rho, CI_Lower=ci[0], CI_Upper=ci[1],
                             Verdict=correlation_verdict(ci)))
        return pd.DataFrame(rows)

    ba_c = nd_corr("Both Active", "Both Inactive")
    pp_c = nd_corr("Person 1 Active", "Person 2 Active")

    # hubness (Hubness_Closeness_22Oct26.m, Hubness_Roles_23Oct26.m)
    cl = {g: np.array([close[g][d] for d in dyads], dtype=float) for g in S.GROUPS}
    hub = hubness_tables(cl, CATEGORY_NAMES)

    # mean path distance by state, Casual Chat vs Conflict
    # (RecordPathDistancePValues_05Nov26.m)
    rows_md = []
    for c, cname in enumerate(CATEGORY_NAMES):
        P = paired_diff_stats(cl["GTK"][:, c], cl["MAN"][:, c])
        rows_md.append(dict(State=cname, N_dyads=P["N"], MeanPathDist_Casual=P["meanA"],
                            MeanPathDist_Conflict=P["meanB"], MeanDiff_CasualMinusConflict=P["meanDiff"],
                            CI_Lower=P["ciBoot"][0], CI_Upper=P["ciBoot"][1], t=P["t"], df=P["df"],
                            p=P["p"], p_Wilcoxon=P["pWilcoxon"], dz=P["dz"]))
    t_md = pd.DataFrame(rows_md)

    # every table: (table, file name, folder, key columns, Monte Carlo columns)
    # The tables are written ROUNDED, as DYMO_roundTable writes MATLAB's (3
    # significant figures; p to 3 decimals, floored at .001). The comparison in
    # step 5b uses the unrounded values held here.
    BOOT = ("CI_Lower", "CI_Upper")
    COR = ("CI_Lower", "CI_Upper", "Symmetric_CI_Lower", "Symmetric_CI_Upper", "Asymmetric_CI_Lower",
           "Asymmetric_CI_Upper", "Delta_CI_Lower", "Delta_CI_Upper")
    tables = [
        (t_pw, "GTKMAN_WhSubgCatsStat", gm_dir, ["Metric"], ("width", BOOT)),
        (t_pc, "GTKMAN_SubgCatsStat", gm_dir, ["Metric", "BehaviouralCategory"], None),
        (t_pg, "GTKMAN_SubgGroupCompare", gm_dir, ["Metric"], ("width", BOOT)),
        (t_w, "WhGSpearCorr", gm_dir, ["Metric"], ("abs", COR)),
        (t_c, "CategoryLevelSpearCorr", gm_dir, ["Metric", "BehaviouralCategory"], ("abs", COR)),
        (t_d, "CorrComparison", gm_dir, ["Metric"], ("abs", COR)),
        (ba_p, "NodeDist_BothActiveInactive_Pairedttest", nd_dir, ["Comparison"], None),
        (pp_p, "NodeDist_Person1Person2_Pairedttest", nd_dir, ["Comparison"], None),
        (ba_c, "NodeDist_BothActiveInactive_SpearmanCorr", nd_dir, ["Comparison"], ("abs", COR)),
        (pp_c, "NodeDist_Person1Person2_SpearmanCorr", nd_dir, ["Comparison"], ("abs", COR)),
        (hub["Hubness_Closeness"], "Hubness_Closeness", gm_dir, ["Condition"], ("width", BOOT)),
        (hub["Hubness_ClosenessByCategory"], "Hubness_ClosenessByCategory", gm_dir,
         ["Condition", "BehaviouralCategory"], None),
        (hub["Hubness_Roles"], "Hubness_Roles", gm_dir, ["Condition"], ("width", BOOT)),
        (hub["Hubness_RoleGap"], "Hubness_RoleGap", gm_dir, ["Contrast"], ("width", BOOT)),
        (t_md, "PathDistance_CasualVsConflict_ByState", gm_dir, ["State"], ("width", BOOT)),
    ]
    tag = S.PY_TAG
    for tab, name, folder, _, _ in tables:
        write_table(tab, os.path.join(folder, "%s_%s.csv" % (name, tag)))
    # per-dyad values (participant-level)
    pd.DataFrame([dict(Condition=g, Dyad=d, **whole[g][d]) for g in S.GROUPS for d in dyads]).to_csv(
        os.path.join(gm_dir, "PerDyad_WholeGraphMetrics_%s.csv" % tag), index=False)
    pd.DataFrame([dict(Condition=g, Dyad=d, **dist[g][d]) for g in S.GROUPS for d in dyads]).to_csv(
        os.path.join(nd_dir, "PerDyad_CategoryDistances_%s.csv" % tag), index=False)
    # the per-category metrics, so that the later analyses
    # (run_later_analyses.py) read them instead of recomputing
    pd.DataFrame([dict(Condition=g, Dyad=d, **{"%s_%d" % (m, c + 1): percat[g][d][m][c]
                                                for m in REPORTED_METRICS for c in range(4)})
                  for g in S.GROUPS for d in dyads]).to_csv(
        os.path.join(gm_dir, "PerDyad_CategoryMetrics_%s.csv" % tag), index=False)
    timing["4 statistics tables"] = time.time() - t
    print("Step 4: statistics tables, %d written (%.0f s)" % (len(tables), timing["4 statistics tables"]))

    ok = True

    # ---- step 6: the figures of the eight MATLAB scripts ----
    t = time.time()
    import matplotlib.pyplot as plt
    CAT = CATEGORY_NAMES

    if OLD_FIGURES:   # superseded (see SUPERSEDED FIGURES at the top)
        # GraphMetrics, paired: whole graph
        f = os.path.join(FIG, "GraphMetrics_PairedTtest", "WholeGraph")
        F.save_pub(F.plot_legend_figure(["Casual Chat", "Conflict"], F.COND_COLORS, "Condition"),
                   f, "ConditionLegend", (13, 10), layout=False)
        for metric, label, p in zip(REPORTED_METRICS, LABELS_WHOLE, t_pw.P_Value):
            xw, yw, _, _ = arrays(metric)
            F.save_pub(F.plot_whole_paired_bar(xw, yw, p, label), f, "WG1_%s" % metric, (13, 16))
    
    # GraphMetrics, paired: per category
    f = os.path.join(FIG, "GraphMetrics_PairedTtest", "Subgraph_ByCategory")
    F.save_pub(F.plot_category_legend(CAT, ["Casual Chat", "Conflict"]), f, "CategoryLegend", (13, 10), layout=False)
    for metric, label in zip(REPORTED_METRICS, LABELS_CATEGORY):
        _, _, Xc, Yc = arrays(metric)
        F.save_pub(F.plot_category_paired_bars(Xc, Yc, CAT, label, "Behavioural Categories"),
                   f, "BC1fig_%s" % metric)

    if OLD_FIGURES:   # superseded (see SUPERSEDED FIGURES at the top)
        # GraphMetrics, correlation: whole graph scatter
        f = os.path.join(FIG, "GraphMetrics_Correlation", "WholeGraph_Scatter")
        F.save_pub(F.plot_corr_legend(["Dyads"], [F.OLIVE]), f, "SeriesLegend", (13, 10), layout=False)
        for metric, label in zip(REPORTED_METRICS, LABELS_WHOLE):
            xw, yw, _, _ = arrays(metric)
            if (np.isfinite(xw) & np.isfinite(yw)).sum() >= 3:
                rho, p = whole_rp[metric]
                F.save_pub(F.plot_whole_scatter(xw, yw, rho, p, label), f, metric, (13, 16))
    
        # GraphMetrics, correlation: delta-rho and four-panel category scatter
        f = os.path.join(FIG, "GraphMetrics_Correlation", "Subgraph_DeltaRho")
        for metric, label in zip(REPORTED_METRICS, LABELS_WHOLE):
            F.save_pub(F.plot_delta_rho(delta[metric], label), f, metric, (13, 16))
        f = os.path.join(FIG, "GraphMetrics_Correlation", "Subgraph_Scatter")
        F.save_pub(F.plot_corr_legend(CAT, F.CAT_CMAP, "", "category"), f, "CategoryLegend", (13, 10), layout=False)
        for metric, label in zip(REPORTED_METRICS, LABELS_WHOLE):
            _, _, Xc, Yc = arrays(metric)
            rr = cat_rho[metric]
            F.save_pub(F.plot_category_scatter(Xc, Yc, [x[0] for x in rr], [x[1] for x in rr], CAT, label), f, metric)
    
    # Mean path distance by state (BC_PathDistanceByState, as
    # RecordPathDistancePValues_05Nov26.m)
    f = os.path.join(FIG, "GraphMetrics_PairedTtest", "MeanPathDistance")
    F.save_pub(F.plot_category_legend(CAT, ["Casual Chat", "Conflict"]), f, "CategoryLegend", (13, 10), layout=False)
    F.save_pub(F.plot_category_paired_bars(cl["GTK"], cl["MAN"], CAT, "Mean path distance",
                                           "Behavioural Categories"), f, "BC_PathDistanceByState")

    # NodeDistance: per-dyad arrays, dyads in the same order in both conditions
    def dv(group, key):
        return np.array([dist[group][d][key] for d in dyads], dtype=float)

    def two_paired(folder, name, left, right):
        """One figure, two plotPairedComparison panels: (title, key or arrays, ylabel)."""
        fig, axes = plt.subplots(1, 2, figsize=(25, 16))   # the saved size: the bracket text is placed in ems
        for ax, (title, g, m, ylab) in zip(axes, (left, right)):
            F.plot_paired_comparison(ax, g, m, _p_pair(g, m), title, ylab)
        F.save_pub(fig, folder, name)

    def two_spear(folder, name, left, right):
        fig, axes = plt.subplots(1, 2)
        for ax, (title, g, m) in zip(axes, (left, right)):
            rho, p = _spear(g, m)
            F.plot_spearman_comparison(ax, g, m, rho, p, title, "Casual Chat", "Conflict")
        F.save_pub(fig, folder, name)

    if OLD_FIGURES:   # superseded (see SUPERSEDED FIGURES at the top)
        W = "Weighted mean distance"
        # NodeDistance, paired: Both Active / Both Inactive (BothActive_Inactive_09July26.m)
        f = os.path.join(FIG, "NodeDistance_PairedTtest", "BothActive_BothInactive")
        F.save_pub(F.plot_legend_figure(["Casual Chat", "Conflict"], F.COND_COLORS, "Condition"),
                   f, "ConditionLegend", (13, 10), layout=False)
        two_paired(f, "VPSubplot_P12_Paired_Dyad_Comparison",
                   ("Both Inactive \u2192 Both Active", dv("GTK", "BA_21"), dv("MAN", "BA_21"), W),
                   ("Both Active \u2192 Both Inactive", dv("GTK", "BA_12"), dv("MAN", "BA_12"), W))
        two_paired(f, "VPSubplot_SameCategory_Paired_Dyad_Comparison",
                   ("Both Inactive \u2192 Both Inactive", dv("GTK", "BA_22"), dv("MAN", "BA_22"), W),
                   ("Both Active \u2192 Both Active", dv("GTK", "BA_11"), dv("MAN", "BA_11"), W))
    
        # NodeDistance, paired: Person 1 / Person 2 (Person1_Person2_Active_09July26.m)
        f = os.path.join(FIG, "NodeDistance_PairedTtest", "Person1_Person2")
        F.save_pub(F.plot_legend_figure(["Casual Chat", "Conflict"], F.COND_COLORS, "Condition"),
                   f, "ConditionLegend", (13, 10), layout=False)
        two_paired(f, "VPSbplt_P12_UnPaired_Dyad_Comparison",
                   ("Person 1 Active \u2192 Person 2 Active", dv("GTK", "P_12"), dv("MAN", "P_12"), W),
                   ("Person 2 Active \u2192 Person 1 Active", dv("GTK", "P_21"), dv("MAN", "P_21"), W))
        two_paired(f, "VPSbplt_P22_UnPaired_Dyad_Comparison",
                   ("Person 1 Active \u2192 Person 1 Active", dv("GTK", "P_11"), dv("MAN", "P_11"), W),
                   ("Person 2 Active \u2192 Person 2 Active", dv("GTK", "P_22"), dv("MAN", "P_22"), W))
        # the two averages, each over the dyads with all four values finite
        g12, g21, m12, m21 = dv("GTK", "P_12"), dv("GTK", "P_21"), dv("MAN", "P_12"), dv("MAN", "P_21")
        vb = np.isfinite(g12) & np.isfinite(m12) & np.isfinite(g21) & np.isfinite(m21)
        g11, g22, m11, m22 = dv("GTK", "P_11"), dv("GTK", "P_22"), dv("MAN", "P_11"), dv("MAN", "P_22")
        vw = np.isfinite(g11) & np.isfinite(g22) & np.isfinite(m11) & np.isfinite(m22)
        two_paired(f, "VPPaired_same_Dyad_Unpair_Comparison",
                   ("Paired dyad comparison of Average\ninter-category node distance",
                    (g12[vb] + g21[vb]) / 2, (m12[vb] + m21[vb]) / 2, "Averaged inter-category Weighted\nmean distance"),
                   ("Paired dyad comparison of Averaged\nintra-category node distance",
                    (g11[vw] + g22[vw]) / 2, (m11[vw] + m22[vw]) / 2, "Averaged within inter-category\nWeighted mean distance"))
    
        # NodeDistance, correlation: Both Active / Both Inactive (BothActiveBothInactive_14July26.m)
        f = os.path.join(FIG, "NodeDistance_Correlation", "BothActive_BothInactive")
        F.save_pub(F.plot_corr_legend(["Dyads"], [F.MATLAB_BLUE]), f, "SeriesLegend", (13, 10), layout=False)
        two_spear(f, "VPSubplot_P12_Paired_Dyad_Comparison",
                  ("Both Inactive \u2192 Both Active", dv("GTK", "BA_21"), dv("MAN", "BA_21")),
                  ("Both Active \u2192 Both Inactive", dv("GTK", "BA_12"), dv("MAN", "BA_12")))
        two_spear(f, "VPSubplot_P22_Paired_Dyad_Comparison",
                  ("Both Inactive \u2192 Both Inactive", dv("GTK", "BA_22"), dv("MAN", "BA_22")),
                  ("Both Active \u2192 Both Active", dv("GTK", "BA_11"), dv("MAN", "BA_11")))
    
        # NodeDistance, correlation: Person 1 / Person 2 (Person1Person2_SpCorr_10July26.m)
        f = os.path.join(FIG, "NodeDistance_Correlation", "Person1_Person2")
        F.save_pub(F.plot_corr_legend(["Dyads"], [F.MATLAB_BLUE]), f, "SeriesLegend", (13, 10), layout=False)
        two_spear(f, "VPSubplot_P12_Paired_Dyad_Comparison",
                  ("Person 1 Active \u2192 Person 2 Active", dv("GTK", "P_12"), dv("MAN", "P_12")),
                  ("Person 2 Active \u2192 Person 1 Active", dv("GTK", "P_21"), dv("MAN", "P_21")))
        two_spear(f, "VPSubplot_P22_Paired_Dyad_Comparison",
                  ("Person 1 Active \u2192 Person 1 Active", dv("GTK", "P_11"), dv("MAN", "P_11")),
                  ("Person 2 Active \u2192 Person 2 Active", dv("GTK", "P_22"), dv("MAN", "P_22")))
    
    timing["6 figures"] = time.time() - t
    # count only this script's folders (Stats_Figures also holds the cycle figures)
    own = [os.path.join(FIG, d) for d in ("GraphMetrics_PairedTtest", "GraphMetrics_Correlation",
                                          "NodeDistance_PairedTtest", "NodeDistance_Correlation")]
    n_fig = 59 if OLD_FIGURES else 11
    n_png, n_pdf, stale = F.check_saved(n_fig, own)
    print("\nStep 6: figures (%.0f s)" % timing["6 figures"])
    ok &= report("%d figures, PNG + PDF" % n_fig, n_png == n_fig == n_pdf == len(F.SAVED),
                 "%d PNG, %d PDF" % (n_png, n_pdf))
    if stale:
        print("  NOTE: %d older figure files in these folders were not written by this run "
              "(left by an earlier version; safe to delete)" % len(stale))

    total = time.time() - t_all
    print("\nTIMING")
    for k in ["1 load TM graphs", "2 graph metrics", "3 node distances", "4 statistics tables", "6 figures"]:
        print("  %-22s %7.0f s" % (k, timing[k]))
    print("  %-22s %7.1f min" % ("TOTAL", total / 60))
    print("\nGRAPH METRICS + NODE DISTANCES: %s   (%.1f min)" % ("PASS" if ok else "FAIL", total / 60))
    print("Tables (aggregate): %s and %s" % (gm_dir, nd_dir))
    print("Figures and per-dyad files (participant data - do not share): %s" % OUT)


if __name__ == "__main__":
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    run_with_summary(main, os.path.join(here, "Stats_GraphNodeDist_Summary_%s.txt" % S.PY_TAG),
                     "GRAPH METRICS + NODE DISTANCES")
