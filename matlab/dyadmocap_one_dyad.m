%% dyadmocap-temporal-mapper: one dyad (MATLAB)
% This script follows ONE dyad through the analysis: loading, skeleton, joint
% angles, velocity, behavioural states and the Temporal Mapper graph. It ends
% with a table of the graph's main graph and cycle metrics for the two
% conversations. It does no statistics.
%
% It uses SIMULATED data, because the study's recordings are not public. The
% code is the code that analysed the study data; only the input files differ.
% The numbers describe the simulation only; they are not findings about real
% conversations.
%
% The same in Python: python/notebooks/dyadmocap_one_dyad.ipynb. The full
% analysis with statistics: dyadmocap_walkthrough.m.
%
% Open it in MATLAB and run it section by section (or right-click it in the
% Current Folder browser and choose "Open as Live Script"; if you save that as
% a .mlx file, clear all outputs before committing it).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

%% 0. Setup
% Temporal Mapper (tmapper2) is an external dependency (see the README).
% From this folder:
DYMO_setup;
cfg = DYMO_config();

%% 1. The data, and the dyad to follow
% The simulated dyads are written once by the Python script
% data/simulated/simulate_dyad.py (15 dyads, 2 of them too short on purpose).
dyads = DYMO_dataIndex();                 % sorted: dyad number d = position here
EXAMPLE = 'simdyad01';                    % the dyad to follow (change it here)
d = find(strcmp(dyads, EXAMPLE));
fprintf('%d dyads in the index; following %s (dyad %d)\n', numel(dyads), EXAMPLE, d);

%% 2. Loading, angles, velocity, states and the Temporal Mapper graph
% The TM stages do every step for every dyad and both conversations
% (GTK = casual chat, MAN = conflict), and save each dyad's figures:
%   1. drop the first 25 s (calibration) and the last 5 s of each file;
%   2. a common, centred window of equal length in both conversations (3 s margin);
%   3. fill short gaps by linear interpolation;
%   4. include a dyad only if every recording keeps at least 180 s;
%   5. analyse the first 180 s; 11 joint angles per person -> velocity (22 columns);
%   6. the four behavioural states (median rule);
%   7. the Temporal Mapper graph (k = 5, dmap = 3, texclude = 3 samples).
% Stages 3-5 then colour each state on the graph and find the graph's cycles.
% About 1.5 hours with the simulated data on a laptop (stage 5, the cycles,
% takes about 45 minutes of it).
% If these stages have already run (for example in another of the three
% scripts), skip this line: the sections below read what they saved.
DYMO_runAll(1, 5);

%% 3. The skeleton (frame 1)
% Person 1 blue, Person 2 red.
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_Skeleton_Plot.png']);

%% 4. Joint angles
% Eleven joint angles per person, each between 0 and 180 degrees, from vectors
% between markers (green = first vector, magenta = second). The velocity is
% the change of each angle per second.
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_Elbow_Angles_Skeleton.png']);
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_All_Angles_Overview.png']);

%% 5. Behavioural states
% A person is Active when their median-normalised activity is above their own
% median. Together: Both Inactive (black), Both Active (green), Person 1
% Active (blue), Person 2 Active (red).
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_TimePointCategoryBars.png']);

%% 6. The Temporal Mapper graph
% Each node is coloured by the state most of its moments carry. The distance
% matrix shows how similar every pair of moments is.
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_FourColorGraph.png']);
showFigure(cfg, ['MAN_Dyad_' num2str(d) '_FourColorGraph.png']);
showFigure(cfg, ['GTK_Dyad_' num2str(d) '_DistanceMatrix.png']);

%% 7. Graph and cycle metrics of this dyad
% * Number of nodes: how many movement states the graph has.
% * Node size: the mean number of time points per node.
% * Edge density: the share of possible transitions present.
% * Mean path distance: the average number of steps from a node to all others
%   (and from all others to it), for the whole graph and the nodes of each state.
% * Cycles: loops back to the same node: how many, their mean length, and how
%   many states a loop passes through (Shannon entropy; 0 = one state only).
T = DYMO_graphCycleTable();
one = T(T.Dyad == EXAMPLE, :);            % two rows: Casual chat, Conflict
vals = one{:, 3:end}';
metrics = T.Properties.VariableNames(3:end)';
oneDyad = array2table(vals, 'RowNames', metrics, ...
    'VariableNames', {'Casual chat (GTK)', 'Conflict (MAN)'});
disp(oneDyad)
writetable(oneDyad, fullfile(cfg.resultsDir, ['OneDyad_GraphCycleMetrics_' EXAMPLE '.csv']), ...
    'WriteRowNames', true);

%% Where everything is
% The figures are under the results folder (cfg.resultsDir), in the TM_GTK and
% TM_MAN results folders; the table is OneDyad_GraphCycleMetrics_<dyad>.csv in
% the results folder.

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
