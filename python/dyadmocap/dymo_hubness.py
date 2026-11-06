"""
dymo_hubness.py - how far each behavioural category sits from the rest of the
network (MATLAB nodeClosenessByCategory.m), and the tables of
Hubness_Closeness_22Oct26.m and Hubness_Roles_23Oct26.m.

THE MEASURE ("mean path distance")
For each node, the mean of its finite shortest-path distances to and from every
other node of the WHOLE graph (D_simp, both directions pooled, unreachable
pairs dropped, the diagonal removed). Then the unweighted mean over the nodes
of each category. LOW = near the network centre (hub), HIGH = peripheral.

It is deliberately UNWEIGHTED, unlike the weighted node distances of
dymo_node_distance.py (weights = product of node sizes): two different
quantities on the same network.

Node categories are node_labels() (findnodelabel 'mode'), the rule every other
per-category metric and every figure uses.

Caveat (as in the MATLAB function): if one category's nodes are large and
mixed and another's small and pure, part of a difference is composition
rather than position.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np
import pandas as pd

from .dymo_paired import paired_diff_stats
from .dymo_format import ci_verdict


def node_closeness_by_category(D, labels, n_categories=4):
    """C[c], nNodes[c] for one graph: the mean over the nodes of category c+1 of
    each node's mean distance to and from the rest of the graph. NaN where the
    category has no node with a finite distance to anything."""
    D = np.array(D, dtype=float)                 # D_simp (hop counts; Inf = no path)
    C = np.full(n_categories, np.nan)
    n_nodes = np.full(n_categories, np.nan)
    N = D.shape[0]
    if N < 2:
        return C, n_nodes
    np.fill_diagonal(D, np.nan)                  # a node's distance to itself is not
                                                 # part of its distance to the rest
    mean_dist = np.full(N, np.nan)
    for i in range(N):
        v = np.concatenate([D[i, :], D[:, i]])   # from i, and to i
        v = v[np.isfinite(v)]                    # drop NaN (diagonal) and Inf (no path)
        if v.size:
            mean_dist[i] = v.mean()
    labels = np.asarray(labels)
    for c in range(n_categories):
        vals = mean_dist[labels == c + 1]
        vals = vals[np.isfinite(vals)]
        n_nodes[c] = vals.size
        if vals.size:
            C[c] = vals.mean()
    return C, n_nodes


def _paired_rows(close, conditions, i1, i2, names, verdict_texts):
    rows = []
    for cond_name, grp in conditions:
        S = paired_diff_stats(close[grp][:, i1], close[grp][:, i2])
        rows.append({"Condition": cond_name, "N": S["N"], names[0]: S["meanA"], names[1]: S["meanB"],
                     names[2]: S["meanDiff"], "CI_Lower": S["ciBoot"][0], "CI_Upper": S["ciBoot"][1],
                     "t": S["t"], "df": S["df"], "p": S["p"], "dz": S["dz"],
                     "Verdict": ci_verdict(S["ciBoot"], *verdict_texts)})
    return pd.DataFrame(rows)


def hubness_tables(close, category_names):
    """The four tables of the two MATLAB hubness scripts.
    close: {'GTK': dyads x 4, 'MAN': dyads x 4}, dyads in the same order.
    Returns dict name -> DataFrame (unrounded)."""
    idx = {n.lower(): k for k, n in enumerate(category_names)}
    i_inact, i_act = idx["both inactive"], idx["both active"]
    i_p1, i_p2 = idx["person 1 active"], idx["person 2 active"]
    out = {}

    # Hubness_Closeness_22Oct26.m: Both Inactive against Both Active, per condition.
    # meanDiff = Inactive - Active in DISTANCE: negative = Both Inactive central.
    out["Hubness_Closeness"] = _paired_rows(
        close, [("Casual Chat", "GTK"), ("Conflict", "MAN")], i_inact, i_act,
        ["Closeness_BothInactive", "Closeness_BothActive", "MeanDiff_InactiveMinusActive"],
        ("Both Active more central", "Both Active more peripheral (supports the observation)"))

    # the descriptive picture, all four categories (not a test)
    rows = []
    for cond_name, grp in [("Casual Chat", "GTK"), ("Conflict", "MAN")]:
        for c, cname in enumerate(category_names):
            v = close[grp][:, c]
            v = v[np.isfinite(v)]
            rows.append(dict(Condition=cond_name, BehaviouralCategory=cname, N_dyads=v.size,
                             MeanClosenessDistance=v.mean() if v.size else np.nan,
                             SEM=np.std(v, ddof=1) / np.sqrt(v.size) if v.size > 1 else
                             (0.0 if v.size == 1 else np.nan)))
    out["Hubness_ClosenessByCategory"] = pd.DataFrame(rows)

    # Hubness_Roles_23Oct26.m: Person 1 Active against Person 2 Active.
    # Casual chat: the labels are arbitrary (control). Conflict: P1 boss, P2 employee.
    out["Hubness_Roles"] = _paired_rows(
        close, [("Casual Chat (labels arbitrary - control)", "GTK"),
                ("Conflict (Person 1 = boss, Person 2 = employee)", "MAN")], i_p1, i_p2,
        ["Closeness_Person1", "Closeness_Person2", "MeanDiff_P1minusP2"],
        ("Person 2 nearer the network core", "Person 1 nearer the network core"))

    # the interaction: each dyad's role gap in conflict minus its gap in casual chat
    d_gtk = close["GTK"][:, i_p1] - close["GTK"][:, i_p2]
    d_man = close["MAN"][:, i_p1] - close["MAN"][:, i_p2]
    S = paired_diff_stats(d_man, d_gtk)
    out["Hubness_RoleGap"] = pd.DataFrame([dict(
        Contrast="Role gap: conflict minus casual chat", N=S["N"],
        Gap_CasualChat=np.mean(d_gtk[np.isfinite(d_gtk)]), Gap_Conflict=np.mean(d_man[np.isfinite(d_man)]),
        MeanDiff=S["meanDiff"], CI_Lower=S["ciBoot"][0], CI_Upper=S["ciBoot"][1],
        t=S["t"], df=S["df"], p=S["p"], dz=S["dz"],
        Verdict=ci_verdict(S["ciBoot"], "Role gap larger in casual chat", "Role gap larger in conflict"))])
    return out
