# dyadmocap-temporal-mapper

Temporal Mapper analysis of dyadic motion capture: how two seated people's body movements are organised over a conversation, compared between a casual chat and a conflict conversation.

This repository holds the analysis code of the study, in Python and in MATLAB, each with one walkthrough that runs the whole pipeline. The study's recordings are not public, so the notebook runs on **simulated** dyads written by `data/simulated/simulate_dyad.py`. The code is the code that analysed the study data; only the input files differ. Results on simulated data are not findings.

> DRAFT for review. The repository is private until the review is complete; the licence and the citation file are drafts.

## What the pipeline does

| Stage | Module (`python/dyadmocap/`) | What it does |
|---|---|---|
| 1 | `run_pipeline_to_tm` | reads the marker files, trims them, applies the inclusion rule (at least 180 s), computes 11 joint angles per person, their velocity, the four behavioural states (Both Inactive, Both Active, Person 1 Active, Person 2 Active), and the Temporal Mapper graph of each recording; draws the per-dyad figures |
| 2 | `run_subgraph_highlight` | each graph drawn with one state highlighted at a time |
| 3 | `run_cycles` | cycles of every graph (length, winning state, Shannon entropy); paired t-tests and Spearman correlations between the two conversations |
| 4 | `run_stats_graph_nodedist` | graph metrics (whole graph and per state), node distances between states, mean path distance of each state (hubness); paired t-tests and Spearman correlations with bootstrap intervals |
| 5 | `run_later_analyses` | correlation bars (whole graph and per state, with pairwise tests), paired comparisons in the purple scheme, node-size distribution, node distances with state-pair icons, the largest nodes of each state (one stay or many returns) |

The stages run in the order of the MATLAB `DYMO_runAll.m`. The figures are the final set: whole-graph comparisons in purple, correlations as bar plots (only node distances as scatter plots), node distances in purple with state-pair icons. Older versions of some figures can still be drawn by setting `OLD_FIGURES = True` (Python) or `makeFigures = true` (MATLAB) in the script concerned; the tables do not change.

## Install

The code needs Python 3.11 and the packages in `environment.yml`, including **Temporal Mapper**, which is an external dependency: [tmapper-py](https://github.com/Multiscale-Complex-Systems-Lab/tmapper-py), version 0.2.0, installed from PyPI by the environment file. It is not copied into this repository.

With [Anaconda or Miniconda](https://docs.conda.io):

```
conda env create -f environment.yml
conda activate dyadmocap-tm
```

## Run

**The walkthrough notebook** (explains each step, then runs everything):

```
conda activate dyadmocap-tm
cd python/notebooks
jupyter lab
```

and open one of the three notebooks (each has a MATLAB script that does the same, see the table). The first run writes the simulated dyads (1–3 minutes, about 0.2 GB).

| Python notebook | MATLAB script | What it does | Statistics |
|---|---|---|---|
| `dyadmocap_one_dyad.ipynb` | `matlab/dyadmocap_one_dyad.m` | One dyad, step by step, up to its Temporal Mapper graphs and a table of their graph and cycle metrics | none |
| `dyadmocap_summary.ipynb` | `matlab/dyadmocap_summary.m` | The Temporal Mapper graph of every dyad, then one table of graph and cycle metrics per dyad and conversation | none |
| `dyadmocap_walkthrough.ipynb` | `matlab/dyadmocap_walkthrough.m` | The whole pipeline: one dyad step by step, then all dyads with the statistics and figures | yes |

**The whole pipeline as one command** (from the `python` folder):

```
python ../data/simulated/simulate_dyad.py      # once
python -m dyadmocap.run_pipeline
```

About 45–60 minutes on a laptop with the simulated data, most of it drawing the per-dyad figures. Tables and figures go to `outputs/results/mednorm_180s/`; each stage also saves what it printed there as a `*_Summary_*.txt` file. `python -m dyadmocap.run_pipeline 3` restarts from stage 3.

## Your own data

Copy `dymo_config.example.ini` to `dymo_config.ini` and set `data_index` (a JSON list of your dyads and their marker files; the format is in the example file) and `results_dir`. `dymo_config.ini` is ignored by git, so no local path is committed. Keep participant data and results outside the repository.

The marker files are expected in this layout: one tab-delimited text file per person and conversation, one header row, then time (s), frame, and x y z (mm) for 42 markers. The analysis settings (trimming, window, Temporal Mapper parameters) are all in `python/dyadmocap/dymo_settings.py`.

## Layout

```
environment.yml               Python environment (conda-forge + tmapper-py from PyPI)
dymo_config.example.ini       where the data are and where results go
data/simulated/               the simulator (its output is not committed)
python/dyadmocap/             the package: stage modules (run_*.py) and building blocks (dymo_*.py)
python/notebooks/             the three notebooks (committed with outputs cleared)
matlab/DYMO_setup.m           puts the MATLAB functions, stages and Temporal Mapper 2 on the path
matlab/DYMO_runAll.m          runs every MATLAB stage in order
matlab/dyadmocap_*.m          the three MATLAB scripts, as the notebooks (save as .mlx to use them as live scripts)
matlab/Functions/            the MATLAB functions
matlab/MainScripts/          the MATLAB stage scripts (one per analysis)
tools/compare_matlab_python.py  checks that the two versions give the same tables
LICENSE                      the licence (MIT)
CITATION.cff                 how to cite this code
```

## MATLAB version

`matlab/` holds the MATLAB version of the pipeline: it reads the same dataset index and `dymo_config.ini`, and runs the same analyses in 33 stages (1–17: temporal mapper, subgraphs, cycles, node distances, graph metrics and correlations; 18–20: the mean path distance; 21–33: the correlation bars, the purple and icon figures, the node-size distribution and the largest nodes).

It needs MATLAB (R2021a or later, with the Statistics and Machine Learning Toolbox) and **Temporal Mapper 2**, an external dependency that is not copied into this repository. Get it once, next to the repository folder (or set `tmapper2_dir` in `dymo_config.ini`):

```
git clone https://github.com/Multiscale-Complex-Systems-Lab/tmapper2.git
cd tmapper2
git checkout v2.2
```

(The analysis used commit 58ee193, which differs from v2.2 only in the toolbox's tests.) The simulated data are written by the Python script (`python data/simulated/simulate_dyad.py`, once; it needs Python with numpy). Then, in MATLAB:

```
cd <repository>/matlab
DYMO_setup
DYMO_runAll                 % every stage; DYMO_runAll(18) resumes at stage 18
```

or open `matlab/dyadmocap_walkthrough.m`, which explains and runs the same thing (several hours with the simulated data on a laptop; stages 1–5 alone, the graphs and the cycles, took about 1.5 hours). Results go to `outputs/matlab_results/` (set `matlab_results_dir` to change it). On Windows, keep that folder's path short (for example `C:\Users\<you>\dymo_results`): some figure paths inside it are over 150 characters, and Windows refuses paths over 260.

### Do the two versions agree?

After both have run on the same data:

```
python tools/compare_matlab_python.py
```

(from the repository folder) compares every table both versions wrote. Exact numbers must agree to the last digit written; bootstrap confidence limits, which come from different random number generators, must agree within 0.05 or 10 % of the interval's width. On the simulated data all 25 tables the two versions share agree.

## Licence and citation

The code is released under the MIT licence (`LICENSE`). If you use it, please cite it as described in `CITATION.cff`.

## Notes

The code was written by Patience Akatuhwera (Multiscale Complex Systems Lab, Michigan State University), with help from Claude (Anthropic, an AI assistant) in writing and porting code; the author reviewed the code and is responsible for it and for every result.
