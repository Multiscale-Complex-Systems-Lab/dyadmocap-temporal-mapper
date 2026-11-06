"""
dymo_animation.py - the skeleton animation of one dyad: both people's markers
moving over time, drawn as the per-dyad skeleton figure is drawn
(dymo_figures.skeleton_frame1): Person 1 blue, Person 2 red, the seat (mean of
markers 2 and 3) in yellow, markers only, the side view of the MATLAB TM
scripts (view(97.17, 1.99)), axes hidden, fixed axis limits.

Playback runs in real time: fs / frame_step frames per second. Saved as MP4
when ffmpeg is installed (it is, in environment.yml), otherwise as a GIF.

The animation is a check that the marker data are read and placed correctly
(two seated people facing each other, moving plausibly). It is made for one
dyad in the walkthrough notebook, not for every dyad.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""
import shutil

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation, FFMpegWriter, PillowWriter

from .dymo_figures import PERSON_COLORS


def joint_positions(X):
    """All frames: samples x joints x 3, transformed as in MATLAB
    (X = x, Y = -z, Z = y); joint 1 is replaced by the seat (mean of 2 and 3).
    X: one preprocessed recording, [time, frame, x1 y1 z1, ...]."""
    J = (X.shape[1] - 2) // 3
    c = 2 + np.arange(J) * 3
    P = np.stack([X[:, c], -X[:, c + 2], X[:, c + 1]], axis=2)
    P[:, 0, :] = (P[:, 1, :] + P[:, 2, :]) / 2
    return P


def animate_dyad(pair, out_path, fs, seconds=10.0, start_s=0.0, frame_step=2, title="", dpi=100):
    """Animate `seconds` of one dyad from `start_s` seconds into the window.

    pair : (Person 1 recording, Person 2 recording), as loaded by the pipeline
    fs   : sampling rate (Hz)
    Returns the path written (.mp4, or .gif without ffmpeg)."""
    P = [joint_positions(X) for X in pair]
    n = min(p.shape[0] for p in P)
    i0 = int(round(start_s * fs))
    frames = np.arange(i0, min(n, i0 + int(round(seconds * fs))), frame_step)
    allp = np.concatenate([p[frames].reshape(-1, 3) for p in P])
    lo, hi = np.nanmin(allp, axis=0), np.nanmax(allp, axis=0)

    fig = plt.figure(figsize=(9.6, 7.2))
    ax = fig.add_subplot(projection="3d")
    ax.view_init(elev=1.99, azim=97.17)          # view(97.17, 1.99), as skeleton_frame1
    ax.set_xlim(lo[0], hi[0])
    ax.set_ylim(lo[1], hi[1])
    ax.set_zlim(lo[2], hi[2])
    ax.set_box_aspect(hi - lo + 1e-9)            # axis equal
    ax.set_axis_off()
    ax.computed_zorder = False                   # seat drawn on top
    pts, seats = [], []
    for s, p in enumerate(P):
        f = frames[0]
        pts.append(ax.scatter(*p[f].T, s=36, color=PERSON_COLORS[s], depthshade=False))
        seats.append(ax.scatter(*p[f, 0:1].T, s=64, color="y", edgecolors="k", depthshade=False))
    head = ax.set_title(title, fontsize=13, fontweight="bold")

    def update(f):
        for s, p in enumerate(P):
            pts[s]._offsets3d = tuple(p[f].T)
            seats[s]._offsets3d = tuple(p[f, 0:1].T)
        head.set_text("%s\n%.1f s" % (title, f / fs))
        return pts + seats + [head]

    anim = FuncAnimation(fig, update, frames=frames, blit=False)
    out_path = str(out_path).rsplit(".", 1)[0]
    if shutil.which("ffmpeg"):
        out_path += ".mp4"
        anim.save(out_path, writer=FFMpegWriter(fps=fs / frame_step), dpi=dpi)
    else:
        out_path += ".gif"
        anim.save(out_path, writer=PillowWriter(fps=fs / frame_step), dpi=dpi)
    plt.close(fig)
    return out_path
