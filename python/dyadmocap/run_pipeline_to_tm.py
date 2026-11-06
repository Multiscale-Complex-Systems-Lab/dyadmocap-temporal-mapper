"""
run_pipeline_to_tm.py - run the Python pipeline on ALL included dyads, both
conditions, from loading up to and including the temporal mapper (TM) graph,
and time every stage.

    Stage 1  loading, trimming, inclusion rule, uniform 180 s window
    Stage 2  11 joint angles per person, velocity
    Stage 3  median normalisation, 4 behavioural categories
    Stage 4  temporal mapper graph (tmapper-py, k = 5, dmap = 3, texclude = 3)
    Figures  the MATLAB temporal-mapper figure set for EVERY dyad, 22 per dyad
             per condition, PNG (300 dpi) + PDF:
             skeleton frame 1, 6 angle-vector skeletons, 11 angle time series +
             overview, distance matrix, category bars, four-colour graph, in
             <Python results folder>\\<PY_TAG>\\TM_Figures\\GTK and ...\\MAN
             (participant data: they stay on this machine). Turn off with
             MAKE_FIGURES = False below.

The later steps (graph metrics, node distances, cycles, statistics) are NOT run
here. They start from the TM output this script saves, so the graphs are not
rebuilt each time:
    <Python results folder>\\<PY_TAG>\\TM_Graphs\\TM_GTK_<PY_TAG>.pkl  (and MAN)
Each file holds, per dyad: colorvar (category of every sample), g_simp (the
shape graph), members (samples in each node), nodesize, and the sample-level
graph as an edge list (for the node distances). Read it back with load_tm().
These are participant-level: they stay on this machine and are not shared.

Each graph is also checked against the rules it must obey.

HOW TO RUN (from the python folder of the repository):
    conda activate dyadmocap-tm
    python -m dyadmocap.run_pipeline_to_tm
or run every stage in order with  python -m dyadmocap.run_pipeline
With the simulated data about 15-20 min; a study of a few dozen dyads takes
about 1-1.5 hours with figures.
A line is printed every 5 dyads.

WHAT IT PRINTS: PASS/FAIL counts and times only - no dyad ID, no values.
Saved to TM_Pipeline_Summary_<PY_TAG>.txt in this folder.

The dyads come from the dataset index (dymo_settings.DATA_INDEX).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import pickle
import time
import numpy as np
import networkx as nx

from . import dymo_settings as S
from .dymo_report import report, run_with_summary

N_ANG = 11
TM_DIR = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG, "TM_Graphs")
FIG_DIR = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG, "TM_Figures")

# Figures take most of the run time (about 1 min per dyad per condition).
# Set to False to build and save only the graphs (about 10-15 min).
MAKE_FIGURES = True


def tm_file(group):
    return os.path.join(TM_DIR, "TM_%s_%s.pkl" % (group, S.PY_TAG))


def load_tm(group):
    """Read the saved TM output of one condition: dict dyad -> dict with
    colorvar, g_simp, members, nodesize and g (sample-level DiGraph, rebuilt
    from the edge list with nodes 0..N-1)."""
    with open(tm_file(group), "rb") as f:
        tm = pickle.load(f)
    for d in tm.values():
        g = nx.DiGraph()
        g.add_nodes_from(range(d["n_samples"]))
        g.add_edges_from(map(tuple, d.pop("g_edges")))
        d["g"] = g
    return tm


def main():
    from .dymo_loading import find_times, load_group
    from .dymo_angles import joint_angles, velocity
    from .dymo_categories import normalize_median, categorize
    from .dymo_graph import build_graph_with_samples, graph_input_velocity
    from . import dymo_figures as F

    t_all = time.time()
    print("Pipeline up to the temporal mapper, all included dyads")
    print("k = %d, dmap = %d, texclude = %d samples\n" % (S.K, S.DMAP, S.TEXCLUDE))
    os.makedirs(TM_DIR, exist_ok=True)

    t = time.time()
    times = find_times()
    t_find = time.time() - t
    print("Finding the trim times: %.0f s" % t_find)

    timing = {}          # stage -> total seconds over both conditions
    per_graph = []       # seconds per graph (stage 4)
    all_ok = True

    for group in S.GROUPS:
        print("\n========== %s ==========" % group)

        # ---- stage 1 ----
        t = time.time()
        data, _, fs, n_keep = load_group(group, times)
        timing["1 loading"] = timing.get("1 loading", 0) + time.time() - t

        n = len(data)
        fails = dict(window=0, angles=0, velocity=0, categories=0, graph=0, figures=0)
        tm = {}
        t_group = time.time()

        for i, (dyad, pair) in enumerate(sorted(data.items()), start=1):
            if not all(x.shape == (n_keep, 128) and not np.isnan(x).any() for x in pair):
                fails["window"] += 1

            # ---- stage 2 ----
            t = time.time()
            ang1, _ = joint_angles(pair[0])
            ang2, _ = joint_angles(pair[1])
            v = velocity(ang1, ang2, fs)
            timing["2 angles + velocity"] = timing.get("2 angles + velocity", 0) + time.time() - t
            if not all(a.shape[1] == N_ANG and np.all((a >= 0) & (a <= 180)) for a in (ang1, ang2)):
                fails["angles"] += 1
            if not (v.shape == (n_keep - 1, 2 * N_ANG) and np.all(np.isfinite(v))):
                fails["velocity"] += 1

            # ---- stage 3 ----
            t = time.time()
            r1, _ = normalize_median(v[:, :N_ANG])
            r2, _ = normalize_median(v[:, N_ANG:])
            cv = categorize(r1, r2)["colorvar"]
            timing["3 categories"] = timing.get("3 categories", 0) + time.time() - t
            N = cv.size
            c = [int((cv == k).sum()) for k in (1, 2, 3, 4)]
            if not (c[1] + c[2] == N // 2 and c[1] + c[3] == N // 2 and sum(c) == N):
                fails["categories"] += 1

            # ---- stage 4 ----
            t = time.time()
            g_simp, members, nodesize, g = build_graph_with_samples(v, S.K, S.DMAP, S.TEXCLUDE)
            dt = time.time() - t
            timing["4 TM graph"] = timing.get("4 TM graph", 0) + dt
            per_graph.append(dt)
            samples = np.sort(np.concatenate([np.asarray(m) for m in members]))
            if not (np.array_equal(samples, np.arange(N)) and int(np.sum(nodesize)) == N):
                fails["graph"] += 1

            # ---- figures (the MATLAB temporal-mapper figure set, 22 per dyad) ----
            if MAKE_FIGURES:
                t = time.time()
                fig_dir = os.path.join(FIG_DIR, group)
                tag = "%s %s" % (group, dyad)
                pre = "%s_%s" % (group, dyad)
                F.skeleton_frame1(pair, tag + " Skeleton View - Frame 1",
                                  os.path.join(fig_dir, "02_Skeletons_Frame1"), pre + "_Skeleton_Plot")
                F.angle_vector_skeletons(pair, tag, os.path.join(fig_dir, "04_AngleVectorSkeletons"), pre)
                F.angle_time_series([ang1, ang2], [pair[0][:, 0], pair[1][:, 0]], tag,
                                    os.path.join(fig_dir, "05_AngleTimeSeries"), pre)
                t_vel = np.arange(v.shape[0]) / fs + 1 / (2 * fs)       # timeVelocity, as in MATLAB
                F.distance_matrix(graph_input_velocity(v)[0], t_vel, tag + " Distance Matrix ",
                                  os.path.join(fig_dir, "06_DistanceMatrices"), pre + "_DistanceMatrix")
                F.category_bars(cv, tag + " Time Point Distribution",
                                os.path.join(fig_dir, "07_TimePointCategoryBars"), pre + "_TimePointCategoryBars")
                F.four_color_graph(g_simp, cv, members,
                                   "%s  k=%d, dmap=%d, texclude=%d" % (tag, S.K, S.DMAP, S.TEXCLUDE),
                                   os.path.join(fig_dir, "08_FourColorGraphs"), pre + "_FourColorGraph")
                timing["5 figures"] = timing.get("5 figures", 0) + time.time() - t
                n_png = sum(f.startswith(pre) and f.endswith(".png")
                            for _, _, fs_ in os.walk(fig_dir) for f in fs_)
                if n_png != 22:
                    fails["figures"] += 1

            tm[dyad] = dict(colorvar=cv, g_simp=g_simp, members=members,
                            nodesize=np.asarray(nodesize), n_samples=g.number_of_nodes(),
                            g_edges=np.array(list(g.edges()), dtype=np.int32))

            if i % 5 == 0 or i == n:
                print("  %s: %d / %d dyads done (%.0f s)" % (group, i, n, time.time() - t_group),
                      flush=True)

        # ---- save the TM output of this condition ----
        t = time.time()
        with open(tm_file(group), "wb") as f:
            pickle.dump(tm, f, protocol=pickle.HIGHEST_PROTOCOL)
        timing["saving"] = timing.get("saving", 0) + time.time() - t

        print("\n Checks, %s (%d dyads):" % (group, n))
        all_ok &= report("dyads included", n > 2 and (S.EXPECTED_DYADS is None or n == S.EXPECTED_DYADS),
                         "%d" % n)
        all_ok &= report("window 9,000 x 128, no NaN", fails["window"] == 0, "%d fail" % fails["window"])
        all_ok &= report("angles 0-180 deg", fails["angles"] == 0, "%d fail" % fails["angles"])
        all_ok &= report("velocity (N-1) x 22, finite", fails["velocity"] == 0, "%d fail" % fails["velocity"])
        all_ok &= report("categories: Active floor(N/2)", fails["categories"] == 0, "%d fail" % fails["categories"])
        all_ok &= report("TM: every sample in 1 node", fails["graph"] == 0, "%d fail" % fails["graph"])
        if MAKE_FIGURES:
            all_ok &= report("22 figures per dyad", fails["figures"] == 0, "%d dyads short" % fails["figures"])
        all_ok &= report("TM output saved", os.path.isfile(tm_file(group)),
                         "%.0f MB" % (os.path.getsize(tm_file(group)) / 1e6))

    total = time.time() - t_all
    print("\nTIMING (both conditions, %d graphs)" % len(per_graph))
    print("  %-22s %7.0f s" % ("0 trim times", t_find))
    for stage in ["1 loading", "2 angles + velocity", "3 categories", "4 TM graph",
                  "5 figures", "saving"]:
        print("  %-22s %7.0f s" % (stage, timing.get(stage, 0)))
    print("  %-22s %7.1f min" % ("TOTAL", total / 60))
    if per_graph:
        print("  one TM graph: mean %.1f s, fastest %.1f s, slowest %.1f s"
              % (np.mean(per_graph), np.min(per_graph), np.max(per_graph)))

    print("\nPIPELINE UP TO TM: %s   (%.1f min)" % ("PASS" if all_ok else "FAIL", total / 60))
    print("TM output (participant data - do not share): %s" % TM_DIR)
    if MAKE_FIGURES:
        print("Figures   (participant data - do not share): %s" % FIG_DIR)


if __name__ == "__main__":
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    run_with_summary(main, os.path.join(here, "TM_Pipeline_Summary_%s.txt" % S.PY_TAG),
                     "PIPELINE UP TO TM")
