"""
dymo_graph.py - stage 4 of the Python DYMO port: the temporal mapper graph.

Python counterpart of the "ALL DYADS: FOUR-COLOR GRAPH PIPELINE" section of
GTK_TM_26June26.m, using tmapper-py (the Python version of tmapper2):
    Functions/TM/zscoreSafe.m                 -> zscore_safe()
    tmapper2 tknndigraph(..., 'lowMemory',true) -> tmapper.tknndigraph(..., low_memory=True)
    tmapper2 filtergraph(g, dmap, 'reciprocal',true) with 3 outputs
                                              -> tmapper.filtergraph(..., compute_dsimp=False)

THE GRAPH INPUT - the single easiest thing to get wrong
    The graph is built from the z-scored SIGNED velocity of BOTH partners,
    N x 22 (Person 1's 11 columns, then Person 2's 11). NOT from the median-
    normalised category score of stage 3. The categories only label the nodes
    afterwards, so they do not enter this file at all.

tmapper-py vs the MATLAB toolbox (tmapper2 v2.2; the analysis used commit 58ee193):
    the low-memory k-NN build and the reachability route of filtergraph were
    read side by side and do the same thing: the k nearest plus every tie at
    the k-th distance, the forward temporal band of texclude samples excluded,
    reciprocity required, then samples within fewer than dmap hops both ways
    merged into nodes. Because ties at the k-th distance are all kept, WHICH
    tied neighbour a search finds first cannot change the graph.
    One difference that does not matter for the counts: tmapper-py numbers
    nodes from 0, MATLAB from 1.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
import networkx as nx
from scipy.spatial import cKDTree

import tmapper


# ---------------------------------------------------------------------------
# zscoreSafe.m
# ---------------------------------------------------------------------------
def zscore_safe(x):
    """Column-wise (x - mean) / SD with N-1; a constant column gives 0.

    MATLAB's zscoreSafe also fills NaN values; stage 2 showed the velocity
    has none, so a NaN here is an error rather than something to fill.
    """
    x = np.asarray(x, dtype=float)
    if not np.all(np.isfinite(x)):
        raise ValueError("velocity contains NaN/Inf; stage 2 said it should not")
    mu = x.mean(axis=0)
    sd = x.std(axis=0, ddof=1)
    sd[sd == 0] = 1.0
    return (x - mu) / sd


# ---------------------------------------------------------------------------
# graphInputVelocity.m: what feeds the graph
# ---------------------------------------------------------------------------
def graph_input_velocity(v, method=None):
    """The matrix the temporal mapper is built from, and an info dict.

    'zscore'    (default, the reported analysis) z-scored SIGNED velocity
    'median'    |v| / median(|v|) per joint - the category score's scaling
    'abszscore' z-score of |v|
    The reported analysis uses the median for the activity score and the
    signed z-score for the network. The option exists so the alternatives can
    be rerun; a run with another method needs its own PY_TAG.
    """
    from . import dymo_settings as S
    from .dymo_matlab import matlab_median
    method = (method or getattr(S, "GRAPH_NORMALIZATION", "zscore")).lower()
    v = np.asarray(v, dtype=float)
    if method == "zscore":
        return zscore_safe(v), dict(method="zscore", jointScale=v.std(axis=0, ddof=1),
                                    nGuardedJoints=0, signDiscarded=False)
    if method == "median":
        if not np.all(np.isfinite(v)):
            raise ValueError("velocity contains NaN/Inf; stage 2 said it should not")
        speed = np.abs(v)
        m = np.array([matlab_median(speed[:, j]) for j in range(speed.shape[1])])
        guarded = (m <= 0) | ~np.isfinite(m)      # a joint that never moves
        m[guarded] = 1.0
        X = speed / m
        X[:, guarded] = 0.0
        return X, dict(method="median", jointScale=m, nGuardedJoints=int(guarded.sum()), signDiscarded=True)
    if method == "abszscore":
        return zscore_safe(np.abs(v)), dict(method="abszscore", jointScale=np.abs(v).std(axis=0, ddof=1),
                                            nGuardedJoints=0, signDiscarded=True)
    raise ValueError("graph normalisation must be 'zscore', 'median' or 'abszscore', not %r" % method)


# ---------------------------------------------------------------------------
# The graph
# ---------------------------------------------------------------------------
def build_graph(v, k, dmap, texclude):
    """Temporal mapper shape graph of one dyad from its (N-1) x 22 velocity.

    Returns g_simp (networkx DiGraph), members (list of lists of sample
    indices, 0-based), nodesize (array).
    """
    X, _ = graph_input_velocity(v)        # z-scored signed velocity by default
    n = X.shape[0]
    g, _ = tmapper.tknndigraph(X, k, np.arange(n),
                               reciprocal=True,
                               time_exclude_space=True,
                               time_exclude_range=texclude,
                               low_memory=True)
    g_simp, members, nodesize, _ = tmapper.filtergraph(g, dmap, reciprocal=True,
                                                       compute_dsimp=False)
    return g_simp, members, nodesize


def graph_counts(g_simp, members):
    """The fingerprint's graph columns (DYMO_fingerprint.m, graphStats)."""
    sz = np.array([len(m) for m in members])
    return dict(nNodes=g_simp.number_of_nodes(),
                nEdges=g_simp.number_of_edges(),
                nodeSizeSum=int(sz.sum()),
                nodeSizeMax=int(sz.max()),
                nComponents=nx.number_weakly_connected_components(g_simp))


# ---------------------------------------------------------------------------
# Diagnostic: how close did any neighbour choice come to changing?
# ---------------------------------------------------------------------------
def knn_margin(v, k, texclude):
    """Smallest relative gap between a sample's k-th and (k+1)-th eligible
    neighbour distance, over all samples - and how many exact ties there are.

    Stage 3 showed single-frame values agree with MATLAB to about 1e-12, not
    1e-16. If some sample's k-th and (k+1)-th distances are closer than that,
    MATLAB and Python could legitimately pick different neighbours. Exact ties
    (gap 0) are harmless: both toolboxes keep every tie.
    Eligible = not itself and not one of the next texclude samples.
    """
    X, _ = graph_input_velocity(v)        # z-scored signed velocity by default
    n = X.shape[0]
    tree = cKDTree(X)
    q = k + 1 + texclude + 1                 # enough to survive the exclusions
    dist, idx = tree.query(X, k=q)
    rows = np.arange(n)[:, None]
    excluded = (idx == rows) | ((idx > rows) & (idx <= rows + texclude))
    d = np.where(excluded, np.inf, dist)
    d.sort(axis=1)
    dk, dk1 = d[:, k - 1], d[:, k]
    gap = (dk1 - dk) / dk
    n_ties = int(np.sum(gap == 0))
    positive = gap[gap > 0]
    return (float(positive.min()) if positive.size else np.inf), n_ties


def build_graph_with_samples(v, k, dmap, texclude):
    """As build_graph, but also returns the SAMPLE-LEVEL graph g, which the
    node distances (D_simp) are measured on. Same calls, same settings."""
    X, _ = graph_input_velocity(v)        # z-scored signed velocity by default
    n = X.shape[0]
    g, _ = tmapper.tknndigraph(X, k, np.arange(n),
                               reciprocal=True,
                               time_exclude_space=True,
                               time_exclude_range=texclude,
                               low_memory=True)
    g_simp, members, nodesize, _ = tmapper.filtergraph(g, dmap, reciprocal=True,
                                                       compute_dsimp=False)
    return g_simp, members, nodesize, g
