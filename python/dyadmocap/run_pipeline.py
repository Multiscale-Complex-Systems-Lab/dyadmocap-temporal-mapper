"""
run_pipeline.py - the whole pipeline, every stage in the order of the MATLAB
DYMO_runAll.m.

    1  run_pipeline_to_tm        loading, inclusion, angles, velocity, categories,
                                 Temporal Mapper graphs, per-dyad TM figures
    2  run_subgraph_highlight    category highlighting figures
    3  run_cycles                cycles (winner, Shannon entropy), paired t-tests,
                                 correlations, and their figures
    4  run_stats_graph_nodedist  node distances, graph metrics (whole and per
                                 category), hubness: tables and figures
    5  run_later_analyses        purple and icon figures, correlation bars,
                                 pairwise tests, node size distribution

HOW TO RUN (from the python folder of the repository):
    python -m dyadmocap.run_pipeline              # every stage
    python -m dyadmocap.run_pipeline 3            # from stage 3 on
Each stage writes its own summary file in the results folder and stops the
run if it fails. With the simulated data the whole run takes about 30-60 min
on a laptop (the Temporal Mapper stage takes most of it).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""
import importlib
import os
import sys
import time

from . import dymo_settings as S
from .dymo_report import run_with_summary

STAGES = [
    ("run_pipeline_to_tm", "TM_Pipeline_Summary", "PIPELINE UP TO TM"),
    ("run_subgraph_highlight", "Subgraph_Highlight_Summary", "CATEGORY HIGHLIGHTING FIGURES"),
    ("run_cycles", "Stats_Cycles_Summary", "CYCLES"),
    ("run_stats_graph_nodedist", "Stats_GraphNodeDist_Summary", "GRAPH METRICS + NODE DISTANCES"),
    ("run_later_analyses", "LaterAnalyses_Summary", "LATER ANALYSES"),
]


def main(first=1):
    here = os.path.join(S.PY_RESULTS_DIR, S.PY_TAG)
    os.makedirs(here, exist_ok=True)
    t_all = time.time()
    for k, (module, summary, name) in enumerate(STAGES, start=1):
        if k < first:
            continue
        print("\n" + "#" * 70 + "\n#### STAGE %d of %d: %s\n" % (k, len(STAGES), module) + "#" * 70)
        mod = importlib.import_module("." + module, __package__)
        path = os.path.join(here, "%s_%s.txt" % (summary, S.PY_TAG))
        t = time.time()
        run_with_summary(mod.main, path, name)
        with open(path) as f:
            text = f.read()
        if "STOPPED WITH AN ERROR" in text or ": FAIL" in text:
            print("\nStage %d (%s) did not pass; the run stops here. See %s" % (k, module, path))
            return 1
        print("Stage %d done in %.1f min" % (k, (time.time() - t) / 60))
    print("\nALL STAGES DONE in %.1f min. Results: %s" % ((time.time() - t_all) / 60, here))
    return 0


if __name__ == "__main__":
    sys.exit(main(int(sys.argv[1]) if len(sys.argv) > 1 else 1))
