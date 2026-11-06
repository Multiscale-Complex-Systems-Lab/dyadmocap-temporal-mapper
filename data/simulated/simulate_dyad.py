"""
simulate_dyad.py - make SIMULATED motion-capture recordings of a seated dyad.

No participant data are used or contained here. All settings are ILLUSTRATIVE
ONLY: they are not fitted to any real recording and say nothing about real
casual chat or conflict.

WHY MARKERS AND NOT ANGLES
The analysis starts from the raw marker export, so the simulator writes raw
marker files. Every step of the pipeline (loading, trimming and window
selection, gap filling, skeleton plots and animation, joint angles, velocity,
states, Temporal Mapper, network measures, figures) then runs on them exactly as
on real data.

WHAT IT MAKES
Two seated people facing each other 1.83 m (6 ft) apart. Each has 42 markers, in
the same order and file layout as the study's optical motion-capture export:

    one tab-delimited text file per person and condition,
    one header row, then 128 columns: time (s), frame, x1 y1 z1, ..., x42 y42 z42
    coordinates in mm; y is vertical (the analysis maps X = x, Y = -z, Z = y)

The 30 markers that define the 11 joint angles are placed on the body where the
analysis expects them (see MARKERS below); the other 12 are placed on the torso,
upper arms and heels and are not used by the angles.

A hidden state sequence decides, at every moment, who is moving:
    1 = Both Inactive, 2 = Both Active, 3 = Person 1 Active, 4 = Person 2 Active
A moving person's joints (shoulders, elbows, wrists, knees, ankles, head) follow
larger, faster rotations; a still person only sways slightly. The markers are
computed from those rotations (forward kinematics), plus 0.5 mm marker jitter
and a few short gaps (missing values) so the gap-filling step is exercised.

Each recording has 25 s of calibration at the start and 5 s at the end, which
the pipeline trims, around the conversation.

MANY DYADS
Each dyad has its own style (how long states last, how much each person
moves, how often each state occurs), the same in both of its conversations.
"casual": the four states about equally often; "conflict": time shifted from
both-person states to one-person states (a toy version of turn-taking).
These settings are made up; results on them are not findings.
By default 15 dyads are written, 2 of them with a conversation too short on
purpose, so the pipeline's inclusion rule (>= 180 s) excludes them and 13
remain. The number is deliberately different from the study's, so the
simulation cannot be mistaken for the real dataset.

FILES WRITTEN (to data/simulated/generated/, or to --out)
    simdyadNN_<conversation>_person1_opt.txt.gz, ..._person2_opt.txt.gz
                                    marker files (gzip-compressed text)
    simdyadNN_<conversation>_hidden_states.csv.gz
                                    the true state per sample (only a simulation
                                    has this; used to check the state rule)
    simulated_dyads.json            the list of dyads and files
About 0.2 GB for 15 dyads. The files are NOT committed to the repository: the
fixed seeds make every run write identical files, so the script is the record.

RUN
    python simulate_dyad.py                 (15 dyads, about 1-3 minutes)
    python simulate_dyad.py --n-dyads 10    (fewer, faster)

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""
import argparse
import json
from pathlib import Path

import numpy as np

FS = 50                 # Hz
CALIB_S = 25.0          # calibration at the start (trimmed by the pipeline)
END_S = 5.0             # trimmed at the end
FACING_DISTANCE_MM = 1830.0      # 6 ft between the two chairs
STATE_NAMES = ["Both Inactive", "Both Active", "Person 1 Active", "Person 2 Active"]

# share of time in each state (BI, BA, P1, P2) - illustrative only
SETTINGS = {
    "casual":   np.array([0.25, 0.25, 0.25, 0.25]),
    "conflict": np.array([0.20, 0.15, 0.35, 0.30]),
}

# 42 markers, 1-based numbers as in the analysis code. Left side 9-23, right
# side 24-38 (left + 15). "(not used)" = not used by any joint angle.
MARKERS = {
    1: "pelvis_back (not used)",  2: "hip_left",  3: "hip_right",
    4: "upper_back (not used)",   5: "chest",
    6: "head_front", 7: "head_left", 8: "head_right",
    9: "ankle_left", 10: "elbow_left", 11: "hand_left",
    12: "upperarm_left (not used)", 13: "knee_left", 14: "shin_left",
    15: "shoulder_left_back", 16: "shoulder_left_top", 17: "thigh_left",
    18: "toe_left_in", 19: "toe_left_mid", 20: "toe_left_out",
    21: "heel_left (not used)", 22: "wrist_left_in", 23: "wrist_left_out",
    24: "ankle_right", 25: "elbow_right", 26: "hand_right",
    27: "upperarm_right (not used)", 28: "knee_right", 29: "shin_right",
    30: "shoulder_right_back", 31: "shoulder_right_top", 32: "thigh_right",
    33: "toe_right_in", 34: "toe_right_mid", 35: "toe_right_out",
    36: "heel_right (not used)", 37: "wrist_right_in", 38: "wrist_right_out",
    39: "neck_back (not used)", 40: "midback (not used)",
    41: "back_left (not used)", 42: "back_right (not used)",
}

# Joint rotations (degrees): resting value, gesture amplitude when moving.
# Illustrative values for a seated, talking person.
DOF = {
    "shoulder_flex": (15, 20), "shoulder_abd": (12, 6), "elbow_flex": (85, 30),
    "wrist_flex": (10, 20), "thigh_elev": (5, 4), "knee": (95, 12),
    "ankle": (100, 12), "head_pitch": (8, 10),
}


# ----------------------------------------------------------------------------
# hidden states and joint rotations
# ----------------------------------------------------------------------------
def state_sequence(n, p_state, mean_dwell_s, fs, rng):
    """Pick a state from p_state, hold it for a random dwell time (>= 0.5 s)."""
    seq = np.empty(n, dtype=int)
    i = 0
    while i < n:
        s = rng.choice(4, p=p_state) + 1
        dwell = max(int(rng.exponential(mean_dwell_s) * fs), fs // 2)
        seq[i:i + dwell] = s
        i += dwell
    return seq


def person_moving(states, person):
    """True where this person (1 or 2) is moving."""
    return np.isin(states, [2, 3]) if person == 1 else np.isin(states, [2, 4])


def rotations(moving, fs, rng, amp_scale=1.0):
    """Joint rotation time series (degrees) for one person, per side.
    amp_scale: this person's overall gesture size (their own movement style)."""
    n = moving.size
    t = np.arange(n) / fs
    k = np.hanning(fs // 2)                               # smooth on/off of movement
    env = np.convolve(moving.astype(float), k / k.sum(), mode="same")
    out = {}
    for side in ("left", "right"):
        for name, (rest, amp) in DOF.items():
            if name == "head_pitch" and side == "right":
                continue
            sway = 0.8 * np.sin(2 * np.pi * rng.uniform(0.05, 0.2) * t + rng.uniform(0, 6.3))
            f = rng.uniform(0.5, 2.0)                     # gesture rate, Hz
            gesture = amp_scale * amp * rng.uniform(0.6, 1.0) * np.sin(2 * np.pi * f * t + rng.uniform(0, 6.3))
            key = name if name == "head_pitch" else f"{name}_{side}"
            out[key] = rest + sway + env * gesture
    return out


# ----------------------------------------------------------------------------
# forward kinematics: rotations -> 42 marker positions (world: X right, Y forward, Z up, mm)
# ----------------------------------------------------------------------------
def _sag(theta_deg):
    """Unit vector in the sagittal (Y, Z) plane at angle theta from +Y (forward)."""
    th = np.deg2rad(theta_deg)
    return np.column_stack([np.zeros_like(th), np.cos(th), np.sin(th)])


def markers_from_rotations(R):
    """N x 42 x 3 marker positions of one person in their own frame
    (facing +Y, seated, origin on the floor below the seat centre)."""
    n = R["head_pitch"].size
    M = np.zeros((n, 43, 3))                      # index 0 unused; markers 1..42
    one = np.ones(n)

    def put(j, xyz):
        M[:, j, :] = xyz

    def pt(x, y, z):
        return np.column_stack([x * one, y * one, z * one])

    # torso (rigid)
    put(1, pt(0, -90, 500)); put(2, pt(-100, 0, 470)); put(3, pt(100, 0, 470))
    put(4, pt(0, -90, 1130)); put(5, pt(0, 100, 1020))
    put(39, pt(0, -60, 1180)); put(40, pt(0, -100, 850))
    put(41, pt(-120, -90, 980)); put(42, pt(120, -90, 980))

    sh_c = {"left": pt(-180, 0, 1080), "right": pt(180, 0, 1080)}
    shoulder_mid = (sh_c["left"] + sh_c["right"]) / 2

    # head: centre 230 mm above the shoulder midpoint, tilted by head_pitch
    hp = np.deg2rad(R["head_pitch"])
    up = np.column_stack([np.zeros(n), np.sin(hp), np.cos(hp)])
    hc = shoulder_mid + 230 * up
    fwd = np.column_stack([np.zeros(n), np.cos(hp), -np.sin(hp)])
    put(6, hc + 90 * fwd); put(7, hc + pt(-75, 0, 0)); put(8, hc + pt(75, 0, 0))

    base = {"left": 9, "right": 24}
    for side, s in (("left", -1.0), ("right", 1.0)):
        b = base[side]
        S = sh_c[side]
        put(b + 6, S + pt(0, -40, 0))                 # shoulder back (15 / 30)
        put(b + 7, S + pt(0, 0, 40))                  # shoulder top  (16 / 31)

        # arm in a plane tilted out by the abduction angle
        abd = np.deg2rad(R[f"shoulder_abd_{side}"])
        phi_s = R[f"shoulder_flex_{side}"]
        phi_e = R[f"elbow_flex_{side}"]
        phi_w = R[f"wrist_flex_{side}"]

        def arm_dir(angle_from_down):
            a = np.deg2rad(angle_from_down)
            return np.column_stack([s * np.sin(abd), np.sin(a) * np.cos(abd), -np.cos(a) * np.cos(abd)])

        E = S + 300 * arm_dir(phi_s)
        W = E + 260 * arm_dir(phi_s + phi_e)
        H = W + 80 * arm_dir(phi_s + phi_e + phi_w)
        put(b + 1, E)                                 # elbow (10 / 25)
        put(b + 2, H)                                 # hand  (11 / 26)
        put(b + 3, S + 150 * arm_dir(phi_s) + pt(s * 40, 0, 0))   # upper arm (not used)
        put(b + 13, W + pt(-s * 25, 0, 0))           # wrist in  (22 / 37)
        put(b + 14, W + pt(s * 25, 0, 0))            # wrist out (23 / 38)

        # leg in the sagittal plane
        Hp = pt(s * 100, 0, 470)
        beta = R[f"thigh_elev_{side}"]
        K = Hp + 430 * _sag(beta)
        shank = _sag(180 + beta + R[f"knee_{side}"])  # interior knee angle
        A = K + 450 * shank
        toe_dir = _sag(180 + beta + R[f"knee_{side}"] - 180 - R[f"ankle_{side}"])
        T = A + 150 * toe_dir
        put(b + 4, K)                                 # knee  (13 / 28)
        put(b + 5, K + 225 * shank + pt(s * 30, 0, 0))  # shin (14 / 29)
        put(b + 8, Hp + 215 * _sag(beta) + pt(s * 40, 0, 0))  # thigh (17 / 32)
        put(b + 0, A)                                 # ankle (9 / 24)
        put(b + 9, T + pt(-s * 30, 0, 0))             # toes (18-20 / 33-35)
        put(b + 10, T)
        put(b + 11, T + pt(s * 30, 0, 0))
        put(b + 12, A - 60 * toe_dir)                 # heel (not used)
    return M[:, 1:, :]


def place_person(M, person):
    """Person 1 at the origin facing +Y; Person 2 facing -Y, 1.83 m away."""
    if person == 1:
        return M
    P = M.copy()
    P[:, :, 0] = -M[:, :, 0]
    P[:, :, 1] = FACING_DISTANCE_MM - M[:, :, 1]
    return P


def to_export_columns(M_world):
    """World (X, Y, Z-up) -> export columns (x = X, y = Z, z = -Y), N x 126."""
    x = M_world[:, :, 0]
    y = M_world[:, :, 2]
    z = -M_world[:, :, 1]
    return np.stack([x, y, z], axis=2).reshape(M_world.shape[0], -1)


def add_gaps(X, rng, n_gaps=6):
    """A few short gaps (0.1-0.5 s) in random markers, as in real optical data."""
    n = X.shape[0]
    for _ in range(n_gaps):
        m = rng.integers(0, 42)
        start = rng.integers(int(CALIB_S * FS), n - FS)
        length = rng.integers(FS // 10, FS // 2)
        X[start:start + length, 3 * m:3 * m + 3] = np.nan
    return X


# ----------------------------------------------------------------------------
# one recording pair (one dyad, one conversation)
# ----------------------------------------------------------------------------
def simulate_conversation(p_state, mean_dwell_s, amp_scale, conversation_s, seed, out_dir, stem):
    """Write the two people's marker files of one conversation and its hidden
    states. Returns the hidden-state shares during the conversation."""
    rng = np.random.default_rng(seed)
    total_s = CALIB_S + conversation_s + END_S
    n = int(round(total_s * FS))
    t = np.arange(n) / FS
    states = state_sequence(n, p_state, mean_dwell_s, FS, rng)
    calib = (t < CALIB_S) | (t >= total_s - END_S)        # nobody gestures here
    header = "\t".join(["Time", "Frame"] + [f"M{j:02d}_{MARKERS[j].split(' ')[0]}_{ax}"
                                            for j in range(1, 43) for ax in "XYZ"])
    for person in (1, 2):
        moving = person_moving(states, person) & ~calib
        R = rotations(moving, FS, rng, amp_scale[person - 1])
        M = place_person(markers_from_rotations(R), person)
        X = to_export_columns(M) + rng.normal(0, 0.5, (n, 126))       # marker jitter
        X = add_gaps(X, rng)
        data = np.column_stack([t, np.arange(1, n + 1), X])
        np.savetxt(out_dir / f"{stem}_person{person}_opt.txt.gz", data, delimiter="\t",
                   header=header, comments="", fmt=["%.4f", "%d"] + ["%.1f"] * 126)
    np.savetxt(out_dir / f"{stem}_hidden_states.csv.gz", np.column_stack([t, states]),
               delimiter=",", fmt=["%.4f", "%d"], comments="",
               header="time,state (1=Both Inactive, 2=Both Active, 3=Person 1 Active, 4=Person 2 Active)")
    conv = ~calib
    return np.bincount(states[conv], minlength=5)[1:] / conv.sum()


# ----------------------------------------------------------------------------
# many dyads
# ----------------------------------------------------------------------------
# What differs between dyads (each dyad's own "style", the SAME in both of its
# conversations, as two real people bring their own style to both):
#   - how long states usually last (mean dwell 1.5-3.0 s)
#   - how much each person moves when active (gesture size x 0.6-1.4)
#   - how often the dyad is in each state (drawn around the setting's shares)
# What differs between the conversations (made up, ILLUSTRATIVE ONLY):
#   - "conflict" shifts time from both-person states to one-person states.
# Two dyads (by default) get a conversation shorter than 180 s + margins, so
# the inclusion rule of the pipeline visibly excludes them.
CONFLICT_SHIFT = np.array([-0.05, -0.10, +0.10, +0.05])   # BI, BA, P1, P2


def dyad_traits(rng):
    base = rng.dirichlet(40 * SETTINGS["casual"])
    conflict = np.clip(base + CONFLICT_SHIFT, 0.03, None)
    return dict(mean_dwell_s=rng.uniform(1.5, 3.0),
                amp_scale=rng.uniform(0.6, 1.4, size=2),
                p={"casual": base, "conflict": conflict / conflict.sum()})


def simulate_many(out_dir, n_dyads=15, n_too_short=2, master_seed=2026):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(master_seed)
    too_short = set(rng.choice(np.arange(1, n_dyads + 1), size=n_too_short, replace=False).tolist())
    index = {"description": "SIMULATED dyads (illustrative only; no participant data)",
             "sampling_rate_hz": FS, "units": "mm", "master_seed": master_seed,
             "coordinates": "export columns x, y (vertical), z; analysis uses X = x, Y = -z, Z = y",
             "markers": {str(k): v for k, v in MARKERS.items()}, "dyads": {}}
    for d in range(1, n_dyads + 1):
        tr = dyad_traits(rng)
        name = f"simdyad{d:02d}"
        index["dyads"][name] = {"files": {}, "excluded_by_design": d in too_short}
        for c, cond in enumerate(("casual", "conflict")):
            conv_s = rng.uniform(150, 175) if d in too_short else rng.uniform(195, 240)
            stem = f"{name}_{cond}"
            share = simulate_conversation(tr["p"][cond], tr["mean_dwell_s"], tr["amp_scale"],
                                          conv_s, int(master_seed * 1000 + d * 10 + c), out_dir, stem)
            index["dyads"][name]["files"][cond] = {"Person 1": f"{stem}_person1_opt.txt.gz",
                                                   "Person 2": f"{stem}_person2_opt.txt.gz",
                                                   "hidden_states": f"{stem}_hidden_states.csv.gz"}
            index["dyads"][name][f"{cond}_hidden_shares"] = np.round(share, 4).tolist()
        print(f"  {name} written" + ("  (too short by design)" if d in too_short else ""), flush=True)
    (out_dir / "simulated_dyads.json").write_text(json.dumps(index, indent=1))
    return index


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Write simulated dyads in the export layout.")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent / "generated"))
    ap.add_argument("--n-dyads", type=int, default=15)
    ap.add_argument("--n-too-short", type=int, default=2)
    a = ap.parse_args()
    idx = simulate_many(a.out, a.n_dyads, a.n_too_short)
    n_ex = sum(v["excluded_by_design"] for v in idx["dyads"].values())
    print(f"{len(idx['dyads'])} simulated dyads written to {a.out} "
          f"({n_ex} too short by design, so {len(idx['dyads']) - n_ex} should be included)")
