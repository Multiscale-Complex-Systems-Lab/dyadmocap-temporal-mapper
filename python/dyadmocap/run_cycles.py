"""
run_cycles.py - cycles of every shape graph, the cycle tables and the cycle
figures (Cycles_WinShannon_03July.m and the four cycle statistics scripts).
Starts from the saved TM graphs (run_pipeline_to_tm.py). Every step is timed.

    Step 1  load the saved TM graphs
    Step 2  cycles of every graph (as CycleCount2pFast.m) and their metrics,
            each dyad saved as soon as it is done (see RESUMING)
    Step 3  the tables, as the four MATLAB cycle scripts write them
            (whole graph and per category: paired t-tests and Spearman
            correlations; symmetric vs asymmetric)
    Step 5  the figures of the four MATLAB cycle scripts, PNG + PDF

HOW TO RUN (from the python folder of the repository), after run_pipeline_to_tm:
    conda activate dyadmocap-tm
    python -m dyadmocap.run_cycles
or run every stage in order with  python -m dyadmocap.run_pipeline
With the study data about 2 hours (one graph took 102-129 s); one line per
dyad. Keep the computer from sleeping while it runs.

RESUMING: each dyad's cycle metrics are appended to
    <Python results folder>\\<PY_TAG>\\Stats_Cycles\\CycleMetrics_PerDyad_<PY_TAG>.csv
as soon as they are done. If the run stops (Ctrl+C, sleep, power), run the
same command again: the dyads already done are skipped. To start over, delete
that file.

OUTPUT, below <Python results folder>\\<PY_TAG>\\:
    Stats_Cycles\\          the 5 tables (aggregate) + per-dyad metrics
    Stats_Figures\\Cycles_* the figures
Per-dyad files and figures are participant-level: they stay on this machine.
WHAT IT PRINTS: PASS/FAIL lines and times only, saved to
Stats_Cycles_Summary_<PY_TAG>.txt in this folder.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import time
import numpy as np
import pandas as pd

from . import dymo_settings as S
from .dymo_report import report, run_with_summary
from .dymo_format import write_table

OUT = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
CYC_DIR = os.path.join(OUT, "Stats_Cycles")
FIG = os.path.join(OUT, "Stats_Figures")
# SUPERSEDED FIGURES. The final figure set: whole-graph comparisons in purple,
# correlations as bar plots (only the node distances as scatter plots, with
# state-pair icons), node distances in purple with icons - all drawn in
# run_later_analyses.py. The older versions of those figures (condition
# colours teal/salmon, correlation scatters, delta-rho plots) are made only if
# OLD_FIGURES = True. The TABLES are unchanged. The MATLAB scripts have the
# same switch (makeFigures).
OLD_FIGURES = False

TABLE_NAMES = ["CycleWholeGraph_Pairedttest", "CycleCategory_Pairedttest", "CycleGroupCompare",
               "WholeGraphCycle_SpearCorr", "CategoryCyclesSpearCorr", "SpearmanCorrCycle"]

# The metrics and labels of the four MATLAB cycle scripts, identical across
# the four scripts.
WHOLE_PAIRED = ["CycleCount", "CycleLenMean", "meanEntropy", "cycleDensity"]
WHOLE_CORR = ["CycleLenMean", "meanEntropy", "cycleDensity", "CycleCount"]
WHOLE_LABEL = {"CycleCount": "CycleCount", "CycleLenMean": "Cycle Mean Length",
               "meanEntropy": "mean Entropy", "cycleDensity": "Cycle Density"}
# Per category, 'Cycle Density' is cyclesPerNode = (cycles won by c) / (nodes
# carrying c), on the same scale as the whole-graph cycle density. (Cycles won
# by c / all the dyad's cycles is a SHARE, the same number as winnerProp, so it
# is not reported as a density.)
CAT_METRICS = ["winnerProp", "CycleLenMean", "meanEntropy", "cycleCategoryCounts", "cyclesPerNode"]
CAT_LABEL = {"winnerProp": "Share of cycles won", "CycleLenMean": "CycleLenMean",
             "meanEntropy": "meanEntropy", "cycleCategoryCounts": "cycleCategoryCounts",
             "cyclesPerNode": "Cycle Density"}


def add_cycles_per_node(per):
    """perCategoryCycleMetrics.m: nodesInCat and cyclesPerNode.
    The cycles won by category c are winnerProp_c x CycleCount (whole numbers);
    the nodes carrying c are counted with node_labels (findnodelabel 'mode'),
    from the saved TM graphs. NaN where the category has no node."""
    from .run_pipeline_to_tm import load_tm
    from .dymo_graph_metrics import node_labels
    per = per.copy()
    for c in range(1, 5):
        per["nodesInCat_%d" % c] = np.nan
        per["cyclesPerNode_%d" % c] = np.nan
    for group in S.GROUPS:
        tm = load_tm(group)
        for i in per.index[per.Condition == group]:
            T = tm[per.at[i, "Dyad"]]
            n_in = np.bincount(node_labels(T["members"], T["colorvar"]), minlength=5)[1:]
            for c in range(1, 5):
                won = np.round(per.at[i, "winnerProp_%d" % c] * per.at[i, "CycleCount"])
                per.at[i, "nodesInCat_%d" % c] = n_in[c - 1]
                if n_in[c - 1] > 0:
                    per.at[i, "cyclesPerNode_%d" % c] = won / n_in[c - 1]
    return per


def build_tables(per, dyads):
    """The six cycle tables in the MATLAB format, unrounded.
    Paired tables: paired t-tests; the symmetric vs asymmetric block uses
    pairedGroupDelta. Correlation tables: rho, a BCa interval (dyads
    resampled) and a verdict; no p-value."""
    from scipy import stats
    from .dymo_correlations import (spearman_with_ci, spearman_group_delta,
                                   correlation_verdict, delta_verdict)
    from .dymo_paired import paired_group_delta, group_means
    from .dymo_format import ci_verdict
    from .dymo_tables import CATEGORY_NAMES

    def col(group, name):
        g = per[per.Condition == group].set_index("Dyad")
        return g.loc[dyads, name].to_numpy(dtype=float)

    def cat(group, m):
        return np.column_stack([col(group, "%s_%d" % (m, c + 1)) for c in range(4)])

    def ttest(x, y):
        v = np.isfinite(x) & np.isfinite(y)
        if v.sum() < 2:
            return int(v.sum()), np.nan, np.nan, np.nan
        r = stats.ttest_rel(x[v], y[v])
        return int(v.sum()), float(r.statistic), int(v.sum()) - 1, float(r.pvalue)

    # 1. whole graph, paired (WholeGraphsCycles_Above3Min_03July26.m)
    rows = []
    for m in WHOLE_PAIRED:
        x, y = col("GTK", m), col("MAN", m)
        n, t, df, p = ttest(x, y)
        v = np.isfinite(x) & np.isfinite(y)
        rows.append(dict(Metric=WHOLE_LABEL[m], N_dyads=n, MeanGTK=x[v].mean(), MeanMAN=y[v].mean(),
                         MeanDiff_GTKminusMAN=x[v].mean() - y[v].mean(), t=t, df=df, p=p))
    t1 = pd.DataFrame(rows)

    # 2. per category, paired, and 3. symmetric vs asymmetric
    #    (EntroWinner_Cycle_Category_Visualization_03July26.m). The means use
    #    every finite dyad of that condition ('omitnan'), the test the pairs
    #    finite in both, as in MATLAB.
    rows2, rows3 = [], []
    for m in CAT_METRICS:
        X, Y = cat("GTK", m), cat("MAN", m)
        for c, cname in enumerate(CATEGORY_NAMES):
            n, t, df, p = ttest(X[:, c], Y[:, c])
            mg, mm = np.nanmean(X[:, c]), np.nanmean(Y[:, c])
            rows2.append(dict(Metric=CAT_LABEL[m], BehaviouralCategory=cname,
                              N_dyads=n if n >= 2 else np.nan, MeanGTK=mg, MeanMAN=mm,
                              MeanDiff_GTKminusMAN=mg - mm, t=t, df=df, p=p))
        R = paired_group_delta(group_means(X, [0, 1]), group_means(Y, [0, 1]),
                               group_means(X, [2, 3]), group_means(Y, [2, 3]))
        rows3.append(dict(Metric=CAT_LABEL[m], N=R["N"], Symmetric_MeanDiff=R["diffG1"],
                          Asymmetric_MeanDiff=R["diffG2"], Delta_MeanDiff=R["delta"],
                          CI_Lower=R["CI"][0], CI_Upper=R["CI"][1],
                          Verdict=ci_verdict(R["CI"], "Effect larger in symmetric", "Effect larger in asymmetric")))
    t2, t3 = pd.DataFrame(rows2), pd.DataFrame(rows3)

    # 4. whole graph, Spearman (SpearCorr_CycWholeGraph_17July26.m)
    rows, whole_rp = [], {}
    for m in WHOLE_CORR:
        rho, p, ci, n = spearman_with_ci(col("GTK", m), col("MAN", m))
        whole_rp[m] = (rho, p)                  # for the scatter annotation only
        rows.append(dict(Metric=WHOLE_LABEL[m], N_dyads=n, SpearmanRho=rho, CI_Lower=ci[0], CI_Upper=ci[1],
                         Verdict=correlation_verdict(ci)))
    t4 = pd.DataFrame(rows)

    # 5. per category, Spearman and 6. symmetric vs asymmetric delta-rho
    #    (EntroWinner_Cycle_Cat_SpCorr_17July.m)
    rows5, rows6, cat_rp, deltas = [], [], {}, {}
    for m in CAT_METRICS:
        X, Y = cat("GTK", m), cat("MAN", m)
        R = spearman_group_delta(X, Y, [0, 1], [2, 3])
        R["verdict"] = delta_verdict(R["CI"])
        deltas[m] = R
        rows6.append(dict(Metric=CAT_LABEL[m], N_dyads=R["nDyads"],
                          Symmetric_rho=R["rhoG1"], Symmetric_CI_Lower=R["ciG1"][0], Symmetric_CI_Upper=R["ciG1"][1],
                          Asymmetric_rho=R["rhoG2"], Asymmetric_CI_Lower=R["ciG2"][0],
                          Asymmetric_CI_Upper=R["ciG2"][1],
                          Delta_rho=R["delta"], Delta_CI_Lower=R["CI"][0], Delta_CI_Upper=R["CI"][1],
                          Verdict=R["verdict"]))
        cat_rp[m] = []
        for c, cname in enumerate(CATEGORY_NAMES):
            rho, p, ci, n = spearman_with_ci(X[:, c], Y[:, c])
            cat_rp[m].append((rho, p))
            rows5.append(dict(Metric=CAT_LABEL[m], BehaviouralCategory=cname, N_dyads=n, SpearmanRho=rho,
                              CI_Lower=ci[0], CI_Upper=ci[1], Verdict=correlation_verdict(ci)))
    tabs = [t1, t2, t3, t4, pd.DataFrame(rows5), pd.DataFrame(rows6)]
    return tabs, dict(whole_rp=whole_rp, cat_rp=cat_rp, deltas=deltas)


def cycles_all(per_dyad_file):
    """Cycle metrics of every dyad in both conditions, saved one dyad at a time.
    Returns the per-dyad table and the counts of failed sanity checks."""
    from .run_pipeline_to_tm import load_tm
    from .dymo_graph_metrics import node_labels
    from .dymo_cycles import find_cycles, cycle_data, whole_cycle_metrics, category_cycle_metrics
    from .dymo_tables import PERCAT

    done = set()
    if os.path.isfile(per_dyad_file):
        prev = pd.read_csv(per_dyad_file)
        done = set(zip(prev.Condition, prev.Dyad))
        print("Resuming: %d of the 60 dyad-conditions already done, skipped." % len(done))

    fails = dict(simple=0, loop=0, entropy=0, winner=0)
    graph_times = []
    for group in S.GROUPS:
        t = time.time()
        tm = load_tm(group)
        print("\n[%s] TM graphs loaded (%.0f s)" % (group, time.time() - t))
        dyads = sorted(tm)
        for i, d in enumerate(dyads, start=1):
            if (group, d) in done:
                continue
            t0 = time.time()
            T = tm[d]
            g = T["g_simp"]
            labels = node_labels(T["members"], T["colorvar"])
            cyc = find_cycles(g)
            cd = cycle_data(cyc, labels)
            W = whole_cycle_metrics(cd, g.number_of_nodes())
            C = category_cycle_metrics(cd)

            # sanity checks of every cycle list
            edges = set(g.edges())
            if not (len(cyc) > 0 and len(set(cyc)) == len(cyc)
                    and all(len(set(c)) == len(c) and c[0] == min(c) for c in cyc)):
                fails["simple"] += 1
            if not all((c[k], c[(k + 1) % len(c)]) in edges for c in cyc for k in range(len(c))):
                fails["loop"] += 1
            if not np.all((cd["entropy"] >= -1e-12) & (cd["entropy"] <= np.log(4) + 1e-12)):
                fails["entropy"] += 1
            if abs(np.nansum(C["winnerProp"]) - 1) > 1e-12:
                fails["winner"] += 1

            row = dict(Condition=group, Dyad=d, **W)
            for metric in PERCAT:
                for c in range(4):
                    row["%s_%d" % (metric, c + 1)] = C[metric][c]
            pd.DataFrame([row]).to_csv(per_dyad_file, mode="a", index=False,
                                       header=not os.path.isfile(per_dyad_file))
            graph_times.append(time.time() - t0)
            print("  %s: %d / %d dyads done (this one %.0f s)" % (group, i, len(dyads), graph_times[-1]),
                  flush=True)
    return pd.read_csv(per_dyad_file), fails, graph_times


def main():
    from .dymo_tables import CATEGORY_NAMES
    from . import dymo_stats_figures as F
    import matplotlib.pyplot as plt

    F.SAVED.clear()   # count only this stage's figures (stages can share one process)
    t_all = time.time()
    timing = {}
    print("Cycles, statistics and figures (run %s)\n" % S.PY_TAG)
    os.makedirs(CYC_DIR, exist_ok=True)
    per_dyad_file = os.path.join(CYC_DIR, "CycleMetrics_PerDyad_%s.csv" % S.PY_TAG)

    # ---- steps 1 and 2: cycles of every graph ----
    t = time.time()
    per, fails, graph_times = cycles_all(per_dyad_file)
    timing["1+2 load + cycles"] = time.time() - t
    dyads = sorted(set(per[per.Condition == "GTK"].Dyad) & set(per[per.Condition == "MAN"].Dyad))
    print("\nCycles (graphs done in THIS run: %d):" % len(graph_times))
    ok = report("dyads in both conditions", len(dyads) > 2 and (S.EXPECTED_DYADS is None or len(dyads) == S.EXPECTED_DYADS),
                "%d" % len(dyads))
    ok &= report("cycles simple and unique", fails["simple"] == 0, "%d graphs fail" % fails["simple"])
    ok &= report("each cycle a loop in graph", fails["loop"] == 0, "%d graphs fail" % fails["loop"])
    ok &= report("entropy in [0, ln 4]", fails["entropy"] == 0, "%d graphs fail" % fails["entropy"])
    ok &= report("winner shares add up to 1", fails["winner"] == 0, "%d graphs fail" % fails["winner"])

    # ---- step 3: the six tables (the MATLAB format) ----
    t = time.time()
    per = add_cycles_per_node(per)                # 'Cycle Density' per category
    tabs, extra = build_tables(per, dyads)
    t1, t2, t3, t4, t5, t6 = tabs
    for tab, n in zip(tabs, TABLE_NAMES):
        write_table(tab, os.path.join(CYC_DIR, "%s_%s.csv" % (n, S.PY_TAG)))   # rounded, as DYMO_roundTable
    timing["3 statistics tables"] = time.time() - t
    print("\nStep 3: %d tables written (%.0f s)" % (len(tabs), timing["3 statistics tables"]))


    # ---- step 5: the figures of the four MATLAB cycle scripts ----
    t = time.time()

    def col(group, name):
        g = per[per.Condition == group].set_index("Dyad")
        return g.loc[dyads, name].to_numpy(dtype=float)

    def cat_arrays(metric):
        X = np.column_stack([col("GTK", "%s_%d" % (metric, c + 1)) for c in range(4)])
        Y = np.column_stack([col("MAN", "%s_%d" % (metric, c + 1)) for c in range(4)])
        return X, Y

    if OLD_FIGURES:   # superseded (see SUPERSEDED FIGURES at the top)
        # WholeGraphsCycles_Above3Min_03July26.m -> plotCycleMetric
        # (no y-axis labels - the metric is the title - and no
        #  ": Casual Chat vs Conflict" in the titles)
        f = os.path.join(FIG, "Cycles_PairedTtest", "WholeGraph")
        F.save_pub(F.plot_legend_figure(["Casual Chat", "Conflict"], F.COND_COLORS, "Condition"),
                   f, "ConditionLegend", (13, 10), layout=False)
        for metric, p in zip(WHOLE_PAIRED, t1.p):
            F.save_pub(F.plot_whole_paired_bar(col("GTK", metric), col("MAN", metric), p, WHOLE_LABEL[metric]),
                       f, "WGCycle_%s" % metric, (13, 16))
    
    # EntroWinner_Cycle_Category_Visualization_03July26.m -> plotMetric
    f = os.path.join(FIG, "Cycles_PairedTtest", "PerCategory")
    F.save_pub(F.plot_category_legend(CATEGORY_NAMES, ["Casual Chat", "Conflict"]),
               f, "CategoryLegend", (13, 10), layout=False)
    cat_titles = {"winnerProp": "Cycle Winner Proportion", "CycleLenMean": "Cycle Mean Length",
                  "meanEntropy": "mean Entropy", "cyclesPerNode": "Cycle Density",
                  "cycleCategoryCounts": "cycle Category Counts"}
    for metric in CAT_METRICS:
        X, Y = cat_arrays(metric)
        F.save_pub(F.plot_category_paired_bars(X, Y, CATEGORY_NAMES, cat_titles[metric], "Behavioural Categories"),
                   f, "CatCycle_%s" % metric)

    if OLD_FIGURES:   # superseded (see SUPERSEDED FIGURES at the top)
        # SpearCorr_CycWholeGraph_17July26.m -> purple scatters
        f = os.path.join(FIG, "Cycles_Correlation", "WholeGraph_Scatter")
        F.save_pub(F.plot_corr_legend(["Dyads"], [F.PURPLE]), f, "SeriesLegend", (13, 10), layout=False)
        for metric in WHOLE_CORR:
            x, y = col("GTK", metric), col("MAN", metric)
            if (np.isfinite(x) & np.isfinite(y)).sum() >= 3:
                rho, p = extra["whole_rp"][metric]
                F.save_pub(F.plot_whole_scatter(x, y, rho, p, "Correlation Analysis: %s" % WHOLE_LABEL[metric], F.PURPLE),
                           f, metric, (13, 16))
    
        # EntroWinner_Cycle_Cat_SpCorr_17July.m -> delta-rho and four-panel scatters
        f = os.path.join(FIG, "Cycles_Correlation", "PerCategory_DeltaRho")
        for metric in CAT_METRICS:
            F.save_pub(F.plot_delta_rho(extra["deltas"][metric], CAT_LABEL[metric]), f, metric)   # default size, as in MATLAB
        f = os.path.join(FIG, "Cycles_Correlation", "PerCategory_Scatter")
        F.save_pub(F.plot_corr_legend(CATEGORY_NAMES, F.CAT_CMAP, "", "category"), f, "CategoryLegend", (13, 10),
                   layout=False)
        for metric in CAT_METRICS:
            X, Y = cat_arrays(metric)
            rr = extra["cat_rp"][metric]
            F.save_pub(F.plot_category_scatter(X, Y, [r[0] for r in rr], [r[1] for r in rr],
                                               CATEGORY_NAMES, CAT_LABEL[metric]), f, metric)
    plt.close("all")

    timing["5 figures"] = time.time() - t
    own = [os.path.join(FIG, "Cycles_PairedTtest"), os.path.join(FIG, "Cycles_Correlation")]
    n_fig = 27 if OLD_FIGURES else 6
    n_png, n_pdf, stale = F.check_saved(n_fig, own)
    print("\nStep 5: figures (%.0f s)" % timing["5 figures"])
    ok &= report("%d figures, PNG + PDF" % n_fig, n_png == n_fig == n_pdf == len(F.SAVED),
                 "%d PNG, %d PDF" % (n_png, n_pdf))
    if stale:
        # e.g. figure files of an earlier run with other names
        print("  NOTE: %d older figure files in these folders were not written by this run "
              "(left by an earlier version; safe to delete)" % len(stale))

    total = time.time() - t_all
    print("\nTIMING")
    for k in ["1+2 load + cycles", "3 statistics tables", "5 figures"]:
        print("  %-22s %7.0f s" % (k, timing[k]))
    if graph_times:
        print("  one graph (this run): mean %.0f s, fastest %.0f s, slowest %.0f s"
              % (np.mean(graph_times), np.min(graph_times), np.max(graph_times)))
    print("  %-22s %7.1f min" % ("TOTAL", total / 60))
    print("\nCYCLES: %s   (%.1f min)" % ("PASS" if ok else "FAIL - stop here", total / 60))
    print("Tables (aggregate): %s" % CYC_DIR)
    print("Figures and per-dyad metrics (participant data - do not share): %s" % OUT)


if __name__ == "__main__":
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    run_with_summary(main, os.path.join(here, "Stats_Cycles_Summary_%s.txt" % S.PY_TAG), "CYCLES")
