"""
dymo_angles.py - stage 2 of the Python DYMO port: joint angles, then velocity.

Python counterpart of
    Functions/TM/skeletonAngleGeometry.m   -> angle_vectors()
    Functions/TM/jointAngle.m              -> joint_angle()
    Functions/TM/computeJointAngles.m      -> joint_angles()
    GTK_TM_26June26.m, section "VELOCITY"  -> velocity()

THE MATHS, in words
  * Each angle has a vertex o and two end points a, b. With u = a - o and
    w = b - o:  cos = (u . w) / (|u| |w|), clipped to [-1, 1], then
    angle = acos(cos) in degrees.
  * head_general is different: its second vector is the global vertical
    [0 0 1], so it is head inclination in the room, not a joint flexion.
  * Velocity is a forward difference: v(n) = (angle(n+1) - angle(n)) * Fs,
    so it has ONE ROW FEWER than the angles (8,999 from 9,000). It is signed.

One detail copied on purpose from MATLAB:
  MATLAB's min/max IGNORE NaN, so min(max(NaN, -1), 1) is -1, not NaN. A
  cosine that is NaN (a zero-length vector, or a marker missing for the whole
  window) therefore becomes -1, i.e. an angle of 180 degrees. numpy's clip
  would keep NaN, which spreads differently. We reproduce MATLAB here, and
  count how often it happens so it is visible rather than silent.

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

import numpy as np

# The order of the 11 angles. It sets the velocity column order everywhere
# downstream, exactly as G.names in skeletonAngleGeometry.m.
ANGLE_NAMES = ["shoulder_left", "shoulder_right", "wrist_left", "wrist_right",
               "elbow_left", "elbow_right", "knee_left", "knee_right",
               "ankle_left", "ankle_right", "head_general"]


# ---------------------------------------------------------------------------
# skeletonAngleGeometry.m
# ---------------------------------------------------------------------------
def angle_vectors(X):
    """The two vectors of each of the 11 angles, for every frame.

    X : N x 128 array of one recording, [time, frame, x1 y1 z1, x2 y2 z2, ...]
    Returns a dict  name -> (v1, v2), each N x 3.

    Joint numbers are 1-based, as in the MATLAB code and the marker list.
    Coordinate transform: X = x, Y = -z, Z = y.
    """
    def P(j):
        """N x 3 position of joint j (1-based)."""
        c = 2 + (j - 1) * 3            # 0-based column of x for joint j
        return np.column_stack([X[:, c], -X[:, c + 2], X[:, c + 1]])

    # ---- landmarks (same grouping and order of operations as MATLAB) ----
    chest          = P(5)
    left_shoulder  = (P(15) + P(16)) / 2          # Back + Top
    right_shoulder = (P(30) + P(31)) / 2
    left_elbow     = P(10)
    right_elbow    = P(25)
    left_wrist     = (P(22) + P(23)) / 2          # In + Out
    right_wrist    = (P(37) + P(38)) / 2
    left_hand      = P(11)
    right_hand     = P(26)
    left_toe       = (P(18) + P(19) + P(20)) / 3
    right_toe      = (P(33) + P(34) + P(35)) / 3
    head           = (P(6) + P(7) + P(8)) / 3
    shoulder_mid   = (left_shoulder + right_shoulder) / 2

    def mk(origin, a, b):
        return (a - origin, b - origin)

    V = {
        "shoulder_left":  mk(left_shoulder,  chest,          left_elbow),
        "shoulder_right": mk(right_shoulder, chest,          right_elbow),
        "wrist_left":     mk(left_wrist,     left_elbow,     left_hand),
        "wrist_right":    mk(right_wrist,    right_elbow,    right_hand),
        "elbow_left":     mk(left_elbow,     left_shoulder,  left_wrist),
        "elbow_right":    mk(right_elbow,    right_shoulder, right_wrist),
        "knee_left":      mk(P(13),          P(17),          P(14)),
        "knee_right":     mk(P(28),          P(32),          P(29)),
        "ankle_left":     mk(P(9),           P(14),          left_toe),
        "ankle_right":    mk(P(24),          P(29),          right_toe),
    }
    # head: the second vector is the global vertical itself, not a point
    vertical = np.tile([0.0, 0.0, 1.0], (X.shape[0], 1))
    V["head_general"] = (head - shoulder_mid, vertical)
    return V


# ---------------------------------------------------------------------------
# jointAngle.m
# ---------------------------------------------------------------------------
def joint_angle(v1, v2):
    """Frame-wise angle in degrees between two N x 3 vector series.

    Returns (angle, n_nan_cos): n_nan_cos counts frames whose cosine was NaN
    and was therefore set to -1 (180 degrees), as MATLAB's min/max do.
    """
    # sums written out left to right, as MATLAB adds 3 numbers
    dot = v1[:, 0] * v2[:, 0] + v1[:, 1] * v2[:, 1] + v1[:, 2] * v2[:, 2]
    n1 = np.sqrt(v1[:, 0] ** 2 + v1[:, 1] ** 2 + v1[:, 2] ** 2)
    n2 = np.sqrt(v2[:, 0] ** 2 + v2[:, 1] ** 2 + v2[:, 2] ** 2)
    with np.errstate(invalid="ignore", divide="ignore"):
        c = dot / (n1 * n2)
    nan_cos = np.isnan(c)
    c = np.clip(c, -1.0, 1.0)          # handles +-Inf like MATLAB
    c[nan_cos] = -1.0                  # MATLAB: min(max(NaN,-1),1) = -1
    return np.arccos(c) * (180 / np.pi), int(nan_cos.sum())


# ---------------------------------------------------------------------------
# computeJointAngles.m
# ---------------------------------------------------------------------------
def joint_angles(X):
    """N x 11 array of angles (degrees), columns in ANGLE_NAMES order.

    Also returns the number of frames whose cosine was NaN (see joint_angle).
    """
    V = angle_vectors(X)
    cols, n_nan = [], 0
    for name in ANGLE_NAMES:
        a, k = joint_angle(*V[name])
        cols.append(a)
        n_nan += k
    return np.column_stack(cols), n_nan


# ---------------------------------------------------------------------------
# Velocity section of GTK_TM_26June26.m
# ---------------------------------------------------------------------------
def velocity(angles_p1, angles_p2, fs):
    """Signed angular velocity (deg/s) of both partners, (N-1) x 22.

    Columns: Person 1's 11 angles, then Person 2's 11 angles.
    Forward difference scaled by the group's sampling rate.
    """
    if angles_p1.shape[0] != angles_p2.shape[0]:
        raise ValueError("Person 1 and Person 2 have different lengths")
    combined = np.hstack([angles_p1, angles_p2])
    return np.diff(combined, axis=0) * fs
