"""
dymo_settings.py - every setting of the Python pipeline, in one place.

This is the Python counterpart of the SETTINGS block at the top of
MainScripts/TM/GTK/GTK_TM_26June26.m plus DYMO_runTag.m: the median-normalised
analysis with a 180 s window, as reported.

Change a setting HERE only, never inside the other files, so that one file
always says what analysis the code computes.

The dyads and their files come from a dataset index and a config file
(see below).

Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
assistant). The author reviewed the code and is responsible for it.
"""

# ---------------------------------------------------------------------------
# Which analysis
# ---------------------------------------------------------------------------
PY_TAG = "mednorm_180s"     # run tag: names the results folder and every table

# ---------------------------------------------------------------------------
# Where things are
#   DATA_INDEX  : a JSON file listing the dyads and their marker files (the
#                 format written by data/simulated/simulate_dyad.py);
#   PY_RESULTS_DIR : where every table and figure is written.
# Both default to the simulated data and to outputs/ in this repository, and
# can be changed in dymo_config.ini in the repository folder (copy
# dymo_config.example.ini; dymo_config.ini is git-ignored). Use the config
# file for real data, so that no
# path is ever committed, and keep real results outside the repository.
# ---------------------------------------------------------------------------
import configparser
import json
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.dirname(os.path.dirname(_HERE))     # python/dyadmocap -> repository
_cfg = configparser.ConfigParser(interpolation=None)
_cfg.read(os.path.join(_REPO, "dymo_config.ini"), encoding="utf-8")
_paths = dict(_cfg["paths"]) if _cfg.has_section("paths") else {}

DATA_INDEX = (_paths.get("data_index", "").strip()
              or os.path.join(_REPO, "data", "simulated", "generated", "simulated_dyads.json"))
PY_RESULTS_DIR = (_paths.get("results_dir", "").strip()
                  or os.path.join(_REPO, "outputs", "results"))


def load_index():
    """The dataset index: dyads, their files per condition and person."""
    if not os.path.isfile(DATA_INDEX):
        raise FileNotFoundError(
            "Dataset index not found: %s\nFor the simulated data run first:  "
            "python data/simulated/simulate_dyad.py" % DATA_INDEX)
    with open(DATA_INDEX, encoding="utf-8") as f:
        return json.load(f)


# ---------------------------------------------------------------------------
# Recordings
# ---------------------------------------------------------------------------
GROUPS    = ["GTK", "MAN"]   # GTK = Casual Chat, MAN = Conflict
SUBS      = [1, 2]           # Person 1, Person 2
# how the two groups are named in the dataset index
GROUP_KEYS = {"GTK": "casual", "MAN": "conflict"}
N_COLUMNS = 128              # numeric columns in each marker file (time, frame, 42 x xyz)

# ---------------------------------------------------------------------------
# Trimming and inclusion (FindGTKMANTimes.m, GTK_TM_26June26.m)
# ---------------------------------------------------------------------------
TRIM_START_SEC = 25     # calibration removed from the start of every file
TRIM_END_SEC   = 5      # end transients removed from the end of every file
MARGIN_SEC     = 3      # trimmed from both ends of the common GTK/MAN window
MIN_STABLE_SEC = 180    # keep a recording only if its stable window is >= 180 s
EXPECTED_DYADS = None   # None = no check; or the number of dyads expected to pass

# ---------------------------------------------------------------------------
# Uniform analysis window
# ---------------------------------------------------------------------------
UNIFORM_WINDOW_SEC = 180      # 180 s = 9,000 samples at 50 Hz
UNIFORM_WINDOW_POS = "first"  # 'first', 'centre' or 'last' of the stable window
# False (the reported analysis): every recording is cut to the SAME length,
# 180 s or the shortest kept recording if that is shorter.
# True: each dyad is cut to its OWN length, up to 180 s, so a shorter dyad
# keeps all of its common window. Leave False for the reported analysis.
CUT_EACH_TO_OWN_LENGTH = False

# ---------------------------------------------------------------------------
# Later stages (not used yet by stage 1; listed so the analysis is defined
# in one place)
# ---------------------------------------------------------------------------
CATEGORY_NORMALIZATION = "median"   # |v| / median(|v|) per joint
# What feeds the temporal mapper graph (graphInputVelocity.m):
# 'zscore' (the reported analysis: signed velocity, z-scored per joint),
# 'median' or 'abszscore'. Change PY_TAG too if you change this, so the
# results of different inputs never share a folder.
GRAPH_NORMALIZATION = "zscore"
THRESHOLD_METHOD       = "median"   # per person, per recording
K        = 5                        # k nearest neighbours
DMAP     = 3                        # filtergraph compression distance
TEXCLUDE = 3                        # temporal exclusion, in SAMPLES
