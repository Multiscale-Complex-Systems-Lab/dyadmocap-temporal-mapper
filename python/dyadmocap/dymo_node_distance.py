"""
dymo_node_distance.py - stage 5c of the Python pipeline: node-to-node
distances (D_simp) and the weighted category-to-category distances.

Python counterpart of
    Functions/TM/computeDsimpLowMem.m          -> compute_dsimp()
    Functions/STATS/dyadCatDistance_weighted.m -> cat_distance()

THE MATHS, in words
  D_simp(i,j) = the shortest path, in hops, in the SAMPLE-LEVEL graph g (not
                the shape graph), from any sample of node i to any sample of
                node j. Directed, so D_simp(i,j) and D_simp(j,i) differ. The
                diagonal is 0. Unreachable = Inf.
  d(a -> b)   = mean of D_simp(i,j) over nodes i labelled a and j labelled b,
                each pair weighted by nodesize(i) * nodesize(j), unreachable
                pairs left out. NaN if a category is absent or nothing is
                reachable.

HOW D_simp IS COMPUTED HERE
  One multi-source shortest-path search per node: scipy's dijkstra with
  min_only=True gives, for every sample, the distance from the NEAREST sample
  of node i - which is exactly the minimum MATLAB takes over node i's rows.
  The minimum over each target node's samples follows. Same numbers as
  computeDsimpLowMem, never an N x N matrix.

WHY THIS MATCHES MATLAB EXACTLY, NOT JUST TO 1e-6
  MATLAB stores D_simp as single. But hop counts are small whole numbers,
  which single stores exactly, and the weighted sum adds whole numbers
  (hops x size x size) far below 2^53, which double also adds exactly. So
  numerator and denominator are both exact and the distance agrees to the
  last bit.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
import networkx as nx
from scipy.sparse.csgraph import dijkstra


def compute_dsimp(g, members):
    """K x K matrix of shortest hop counts between the member sets of the K
    nodes, in the sample-level directed graph g (nodes 0..N-1)."""
    N = g.number_of_nodes()
    K = len(members)
    A = nx.to_scipy_sparse_array(g, nodelist=range(N), format="csr")

    # samples grouped by node, so the minimum over a node's samples is a reduceat
    label = np.empty(N, dtype=int)
    for k, m in enumerate(members):
        label[m] = k
    order = np.argsort(label, kind="stable")
    starts = np.searchsorted(label[order], np.arange(K))

    D = np.empty((K, K))
    for i, m in enumerate(members):
        d = dijkstra(A, directed=True, indices=m, unweighted=True, min_only=True)  # from node i
        D[i, :] = np.minimum.reduceat(d[order], starts)                           # to each node j
    return D


def cat_distance(D, labels, nodesize, cat_from, cat_to):
    """Weighted mean directed distance from category cat_from to cat_to (1..4)."""
    frm = np.flatnonzero(labels == cat_from)
    to = np.flatnonzero(labels == cat_to)
    if frm.size == 0 or to.size == 0:
        return np.nan
    Dsub = D[np.ix_(frm, to)]
    W = np.outer(nodesize[frm], nodesize[to]).astype(float)   # s_i * s_j
    valid = np.isfinite(Dsub)
    if not valid.any():
        return np.nan                                          # nothing reachable
    return float(np.sum(Dsub[valid] * W[valid]) / np.sum(W[valid]))


def four_distances(D, labels, nodesize, c1, c2):
    """d(c1->c2), d(c2->c1), d(c1->c1), d(c2->c2) - the '12', '21', '11', '22'
    of the MATLAB scripts."""
    return dict(d12=cat_distance(D, labels, nodesize, c1, c2),
                d21=cat_distance(D, labels, nodesize, c2, c1),
                d11=cat_distance(D, labels, nodesize, c1, c1),
                d22=cat_distance(D, labels, nodesize, c2, c2))
