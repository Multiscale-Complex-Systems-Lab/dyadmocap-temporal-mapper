"""dyadmocap - Temporal Mapper analysis of dyadic motion capture (DYMO).

The analysis pipeline of the study (Patience Akatuhwera, Multiscale Complex
Systems Lab, Michigan State University), in Python. It gives the same results
as the MATLAB version (matlab/); the stage modules run in the order of the
MATLAB DYMO_runAll.m:

  run_pipeline_to_tm      GTK_TM_26June26 / MAN_TM_26June26
                          loading and inclusion, joint angles, velocity,
                          behavioural categories, Temporal Mapper graphs,
                          and the per-dyad TM figures
  run_subgraph_highlight  GTK/MAN_Above3Min_SubGraphs_20July (part B):
                          category highlighting figures
  run_cycles              Cycles_WinShannon_03July and the four cycle
                          statistics scripts (paired t-tests, correlations)
  run_stats_graph_nodedist
                          node distance (paired, correlation), graph metrics
                          (paired, correlation, whole and per category), and
                          hubness (mean path distance, roles)
  run_later_analyses      MATLAB stages 21-33:
                          correlation bars (whole graph and pairwise by
                          category), purple paired bars, node size
                          distribution, node distances with state-pair icons

Run every stage in order:  python -m dyadmocap.run_pipeline

Building blocks: dymo_loading, dymo_angles, dymo_categories, dymo_graph,
dymo_graph_metrics, dymo_node_distance, dymo_cycles, dymo_hubness,
dymo_paired, dymo_correlations, dymo_format, dymo_tables, dymo_figures,
dymo_stats_figures, dymo_later_figures.
All settings: dymo_settings.

Temporal Mapper is an external dependency (tmapper-py).
"""
