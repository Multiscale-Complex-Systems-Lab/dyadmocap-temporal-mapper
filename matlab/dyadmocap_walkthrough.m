%% dyadmocap-temporal-mapper: MATLAB walkthrough
% This script runs the complete analysis pipeline of the study in MATLAB,
% from the raw marker files to the statistics and figures, on SIMULATED
% dyads (the study's recordings are not public). The code is the code that
% analysed the study data; only the input files differ. Results on simulated
% data are not findings.
%
% Open it in MATLAB and run it section by section (or right-click it in the
% Current Folder browser and choose "Open as Live Script"; if you save that as
% a .mlx file, clear all outputs before committing it).
%
% The same pipeline in Python, with a step-by-step explanation of each stage,
% is python/notebooks/dyadmocap_walkthrough.ipynb. The two versions give the
% same results: tools/compare_matlab_python.py checks it, table by table.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

%% 0. Setup
% Temporal Mapper (tmapper2) is an external dependency: clone it once,
%   git clone https://github.com/Multiscale-Complex-Systems-Lab/tmapper2.git
%   cd tmapper2 && git checkout v2.2
% and write its folder in dymo_config.ini (tmapper2_dir = ...), or add its
% tmapper_tools folder to the MATLAB path. Then, from this folder:
DYMO_setup;
cfg = DYMO_config();

%% 1. The data
% The simulated dyads are written once by the Python script
% data/simulated/simulate_dyad.py (15 dyads, 2 of them too short on purpose,
% so the inclusion rule keeps 13). From the repository folder:
%   python data/simulated/simulate_dyad.py
% (it needs Python with numpy; see environment.yml). To analyse your own data,
% point data_index in dymo_config.ini at an index of your recordings.
dyads = DYMO_dataIndex();
fprintf('%d dyads in the index %s\n', numel(dyads), cfg.dataIndex);

%% 2. The whole pipeline
% 33 stages (1-17: temporal mapper, subgraphs, cycles, node distances, graph
% metrics, correlations; 18-20: the mean path distance; 21-33: correlation
% bars, purple and icon figures, node size, the largest nodes).
% About 1 hour with the simulated data. Results go to cfg.resultsDir.
% To resume after an error at stage n: DYMO_runAll(n).
T = DYMO_runAll;

%% 3. A few results
% Every table is in <results>/<area>_Results_mednorm_180s/Tables, every figure
% in <results>/<area>_Results_mednorm_180s/Figures.
res = cfg.resultsDir;
tag = DYMO_runTag();
tab = @(area, name) readtable(fullfile(res, [area '_Results_' tag], 'Tables', [name '_' tag '.csv']));
fig = @(area, varargin) fullfile(res, [area '_Results_' tag], 'Figures', varargin{:});

% Graph metrics, Casual Chat vs Conflict (paired t-tests, bootstrap CI)
disp(tab('GraphMetrics_Piaredttest', 'GTKMAN_WhSubgCatsStat'))

% Mean path distance by state
disp(tab('GraphMetrics_Piaredttest', 'PathDistance_CasualVsConflict_ByState'))
figure; imshow(fig('GraphMetrics_Piaredttest', 'GraphMetrics_PairedTtest', ...
    'MeanPathDistance', 'BC_PathDistanceByState.png'));

% Node distances, eight panels with the state-pair icons
figure; imshow(fig('NodeDistance_Pairedttest', 'NodeDistance_PairedTtest', ...
    'EightPanel_Purple', 'NodeDistance_8Panel_Purple_Icons.png'));

% The largest node of each state: one long stay, or many returns?
disp(tab('GraphMetrics_Piaredttest', 'LargestNodeByState'))

%% 4. Compare with the Python version
% After the Python pipeline has also run (python -m dyadmocap.run_pipeline,
% from the python folder), from the repository folder:
%   python tools/compare_matlab_python.py
