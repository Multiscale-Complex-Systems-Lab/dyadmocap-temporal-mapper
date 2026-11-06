"""
dymo_cycles.py - stage 5d of the Python DYMO port: cycles of the shape graph,
their category composition, winner and Shannon entropy.

Python counterpart of
    Functions/Cycles/CycleCount2pFast.m            -> find_cycles()
    MainScripts/Cycles/CycleData/Cycles_WinShannon_03July.m (per dyad) -> cycle_data()
    Functions/Cycles/wholeGraphCycleMetrics.m      -> whole_cycle_metrics()
    Functions/Cycles/perCategoryCycleMetrics.m     -> category_cycle_metrics()

THE PROCEDURE, in words
  On the shape graph g_simp (unweighted, directed):
  1. one breadth-first shortest-path tree from every node s;
  2. for every pair s < t that can reach each other: the tree path s -> t,
     then the tree path t -> s without its two end nodes, joined into a cycle;
  3. keep it only if no node repeats (a simple cycle);
  4. rotate it so the smallest node number comes first, and count each
     distinct cycle once.
  CycleCount is therefore "the number of distinct shortest round-trip cycles",
  NOT the number of cycles in the graph.

TIE-BREAKING
  When two shortest paths are equally short, which one the tree keeps is
  decided inside MATLAB's shortestpathtree. Here the tree comes from scipy's
  breadth_first_order: first-in-first-out, neighbours in increasing node
  number, the first node to reach a new node becomes its parent. MATLAB breaks
  ties the same way, so the cycle lists of the two versions match.

SPEED
  The pair loop is plain Python (kept simple, like the MATLAB loop it copies),
  so it is slow: it visits every pair of nodes, about 12 million pairs for a
  graph of about 5,000 nodes.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
import networkx as nx
from scipy.sparse.csgraph import breadth_first_order


# ---------------------------------------------------------------------------
# CycleCount2pFast.m
# ---------------------------------------------------------------------------
def shortest_path_trees(g_simp):
    """Breadth-first tree from every node: PRED[s, v] = parent of v on the
    s -> v path (-1 if v is unreachable from s, s itself for v = s)."""
    K = g_simp.number_of_nodes()
    A = nx.to_scipy_sparse_array(g_simp, nodelist=range(K), format="csr")
    A.sort_indices()                                  # neighbours in increasing order
    A.data[:] = 1                                     # unweighted, as adjacency(G) in MATLAB
    PRED = np.full((K, K), -1, dtype=np.int32)
    for s in range(K):
        _, pred = breadth_first_order(A, s, directed=True, return_predecessors=True)
        pred[pred < 0] = -1                           # scipy marks "no parent" as -9999
        pred[s] = s
        PRED[s] = pred
    return PRED


def _tree_path(PRED, s, t):
    """Nodes on the tree path s -> t, starting at s and ending at t."""
    path = [t]
    v = t
    while v != s:
        v = int(PRED[s, v])
        path.append(v)
    path.reverse()
    return path


def find_cycles(g_simp, progress_every=0):
    """All distinct simple shortest round-trip cycles (list of tuples of node
    numbers, each rotated to start at its smallest node)."""
    PRED = shortest_path_trees(g_simp)
    K = PRED.shape[0]
    cycles = set()
    for s in range(K):
        if progress_every and s % progress_every == 0:
            print("      %3.0f %% of nodes done" % (100.0 * s / K), flush=True)
        for t in range(s + 1, K):
            if PRED[s, t] < 0 or PRED[t, s] < 0:       # not mutually reachable
                continue
            spf = _tree_path(PRED, s, t)               # s -> t
            spb = _tree_path(PRED, t, s)               # t -> s
            cycle = spf + spb[1:-1]
            if len(set(cycle)) != len(cycle):          # keep simple cycles only
                continue
            i = cycle.index(min(cycle))                # rotate: smallest node first
            cycles.add(tuple(cycle[i:] + cycle[:i]))
    return sorted(cycles, key=lambda c: (len(c), c))   # MATLAB order: by length, then rows


# ---------------------------------------------------------------------------
# Cycles_WinShannon_03July.m, per dyad
# ---------------------------------------------------------------------------
def cycle_data(cycles, node_labels, n_categories=4):
    """Per cycle: length, category counts, winner, entropy (nats)."""
    n = len(cycles)
    lengths = np.array([len(c) for c in cycles], dtype=float)
    counts = np.zeros((n, n_categories))
    for i, c in enumerate(cycles):
        counts[i] = np.bincount(node_labels[list(c)], minlength=n_categories + 1)[1:]
    # winner: first maximum = the SMALLER category number on a tie (MATLAB max)
    winner = counts.argmax(axis=1) + 1 if n else np.zeros(0, dtype=int)
    # Shannon entropy in nats, with 0 * log 0 = 0
    with np.errstate(invalid="ignore", divide="ignore"):
        P = counts / counts.sum(axis=1, keepdims=True)
        PL = np.where(P > 0, P * np.log(P), 0.0)
    entropy = -PL.sum(axis=1)
    return dict(lengths=lengths, counts=counts, winner=winner, entropy=entropy)


# ---------------------------------------------------------------------------
# wholeGraphCycleMetrics.m
# ---------------------------------------------------------------------------
def whole_cycle_metrics(cd, n_nodes):
    n = cd["lengths"].size
    return dict(CycleCount=float(n),
                CycleLenMean=cd["lengths"].mean() if n else np.nan,
                meanEntropy=np.nanmean(cd["entropy"]) if n else np.nan,
                cycleDensity=n / n_nodes)


# ---------------------------------------------------------------------------
# perCategoryCycleMetrics.m  (absentValue = NaN)
# ---------------------------------------------------------------------------
def category_cycle_metrics(cd, n_categories=4, absent_value=np.nan):
    n = cd["lengths"].size
    win = cd["winner"]
    count = np.array([np.sum(win == c) for c in range(1, n_categories + 1)], dtype=float)
    M = dict(CycleCount=count)
    if n > 0:
        M["winnerProp"] = count / n
        M["cycleDensity"] = count / n                  # the same number (part 2, 5.5)
    else:
        M["winnerProp"] = np.zeros(n_categories)
        M["cycleDensity"] = np.full(n_categories, np.nan)
    M["CycleLenMean"] = np.array([cd["lengths"][win == c].mean() if np.any(win == c) else absent_value
                                  for c in range(1, n_categories + 1)])
    M["meanEntropy"] = np.array([np.nanmean(cd["entropy"][win == c]) if np.any(win == c) else absent_value
                                 for c in range(1, n_categories + 1)])
    if n > 0:
        prop = cd["counts"] / cd["counts"].sum(axis=1, keepdims=True)
        M["cycleCategoryCounts"] = np.nanmean(prop, axis=0)
    else:
        M["cycleCategoryCounts"] = np.zeros(n_categories)
    return M
