function T = DYMO_graphCycleMetrics(AllDyads, Cycles, Vis, dyadNames, conversation)
%DYMO_GRAPHCYCLEMETRICS  The main graph and cycle metrics of every dyad's TM
%graph in one conversation, as one table. No statistics.
%
%   T = DYMO_graphCycleMetrics(GTK_AllDyads_GraphData, GTKCycles, GTKVis, dyadNames, "Casual chat")
%
% INPUT
%   AllDyads     : the TM graphs of one conversation (GTK_AllDyads_GraphData
%                  or MAN_AllDyads_GraphData, saved by the TM stage)
%   Cycles, Vis  : the cycles of the same graphs (GTKCycles, GTKVis or
%                  MANCycles, MANVis, saved by Cycles_WinShannon_03July)
%   dyadNames    : the dyad names, in the order of AllDyads (DYMO_dataIndex)
%   conversation : the text for the Conversation column
%
% OUTPUT
%   One row per dyad with a graph (excluded dyads are left out). The columns
%   are the same as the table of the Python notebooks:
%     Number of nodes, Node size (mean time points), Edge density,
%     Mean path distance (whole graph, and for the nodes of each state),
%     Cycle count, Cycle mean length, Cycle entropy (mean)
%
% Every number comes from a function the pipeline already uses:
%   graphStatsWhole          number of nodes, node size, edge density
%   nodeClosenessByCategory  mean path distance (per state; and, with every
%                            node given the same label, for the whole graph)
%   wholeGraphCycleMetrics   cycle count, mean length, mean entropy
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

S = graphStatsWhole(AllDyads);
C = wholeGraphCycleMetrics(Cycles, Vis);
mpdState = nodeClosenessByCategory(AllDyads, 4);

% whole graph: the same function, with every node in one category
OneLabel = AllDyads;
for d = 1:numel(OneLabel)
    if ~isempty(OneLabel{d}) && isstruct(OneLabel{d})
        OneLabel{d}.colorvar = ones(size(OneLabel{d}.colorvar));
    end
end
mpdWhole = nodeClosenessByCategory(OneLabel, 1);

keep = find(~cellfun(@isempty, AllDyads(:)));
n = numel(keep);
T = table(string(dyadNames(keep)), repmat(string(conversation), n, 1), ...
    S.numNodes(keep), S.nodesizes(keep), S.density(keep), mpdWhole(keep, 1), ...
    mpdState(keep, 1), mpdState(keep, 2), mpdState(keep, 3), mpdState(keep, 4), ...
    C.CycleCount(keep), C.CycleLenMean(keep), C.meanEntropy(keep), ...
    'VariableNames', {'Dyad', 'Conversation', ...
    'Number of nodes', 'Node size (mean time points)', 'Edge density', 'Mean path distance', ...
    'Mean path distance, Both Inactive', 'Mean path distance, Both Active', ...
    'Mean path distance, Person 1 Active', 'Mean path distance, Person 2 Active', ...
    'Cycle count', 'Cycle mean length', 'Cycle entropy (mean)'});
end
