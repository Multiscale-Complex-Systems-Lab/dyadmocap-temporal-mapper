%% dyadmocap-temporal-mapper: summary of all dyads (MATLAB)
% This script builds the Temporal Mapper graph of every dyad in both
% conversations, shows the graphs, and then summarises the main graph and
% cycle metrics in one table. It does no statistics.
%
% It uses SIMULATED data, because the study's recordings are not public. The
% code is the code that analysed the study data; only the input files differ.
% The numbers describe the simulation only; they are not findings about real
% conversations.
%
% The same in Python: python/notebooks/dyadmocap_summary.ipynb. Each step is
% explained in dyadmocap_one_dyad.m; the full analysis with statistics is
% dyadmocap_walkthrough.m.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

%% 0. Setup
% Temporal Mapper (tmapper2) is an external dependency (see the README).
% From this folder:
DYMO_setup;
cfg = DYMO_config();
dyads = DYMO_dataIndex();
fprintf('%d dyads in the index\n', numel(dyads));

%% 1. Temporal Mapper graph of every dyad, and its cycles
% For each dyad and conversation: loading and trimming (a dyad is included
% only if every recording keeps at least 180 s), 11 joint angles per person ->
% velocity (22 columns) -> the four behavioural states (median rule) -> the
% Temporal Mapper graph (k = 5, dmap = 3, texclude = 3 samples). Stages 3-5
% then colour each state on the graph and find the graph's cycles.
% About 1.5 hours with the simulated data on a laptop (stage 5, the cycles,
% takes about 45 minutes of it).
% If these stages have already run (for example in another of the three
% scripts), skip this line: the sections below read what they saved.
DYMO_runAll(1, 5);

%% 2. The graphs: casual chat left, conflict right
% Each node is coloured by the state most of its moments carry: Both Inactive
% black, Both Active green, Person 1 Active blue, Person 2 Active red.
T = DYMO_graphCycleTable();               % also tells which dyads are included
included = unique(T.Dyad, 'stable');
fig = figure('Color', 'w', 'Position', [50 50 900 300 * numel(included)]);
tiledlayout(numel(included), 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for i = 1:numel(included)
    d = find(strcmp(dyads, included(i)));
    for g = ["GTK", "MAN"]
        nexttile;
        f = dir(fullfile(cfg.resultsDir, '**', g + "_Dyad_" + d + "_FourColorGraph.png"));
        if ~isempty(f)
            image(imread(fullfile(f(1).folder, f(1).name)));
        end
        axis image off
        if g == "GTK", name = "Casual chat"; else, name = "Conflict"; end
        title(included(i) + ", " + name, 'Interpreter', 'none');
    end
end

%% 3. Graph and cycle metrics of every dyad
% * Number of nodes: how many movement states the graph has.
% * Node size: the mean number of time points per node.
% * Edge density: the share of possible transitions present.
% * Mean path distance: the average number of steps from a node to all others
%   (and from all others to it), for the whole graph and the nodes of each state.
% * Cycles: loops back to the same node: how many, their mean length, and how
%   many states a loop passes through (Shannon entropy; 0 = one state only).
% One row per dyad and conversation. No statistics.
disp(T)
writetable(T, fullfile(cfg.resultsDir, ['Summary_GraphCycleMetrics_' DYMO_runTag() '.csv']));

%% Where everything is
% The graphs are under the results folder (cfg.resultsDir), in the TM_GTK and
% TM_MAN results folders; the table is Summary_GraphCycleMetrics_<tag>.csv in
% the results folder.
