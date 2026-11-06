%% dyadmocap-temporal-mapper: MATLAB walkthrough
% This script runs the complete analysis pipeline of the study in MATLAB,
% from the raw marker files to the statistics and figures, on SIMULATED
% dyads (the study's recordings are not public). The code is the code that
% analysed the study data; only the input files differ. Results on simulated
% data are not findings.
%
% Part A follows one example dyad through every step, up to its Temporal
% Mapper graphs and a table of their graph and cycle metrics (as
% dyadmocap_one_dyad.m). Part B runs the rest of the pipeline on all dyads:
% the statistics and figures.
%
% Open it in MATLAB and run it section by section (or right-click it in the
% Current Folder browser and choose "Open as Live Script"; if you save that as
% a .mlx file, clear all outputs before committing it).
%
% The same pipeline in Python is python/notebooks/dyadmocap_walkthrough.ipynb.
% The two versions give the same results: tools/compare_matlab_python.py
% checks it, table by table.
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

%% Part A. One dyad, step by step
EXAMPLE = 'simdyad01';                    % the example dyad (change it here)
d = find(strcmp(dyads, EXAMPLE));

%% A1-A5. Loading, angles, velocity, states and the Temporal Mapper graph
% Stages 1-5 of the pipeline, for every dyad and both conversations
% (GTK = casual chat, MAN = conflict):
%   1. drop the first 25 s (calibration) and the last 5 s of each file;
%   2. a common, centred window of equal length in both conversations (3 s margin);
%   3. fill short gaps by linear interpolation;
%   4. include a dyad only if every recording keeps at least 180 s;
%   5. analyse the first 180 s; 11 joint angles per person -> velocity (22 columns);
%   6. the four behavioural states (median rule);
%   7. the Temporal Mapper graph (k = 5, dmap = 3, texclude = 3 samples);
% then the state colouring of each graph (subgraphs) and the graph's cycles.
% About 1.5 hours with the simulated data on a laptop (stage 5, the cycles,
% takes about 45 minutes of it).
% If these stages have already run (for example in another of the three
% scripts), skip this line: the sections below read what they saved.
DYMO_runAll(1, 5);

% the example dyad's figures
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_Skeleton_Plot.png']);          % skeleton, frame 1
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_Elbow_Angles_Skeleton.png']);  % angle vectors
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_All_Angles_Overview.png']);    % the 11 angles
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_TimePointCategoryBars.png']);  % time in each state
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_FourColorGraph.png']);         % TM graph, casual chat
showFigure(cfg, ['MAN_Dyad_' num2str(d) '_FourColorGraph.png']);         % TM graph, conflict
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_DistanceMatrix.png']);         % distance matrix

%% A6. Graph and cycle metrics of the example dyad (no statistics)
G = DYMO_graphCycleTable();
one = G(G.Dyad == EXAMPLE, :);            % two rows: Casual chat, Conflict
disp(array2table(one{:, 3:end}', 'RowNames', G.Properties.VariableNames(3:end)', ...
    'VariableNames', {'Casual chat (GTK)', 'Conflict (MAN)'}))

%% Part B. All dyads: the rest of the pipeline
% Stages 6-33 (node distances, graph metrics, correlations, cycle statistics;
% the mean path distance; correlation bars, purple and icon figures, node size,
% the largest nodes).
% To resume after an error at stage n: DYMO_runAll(n).
T = DYMO_runAll(6);                       % B1

%% B2. A few results
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

%% B3. Compare with the Python version
% After the Python pipeline has also run (python -m dyadmocap.run_pipeline,
% from the python folder), from the repository folder:
%   python tools/compare_matlab_python.py

%% ------------------------------------------------------------------
function showFigure(cfg, fileName)
% show a saved PNG figure of the pipeline, found by name under the results folder
f = dir(fullfile(cfg.resultsDir, '**', fileName));
if isempty(f)
    warning('Figure not found under %s: %s', cfg.resultsDir, fileName);
    return
end
figure('Color', 'w');
image(imread(fullfile(f(1).folder, f(1).name)));
axis image off
title(strrep(fileName, '_', ' '));
end
