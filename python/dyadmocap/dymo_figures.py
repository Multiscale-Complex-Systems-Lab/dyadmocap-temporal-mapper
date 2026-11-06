"""
dymo_figures.py - the temporal-mapper figures of the MATLAB pipeline, for
one dyad, in Python:

    MATLAB (GTK_TM_26June26.m, figure folder)      Python function
    02_Skeletons_Frame1                             skeleton_frame1()
    04_AngleVectorSkeletons  (plotSkeletonAngleVectors.m)  angle_vector_skeletons()
    05_AngleTimeSeries + overview (plotAngleTimeSeries.m)  angle_time_series()
    06_DistanceMatrices                             distance_matrix()
    07_TimePointCategoryBars                        category_bars()
    08_FourColorGraphs (plotTMGraphCategories.m)    four_color_graph()

Colours as in MATLAB: categories black / green / blue / red (C.cmap), Person 1
blue and Person 2 red (DYMO_personColors.m), angle vectors green (v1) and
magenta (v2), distance matrix 'hot' with the colour bar fixed at 0-50.
Every figure is saved as PNG and vector PDF, 14 x 8 inches as in
AutoSavePublishableFigure.m.

These figures show one participant dyad's data: they are saved in the Python
RESULTS folder, never in the code folder, and are not to be shared.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import os
import numpy as np
import matplotlib
matplotlib.use("Agg")                      # draw to files, no windows
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
from scipy.spatial.distance import cdist

from .dymo_angles import ANGLE_NAMES, angle_vectors, joint_angle

CAT_NAMES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]
CAT_CMAP = np.array([[0, 0, 0], [0, 1, 0], [0, 0, 1], [1, 0, 0]], dtype=float)   # C.cmap
PERSON_COLORS = [(0, 0, 1), (1, 0, 0)]                                              # blue, red
PERSON_NAMES = ["Person 1", "Person 2"]


# ---------------------------------------------------------------------------
# saving: PNG + vector PDF, 14 x 8 inches (AutoSavePublishableFigure.m)
# ---------------------------------------------------------------------------
def save(fig, folder, name):
    os.makedirs(folder, exist_ok=True)
    fig.set_size_inches(14, 8)
    for ax in fig.axes:
        ax.title.set_fontsize(11)
        ax.title.set_fontweight("bold")
    fig.savefig(os.path.join(folder, name + ".png"), dpi=300, bbox_inches="tight")
    fig.savefig(os.path.join(folder, name + ".pdf"), bbox_inches="tight")
    plt.close(fig)


def _joints(X, frame=0):
    """Joint positions at one frame, J x 3, transformed as in MATLAB
    (X = x, Y = -z, Z = y); joint 1 is replaced by the seat (mean of 2 and 3)."""
    J = (X.shape[1] - 2) // 3
    c = 2 + np.arange(J) * 3
    P = np.column_stack([X[frame, c], -X[frame, c + 2], X[frame, c + 1]])
    P[0] = (P[1] + P[2]) / 2
    return P


def _skeleton_axes(fig):
    ax = fig.add_subplot(projection="3d")
    ax.view_init(elev=1.99, azim=97.17)     # view(97.17, 1.99)
    ax.set_axis_off()
    return ax


def _equal_3d(ax, pts):
    lo, hi = pts.min(axis=0), pts.max(axis=0)
    ax.set_box_aspect(hi - lo + 1e-9)       # axis equal


# ---------------------------------------------------------------------------
# 02_Skeletons_Frame1
# ---------------------------------------------------------------------------
def skeleton_frame1(pair, title, folder, name):
    fig = plt.figure()
    ax = _skeleton_axes(fig)
    allp = []
    for s, X in enumerate(pair):
        P = _joints(X)
        allp.append(P)
        ax.plot(P[:, 0], P[:, 1], P[:, 2], "o", ms=6, color=PERSON_COLORS[s])
        ax.plot([P[0, 0]], [P[0, 1]], [P[0, 2]], "o", ms=8, mfc="y", mec="k")   # seat
    _equal_3d(ax, np.vstack(allp))
    ax.set_title(title)
    save(fig, folder, name)
    # nothing is returned


# ---------------------------------------------------------------------------
# 04_AngleVectorSkeletons (plotSkeletonAngleVectors.m)
# ---------------------------------------------------------------------------
GROUPS = [("Shoulder", ["shoulder_left", "shoulder_right"]), ("Wrist", ["wrist_left", "wrist_right"]),
          ("Elbow", ["elbow_left", "elbow_right"]), ("Knee", ["knee_left", "knee_right"]),
          ("Ankle", ["ankle_left", "ankle_right"]), ("Head", ["head_general"])]
TEXT = {"shoulder_left": "Left shoulder", "shoulder_right": "Right shoulder", "wrist_left": "Left wrist",
        "wrist_right": "Right wrist", "elbow_left": "Left elbow", "elbow_right": "Right elbow",
        "knee_left": "Left knee", "knee_right": "Right knee", "ankle_left": "Left ankle",
        "ankle_right": "Right ankle", "head_general": "Head"}


def _origin(X, name):
    """Vertex of each angle at frame 1 (as in skeletonAngleGeometry.m)."""
    J = (X.shape[1] - 2) // 3
    c = 2 + np.arange(J) * 3
    P = lambda j: np.array([X[0, c[j - 1]], -X[0, c[j - 1] + 2], X[0, c[j - 1] + 1]])
    ls, rs = (P(15) + P(16)) / 2, (P(30) + P(31)) / 2
    return {"shoulder_left": ls, "shoulder_right": rs,
            "wrist_left": (P(22) + P(23)) / 2, "wrist_right": (P(37) + P(38)) / 2,
            "elbow_left": P(10), "elbow_right": P(25), "knee_left": P(13), "knee_right": P(28),
            "ankle_left": P(9), "ankle_right": P(24), "head_general": (ls + rs) / 2}[name]


def angle_vector_skeletons(pair, title_prefix, folder, prefix):
    V = [angle_vectors(X[:1]) for X in pair]
    for group, names in GROUPS:
        fig = plt.figure()
        ax = _skeleton_axes(fig)
        allp = []
        for s, X in enumerate(pair):
            P = _joints(X)
            allp.append(P)
            ax.plot(P[:, 0], P[:, 1], P[:, 2], "o", ms=6, color=PERSON_COLORS[s], label=PERSON_NAMES[s])
            ax.plot([P[0, 0]], [P[0, 1]], [P[0, 2]], "o", ms=8, mfc="y", mec="k")
            for nm in names:
                v1, v2 = V[s][nm][0][0], V[s][nm][1][0]
                ang, _ = joint_angle(v1[None, :], v2[None, :])
                if nm == "head_general":
                    v2 = v2 / np.linalg.norm(v2) * np.linalg.norm(v1)   # visible reference arrow
                o = _origin(X, nm)
                ax.quiver(*o, *v1, color="g", linewidth=2)
                ax.quiver(*o, *v2, color="m", linewidth=2)
                ax.text(*(o + v1), "%s Angle: %.2f°" % (TEXT[nm], ang[0]), color=PERSON_COLORS[s], fontsize=8)
        _equal_3d(ax, np.vstack(allp))
        ax.plot([], [], color="g", label="angle vector 1 (green)")
        ax.plot([], [], color="m", label="angle vector 2 (magenta)")
        ax.legend(loc="best")
        ax.set_title("%s: 3D Skeletons with %s Angles (frame 1)" % (title_prefix, group))
        save(fig, os.path.join(folder, group), "%s_%s_Angles_Skeleton" % (prefix, group))


# ---------------------------------------------------------------------------
# 05_AngleTimeSeries (plotAngleTimeSeries.m), 11 figures + overview
# ---------------------------------------------------------------------------
INFO = [("shoulder_left", "Left Shoulder", "Abduction/Adduction", None),
        ("shoulder_right", "Right Shoulder", "Abduction/Adduction", None),
        ("wrist_left", "Left Wrist", "Flexion/Extension", None),
        ("wrist_right", "Right Wrist", "Flexion/Extension", None),
        ("elbow_left", "Left Elbow", "Flexion/Extension", (0, 180)),
        ("elbow_right", "Right Elbow", "Flexion/Extension", (0, 180)),
        ("knee_left", "Left Knee", "Flexion/Extension", None),
        ("knee_right", "Right Knee", "Flexion/Extension", None),
        ("ankle_left", "Left Ankle", "Dorsiflexion/Plantarflexion", None),
        ("ankle_right", "Right Ankle", "Dorsiflexion/Plantarflexion", None),
        ("head_general", "Head", "Tilt from vertical", None)]


def angle_time_series(angles, times, title_prefix, folder, prefix):
    """angles: [Person 1 N x 11, Person 2 N x 11]; times: the file time columns (s)."""
    def draw(ax, k):
        for s in range(2):
            ax.plot(times[s], angles[s][:, k], color=PERSON_COLORS[s], lw=2, label=PERSON_NAMES[s])

    for k, (field, label, motion, yl) in enumerate(INFO):
        fig, ax = plt.subplots()
        draw(ax, k)
        ax.set_xlabel("Time (s)")
        ax.set_ylabel(label + " Angle (Degrees)")
        ax.set_title("%s: %s Angle Over Time (%s)" % (title_prefix, label, motion))
        if yl:
            ax.set_ylim(yl)
        ax.legend(loc="best")
        ax.grid(True)
        save(fig, os.path.join(folder, label.replace(" ", "_")),
             "%s_%s_Angle" % (prefix, label.replace(" ", "_")))

    fig, axs = plt.subplots(4, 3, constrained_layout=True)
    for k, (field, label, motion, yl) in enumerate(INFO):
        ax = axs.flat[k]
        draw(ax, k)
        ax.set_title(label)
        if yl:
            ax.set_ylim(yl)
        ax.grid(True)
        if k == 0:
            ax.legend(loc="best")
    axs.flat[-1].axis("off")
    fig.supxlabel("Time (s)")
    fig.supylabel("Angle (Degrees)")
    fig.suptitle(title_prefix + ": All Joint Angles Over Time")
    save(fig, os.path.join(folder, "All_Angles_Overview"), prefix + "_All_Angles_Overview")


# ---------------------------------------------------------------------------
# 06_DistanceMatrices (display only: at most 4,000 evenly spaced samples)
# ---------------------------------------------------------------------------
def distance_matrix(zv, time, title, folder, name, max_points=4000, max_limit=50):
    step = max(1, int(np.ceil(zv.shape[0] / max_points)))
    idx = np.arange(0, zv.shape[0], step)
    D = cdist(zv[idx].astype(np.float32), zv[idx].astype(np.float32))    # Euclidean (L-2)
    fig, ax = plt.subplots()
    im = ax.imshow(D, cmap="hot", vmin=0, vmax=max_limit, origin="upper",
                   extent=[time[idx[0]], time[idx[-1]], time[idx[-1]], time[idx[0]]])
    cb = fig.colorbar(im, ax=ax)
    cb.set_label("L-2 distance")
    ax.set_title(title)
    ax.set_xlabel("time (s)")
    ax.set_ylabel("time (s)")
    ax.set_aspect("equal")
    save(fig, folder, name)


# ---------------------------------------------------------------------------
# 07_TimePointCategoryBars
# ---------------------------------------------------------------------------
def category_bars(colorvar, title, folder, name):
    counts = np.array([np.sum(colorvar == k) for k in (1, 2, 3, 4)])
    pct = counts / counts.sum() * 100
    fig, ax = plt.subplots()
    ax.bar(np.arange(1, 5), counts, color=CAT_CMAP, edgecolor="k")
    ax.set_xticks(np.arange(1, 5))
    ax.set_xticklabels(CAT_NAMES)
    ax.set_xlabel("Behavioural Category")
    ax.set_ylabel("Time points")
    ax.set_title(title)
    ax.grid(True)
    for i in range(4):
        ax.text(i + 1, counts[i] + 0.5, "%.1f%%" % pct[i], ha="center", va="bottom", fontweight="bold")
    save(fig, folder, name)


# ---------------------------------------------------------------------------
# 08_FourColorGraphs (plotTMGraphCategories.m + tmapper2 plottmgraph.m)
# ---------------------------------------------------------------------------
def graph_layout(g_simp):
    """Force-directed node positions (networkx spring layout, seed 1, so the
    same graph always gets the same picture)."""
    import networkx as nx
    return nx.spring_layout(g_simp, seed=1)


def four_color_graph(g_simp, colorvar, members, title, folder, name, cmap=None, pos=None):
    """The shape graph, nodes coloured by their category label (mode of the
    samples, ties to the smaller number), sized by log10 of their sample count
    rescaled to 3-8, force-directed layout - as plottmgraph.m does with
    'Layout','force', 'nodesizemode','log', 'nodesizerange',[3 8].

    The layout is networkx's force-directed (Fruchterman-Reingold) layout, the
    same family as MATLAB's 'force'. A force layout has a random start, so the
    picture's arrangement will not look identical to the MATLAB figure; the
    graph drawn is the same. (tmapper-py's own plot_tmgraph needs the optional
    python-igraph package, which is not installed.)

    cmap : 4 x 3 colours, default the category colours. The subgraph
           highlighting figures pass one category's colour and grey for the
           other three (GTK/MAN_Above3Min_SubGraphs_20July.m, part B).
    pos  : node positions to reuse (from graph_layout), so the four
           highlighting figures of a dyad share one arrangement.
    Returns the positions used."""
    import networkx as nx
    from matplotlib.collections import LineCollection
    from .dymo_graph_metrics import node_labels

    labels = node_labels(members, colorvar)
    size = np.log10(np.array([len(m) for m in members], dtype=float))
    if np.ptp(size) > 0:
        size = 3 + (size - size.min()) / np.ptp(size) * 5          # rescale to [3, 8]
    else:
        size = np.full(size.shape, 3 + 5 / len(size))
    if cmap is None:
        cmap = CAT_CMAP
    cmap = np.asarray(cmap, dtype=float)
    if pos is None:
        pos = graph_layout(g_simp)
    xy = np.array([pos[n] for n in range(g_simp.number_of_nodes())])

    fig, ax = plt.subplots()
    segs = [(xy[u], xy[v]) for u, v in g_simp.edges()]
    ax.add_collection(LineCollection(segs, colors="k", alpha=0.3, linewidths=0.5, zorder=1))
    order = np.argsort(size)[::-1]                                  # small nodes on top
    ax.scatter(xy[order, 0], xy[order, 1], s=size[order] ** 2, c=cmap[labels[order] - 1],
               edgecolors="none", zorder=2)
    ax.set_aspect("equal")
    ax.axis("off")
    sm = plt.cm.ScalarMappable(cmap=ListedColormap(cmap), norm=plt.Normalize(0.5, 4.5))
    cbar = fig.colorbar(sm, ax=ax, ticks=[1, 2, 3, 4])
    cbar.set_ticklabels(CAT_NAMES)
    cbar.set_label("Behavioural Categories")
    ax.set_title(title)
    save(fig, folder, name)
    return pos
