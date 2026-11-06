"""
dymo_graph_metrics.py - stage 5a of the Python pipeline: graph metrics and
their paired t-tests (GTK vs MAN).

Python counterpart of
    tmapper2 findnodelabel.m ('mode')        -> node_labels()
    Functions/STATS/graphStatsWhole.m        -> whole_graph_metrics()
    Functions/STATS/graphStatsByCategory.m   -> category_metrics()
    GTK_MAN_WholeStats_Pairedttest_8July26.m -> paired_table()  (whole graph)
    GTK_MAN_Subgraphstats_Pairedttest_8July26.m -> paired_table() (per category)

TWO RULES REPRODUCED DELIBERATELY (they are discrete choices, not rounding):
  * A node's label is the MODE of its samples' categories; on a tie MATLAB's
    mode returns the SMALLEST category number. np.bincount(...).argmax() does
    the same (it returns the first maximum).
  * A category with fewer than 2 nodes in a dyad gives NaN, never 0, and the
    t-test drops that dyad (pairwise deletion), exactly as MATLAB does.

The reported metric list is kept as a setting (REPORTED_METRICS below).
Every metric is computed either way.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
import networkx as nx
from scipy import stats

CATEGORY_NAMES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]

ALL_METRICS = ["numNodes", "numEdges", "density", "meanInDeg", "meanOutDeg", "nodesizes",
               "numComponents", "largestComponent", "largestFrac",
               "Embed_numNodes", "Embed_numEdges", "Embed_density", "Embed_meanInDeg",
               "Embed_meanOutDeg", "Embed_nodesizes"]

# The reported set, in the MATLAB table's row order, with the MATLAB labels.
# For the whole graph the Embed_* metrics equal the plain ones; they are
# reported to show that the embedded and the induced metrics agree.
REPORTED_METRICS = ["numNodes", "density", "nodesizes", "numComponents", "largestFrac",
                    "Embed_numNodes", "Embed_density", "Embed_nodesizes"]
LABELS_WHOLE = ["Number of Nodes", "Edge Density", "Node size", "number of Connected Components",
                "Dominance of the main Cluster", "Embedded Number of Nodes",
                "Embedded Edge Density", "Embedded node sizes"]
# the per-category script spells the last label with capitals
LABELS_CATEGORY = LABELS_WHOLE[:-1] + ["Embedded Node Sizes"]


# ---------------------------------------------------------------------------
# findnodelabel.m, 'mode'
# ---------------------------------------------------------------------------
def node_labels(members, colorvar):
    """Category (1..4) of every node: the mode of its samples, ties -> smallest."""
    return np.array([np.bincount(colorvar[m], minlength=5)[1:].argmax() + 1
                     for m in members])


def _weak_component_sizes(g):
    return [len(c) for c in nx.weakly_connected_components(g)]


# ---------------------------------------------------------------------------
# graphStatsWhole.m
# ---------------------------------------------------------------------------
def whole_graph_metrics(g_simp, nodesize):
    """The 15 whole-graph metrics of one dyad (dict)."""
    S = {m: np.nan for m in ALL_METRICS}
    nn = g_simp.number_of_nodes()
    ne = g_simp.number_of_edges()
    indeg = np.array([d for _, d in g_simp.in_degree()])
    outdeg = np.array([d for _, d in g_simp.out_degree()])

    S["numNodes"] = nn
    S["numEdges"] = ne
    S["density"] = ne / (nn * (nn - 1)) if nn > 1 else 0.0
    S["meanInDeg"] = indeg.mean()
    S["meanOutDeg"] = outdeg.mean()
    S["nodesizes"] = np.mean(nodesize)
    csize = _weak_component_sizes(g_simp)
    S["numComponents"] = len(csize)
    S["largestComponent"] = max(csize)
    if nn > 0:
        S["largestFrac"] = max(csize) / nn
    if nn >= 2:                                   # embedding = the whole graph
        S["Embed_numNodes"] = nn
        S["Embed_numEdges"] = ne                  # nnz(adjacency(g)); no self-loops
        S["Embed_density"] = ne / (nn * (nn - 1))
        S["Embed_meanInDeg"] = indeg.mean()
        S["Embed_meanOutDeg"] = outdeg.mean()
        S["Embed_nodesizes"] = np.mean(nodesize)
    return S


# ---------------------------------------------------------------------------
# graphStatsByCategory.m
# ---------------------------------------------------------------------------
def category_metrics(g_simp, members, nodesize, colorvar, n_categories=4):
    """The 15 metrics per category: dict metric -> array of 4 (NaN if < 2 nodes)."""
    S = {m: np.full(n_categories, np.nan) for m in ALL_METRICS}
    labels = node_labels(members, colorvar)
    nodes = np.array(list(g_simp.nodes()))       # 0..K-1, same order as members
    indeg_g = dict(g_simp.in_degree())
    outdeg_g = dict(g_simp.out_degree())
    nsz = np.asarray(nodesize, dtype=float)

    for c in range(1, n_categories + 1):
        idx = nodes[labels == c]
        if idx.size < 2:
            continue                              # absent or 1 node -> NaN
        j = c - 1
        gs = g_simp.subgraph(idx)                 # induced subgraph
        nn, ne = gs.number_of_nodes(), gs.number_of_edges()
        S["numNodes"][j] = nn
        S["numEdges"][j] = ne
        S["density"][j] = ne / (nn * (nn - 1))
        S["meanInDeg"][j] = np.mean([d for _, d in gs.in_degree()])
        S["meanOutDeg"][j] = np.mean([d for _, d in gs.out_degree()])
        S["nodesizes"][j] = nsz[idx].mean()
        csize = _weak_component_sizes(gs)
        S["numComponents"][j] = len(csize)
        S["largestComponent"][j] = max(csize)
        S["largestFrac"][j] = max(csize) / nn
        # embedded in the whole graph
        S["Embed_numNodes"][j] = nn
        S["Embed_numEdges"][j] = ne               # nnz(A(idx,idx)) = edges of the induced subgraph
        S["Embed_density"][j] = ne / (nn * (nn - 1))
        S["Embed_meanInDeg"][j] = np.mean([indeg_g[i] for i in idx])     # degree in the WHOLE graph
        S["Embed_meanOutDeg"][j] = np.mean([outdeg_g[i] for i in idx])
        S["Embed_nodesizes"][j] = nsz[idx].mean()
    return S


# ---------------------------------------------------------------------------
# The paired t-test rows of the two MATLAB tables
# ---------------------------------------------------------------------------
def paired_row(x_gtk, x_man):
    """N, means, SEMs (SD with N-1, /sqrt(N)) and paired t-test p, with
    pairwise deletion of non-finite values - as the MATLAB scripts do."""
    x_gtk = np.asarray(x_gtk, dtype=float)
    x_man = np.asarray(x_man, dtype=float)
    valid = np.isfinite(x_gtk) & np.isfinite(x_man)
    a, b = x_gtk[valid], x_man[valid]
    n = a.size
    p = stats.ttest_rel(a, b).pvalue if n > 1 else np.nan
    def sem(x):
        # MATLAB: std of one value is 0, of no values NaN
        if n == 0:
            return np.nan
        return (np.std(x, ddof=1) if n > 1 else 0.0) / np.sqrt(n)
    return dict(N=n,
                GTK_Mean=a.mean() if n else np.nan, GTK_SEM=sem(a),
                MAN_Mean=b.mean() if n else np.nan, MAN_SEM=sem(b),
                P_Value=p)
