"""
run_subgraph_highlight.py - the category highlighting figures of
GTK_Above3Min_SubGraphs_20July.m and MAN_Above3Min_SubGraphs_20July.m,
part (B): for every dyad, the whole temporal mapper graph drawn four times,
each time with ONE behavioural category in its colour and the other three in
grey (0.75, 0.75, 0.75). Starts from the saved TM graphs (run_pipeline_to_tm.py).

Part (A) of those scripts (each category lifted out into a graph of its own)
is not in the Python version: it is off in MATLAB too (runSubgraphs = false)
and nothing downstream uses it.

Same titles, file names and folders as MATLAB:
    <Python results folder>\\<PY_TAG>\\Subgraph_Figures\\Subgraphs_GTK\\02_CategoryHighlighting\\<Category>\\
        GTK_Dyad_<d>_Highlight_<Category>.png / .pdf        (and the same for MAN)
4 figures per dyad per condition (8 per dyad).

ONE DELIBERATE DIFFERENCE: MATLAB computes a new force layout for each of the
four figures, so the same graph appears in four different arrangements. Here
the four figures of a dyad share one layout (seed 1), so the highlighted
category can be compared across them. The graph, colours and node sizes are
the same as MATLAB's.

HOW TO RUN (from the python folder of the repository), after run_pipeline_to_tm:
    conda activate dyadmocap-tm
    python -m dyadmocap.run_subgraph_highlight
or run every stage in order with  python -m dyadmocap.run_pipeline
Expected about 20-40 minutes for the study data. A line is printed every 5 dyads.
The figures show participant data: they stay on this machine.
WHAT IT PRINTS: PASS/FAIL and times only, saved to
Subgraph_Highlight_Summary_<PY_TAG>.txt in this folder.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import time
import numpy as np

from . import dymo_settings as S
from .dymo_report import report, run_with_summary

FIG = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG, "Subgraph_Figures")
GREY = [0.75, 0.75, 0.75]


def main():
    from .run_pipeline_to_tm import load_tm
    from . import dymo_figures as F

    t_all = time.time()
    print("Category highlighting figures (subgraph scripts, part B)\n")
    ok = True
    t_layout = t_draw = 0.0
    for group in S.GROUPS:
        t = time.time()
        tm = load_tm(group)
        print("[%s] TM graphs loaded (%.0f s)" % (group, time.time() - t))
        dyads = sorted(tm)
        short = 0
        t_group = time.time()
        for i, d in enumerate(dyads, start=1):
            T = tm[d]
            dnum = d                                       # the dyad's name
            t = time.time()
            pos = F.graph_layout(T["g_simp"])              # one layout for the dyad's 4 figures
            t_layout += time.time() - t

            t = time.time()
            for c, cname in enumerate(F.CAT_NAMES):
                cmap = np.array([GREY] * 4)
                cmap[c] = F.CAT_CMAP[c]                    # this category in colour, others grey
                tag = cname.replace(" ", "_")
                folder = os.path.join(FIG, "Subgraphs_%s" % group, "02_CategoryHighlighting", tag)
                F.four_color_graph(T["g_simp"], T["colorvar"], T["members"],
                                   "%s %s\nHighlighted: %s" % (group, dnum, cname),
                                   folder, "%s_%s_Highlight_%s" % (group, dnum, tag),
                                   cmap=cmap, pos=pos)
            t_draw += time.time() - t

            base = os.path.join(FIG, "Subgraphs_%s" % group, "02_CategoryHighlighting")
            n = sum(os.path.isfile(os.path.join(base, cn.replace(" ", "_"),
                                                "%s_%s_Highlight_%s.%s" % (group, dnum, cn.replace(" ", "_"), ext)))
                    for cn in F.CAT_NAMES for ext in ("png", "pdf"))
            short += int(n != 8)
            if i % 5 == 0 or i == len(dyads):
                print("  %s: %d / %d dyads done (%.0f s)" % (group, i, len(dyads), time.time() - t_group),
                      flush=True)
        ok &= report("%s: 4 figures per dyad" % group, short == 0,
                     "%d dyads, %d short" % (len(dyads), short))

    total = time.time() - t_all
    print("\nTIMING")
    print("  %-22s %7.0f s" % ("layouts", t_layout))
    print("  %-22s %7.0f s" % ("drawing + saving", t_draw))
    print("  %-22s %7.1f min" % ("TOTAL", total / 60))
    print("\nCATEGORY HIGHLIGHTING FIGURES: %s   (%.1f min)" % ("PASS" if ok else "FAIL", total / 60))
    print("Figures (participant data - do not share): %s" % FIG)


if __name__ == "__main__":
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    run_with_summary(main, os.path.join(here, "Subgraph_Highlight_Summary_%s.txt" % S.PY_TAG),
                     "CATEGORY HIGHLIGHTING FIGURES")
