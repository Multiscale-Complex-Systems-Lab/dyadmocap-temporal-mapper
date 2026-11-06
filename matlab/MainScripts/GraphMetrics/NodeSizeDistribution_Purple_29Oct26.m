%% ================== HOW BIG ARE THE NODES? ==================
% `nodesizes` as reported is mean(nodesize), and mean(nodesize) = N/numNodes
% exactly, because every analysed sample belongs to exactly one node. With a
% floor of 1, a mean near 2 forces most NODES to hold one or two samples.
%
% But the share of NODES that are singletons is not the share of TIME in
% singletons. If the distribution has a heavy tail, a small minority of large
% nodes can hold a large part of the recording, and the mean hides this because
% in averaging a node holding 4,000 samples counts the same as a node holding 1.
%
% WHAT IS COMPUTED
%   1. % of TIME in size-1 nodes: sum(s(s==1))/sum(s). How much of the
%      recording really is uncollected time points.
%   2. The binned table and the left/right figure panels: what share of nodes,
%      and what share of time, sits in nodes of size 1, 2-4, 5-9, 10-49 and
%      50+. This is the "actual time spent in nodes of different sizes" view,
%      and it is the robust one.
%   3. Frame-weighted mean node size, sum(s.^2)/sum(s): the size of the node an
%      average TIME POINT sits in. CAUTION - this is dominated by the few
%      largest nodes, so it is quoted for intuition and NOT used as a result,
%      and a difference between conditions in this statistic is NOT a finding.
% With a median of 1 and a heavy tail, `nodesizes` is better described as
% COMPRESSION, N/numNodes, than as "average node size".
%
% SCOPE
% Descriptive only. No test, no p-value, no condition comparison - the paired
% comparison of node size is in GTK_MAN_WholeStats_Pairedttest. Output is
% aggregate over all nodes of all dyads. The tables are displayed, not written.
%
% Colours: Casual Chat solid purple, Conflict light purple
% (DYMO_conditionColorsPurple, the colours for figures without states).
% Figures go to folders ending in _Purple.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('DYMO_files','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');

sets  = {GTK_AllDyads_GraphData, MAN_AllDyads_GraphData};
names = {'Casual Chat', 'Conflict'};
nC    = numel(sets);

% bin edges for the size bands, last band is open-ended
edges    = [1 2 5 10 50 Inf];
bandName = {'1', '2-4', '5-9', '10-49', '50+'};
nB       = numel(bandName);

Condition    = strings(nC,1);   nDyads        = nan(nC,1);
nNodesTot    = nan(nC,1);       nSamples      = nan(nC,1);
MeanSize     = nan(nC,1);       MedianSize    = nan(nC,1);
MaxSize      = nan(nC,1);       PctNodesSize1 = nan(nC,1);
PctTimeSize1 = nan(nC,1);       FrameWtMean   = nan(nC,1);

BandCond     = strings(nC*nB,1);   BandLabel   = strings(nC*nB,1);
BandPctNodes = nan(nC*nB,1);       BandPctTime = nan(nC*nB,1);
row = 0;

sAll        = cell(nC,1);        % the pooled node sizes, kept for the figures
PctNodesMat = nan(nB, nC);       % bands x conditions, for the bar panels
PctTimeMat  = nan(nB, nC);

for q = 1:nC

    AllDyads = sets{q};
    s  = [];
    nd = 0;
    for d = 1:numel(AllDyads)
        data = AllDyads{d};
        if isempty(data) || ~isstruct(data), continue; end
        s  = [s; double(data.nodesize(:))]; %#ok<AGROW>
        nd = nd + 1;
    end

    if isempty(s)
        warning('NodeSizeDistribution:noData', 'No nodes found for %s.', names{q});
        continue
    end
    sAll{q} = s;

    Condition(q)     = string(names{q});
    nDyads(q)        = nd;
    nNodesTot(q)     = numel(s);
    nSamples(q)      = sum(s);
    MeanSize(q)      = mean(s);                 % = N / numNodes
    MedianSize(q)    = median(s);
    MaxSize(q)       = max(s);
    PctNodesSize1(q) = 100 * mean(s == 1);
    PctTimeSize1(q)  = 100 * sum(s(s == 1)) / sum(s);
    FrameWtMean(q)   = sum(s.^2) / sum(s);      % intuition only - see header

    fprintf('\n%s: %d dyads, %d nodes, %d samples\n', ...
        names{q}, nd, numel(s), sum(s));
    fprintf('  mean node size (= N/numNodes)   %.3f\n', MeanSize(q));
    fprintf('  median %g,  max %g\n', MedianSize(q), MaxSize(q));
    fprintf('  %% of NODES of size 1            %.1f\n', PctNodesSize1(q));
    fprintf('  %% of TIME in size-1 nodes       %.1f\n', PctTimeSize1(q));
    fprintf('  frame-weighted mean node size   %.3f   (tail-dominated)\n', ...
        FrameWtMean(q));

    fprintf('  where the time actually sits:\n');
    fprintf('    %-7s %8s %8s\n', 'size', '%nodes', '%time');
    for b = 1:nB
        in  = s >= edges(b) & s < edges(b+1);
        row = row + 1;
        BandCond(row)     = string(names{q});
        BandLabel(row)    = string(bandName{b});
        BandPctNodes(row) = 100 * sum(in) / numel(s);
        BandPctTime(row)  = 100 * sum(s(in)) / sum(s);
        PctNodesMat(b,q)  = BandPctNodes(row);
        PctTimeMat(b,q)   = BandPctTime(row);
        fprintf('    %-7s %8.1f %8.1f\n', bandName{b}, ...
            BandPctNodes(row), BandPctTime(row));
    end
end

%% ==================== TABLES ====================
NodeSizeSummary = table(Condition, nDyads, nNodesTot, nSamples, MeanSize, ...
    MedianSize, MaxSize, PctNodesSize1, PctTimeSize1, FrameWtMean, ...
    'VariableNames', {'Condition','N_dyads','N_nodes','N_samples', ...
                      'MeanNodeSize','MedianNodeSize','MaxNodeSize', ...
                      'PctNodes_Size1','PctTime_Size1','FrameWeightedMeanSize'});

NodeSizeBands = table(BandCond, BandLabel, BandPctNodes, BandPctTime, ...
    'VariableNames', {'Condition','NodeSizeBand','PctOfNodes','PctOfTime'});

NodeSizeSummary = DYMO_roundTable(NodeSizeSummary);
NodeSizeBands   = DYMO_roundTable(NodeSizeBands);

% (not written) DYMO_writeTable(NodeSizeSummary, 'NodeSizeSummary.csv');
% (not written) DYMO_writeTable(NodeSizeSummary, 'NodeSizeSummary.xlsx');
% (not written) DYMO_writeTable(NodeSizeBands,   'NodeSizeBands.csv');
% (not written) DYMO_writeTable(NodeSizeBands,   'NodeSizeBands.xlsx');

disp(NodeSizeSummary)
disp(NodeSizeBands)

%% ==================== FIGURES ====================
% Two figures, plus the condition key as its own figure, following the
% convention of the other GraphMetrics scripts (result figures carry no
% legend; the key is saved once).
%
% Figure 1 has two panels: the SAME bands, counted by nodes on the left and by
% time on the right. The contrast between the two panels is the point, so they
% share a 0-100 % axis and must not be rescaled independently.
tic;
figureFolder = DYMO_figureFolder('GraphMetrics_PairedTtest', 'NodeSizeDistribution_Purple');
C            = DYMO_conditionColorsPurple();

figLegend = plotLegendFigure({'Casual Chat','Conflict'}, C, 'Condition');
SavePublicationFigure('ConditionLegend', figLegend, figureFolder, [7 5]);   % narrower key
close(figLegend);

% ---- Figure 1: share of nodes vs share of time, by node size band ----
fig = figure('Color','w');

ax1 = subplot(1,2,1);
b1  = bar(ax1, PctNodesMat, 'grouped');
for q = 1:nC, b1(q).FaceColor = C(q,:); end
set(ax1, 'XTick', 1:nB, 'XTickLabel', bandName);
xlabel(ax1, 'Node size (No. of time points)');
ylabel(ax1, 'Percent of all nodes');
title(ax1, 'Share of nodes');
ylim(ax1, [0 100]);
box(ax1, 'on');

ax2 = subplot(1,2,2);
b2  = bar(ax2, PctTimeMat, 'grouped');
for q = 1:nC, b2(q).FaceColor = C(q,:); end
set(ax2, 'XTick', 1:nB, 'XTickLabel', bandName);
xlabel(ax2, 'Node size (No. of time points)');
ylabel(ax2, 'Percent of recording time');
title(ax2, 'Share of recording time');
ylim(ax2, [0 100]);
box(ax2, 'on');

SavePublicationFigure('NodeSize_NodesVsTime', fig, figureFolder, [25 16]);
close(fig);

% ---- Figure 2: the node size distribution itself ----
% Log-spaced bins and log axes, because the range is 1 to over 4,000 and a
% linear histogram of this distribution is a single bar at 1 and nothing else.
% Drawn as outlines rather than filled bars so the two conditions can be
% compared where they overlap.
maxS = max([max(sAll{1}) max(sAll{2})]);
ed   = unique([1, 10.^(0 : 0.1 : ceil(log10(maxS)))]);

fig = figure('Color','w');
ax  = axes(fig);
hold(ax, 'on');
for q = 1:nC
    cnt = histcounts(sAll{q}, ed);
    stairs(ax, ed(1:end-1), cnt, 'LineWidth', 3, 'Color', C(q,:));
end
hold(ax, 'off');
set(ax, 'XScale', 'log', 'YScale', 'log');
xlabel(ax, 'Node size (No. of time points)');
ylabel(ax, 'Number of nodes');
title(ax, 'Node size distribution');
xlim(ax, [1 maxS]);
box(ax, 'on');

SavePublicationFigure('NodeSize_Histogram', fig, figureFolder, [16 13]);
close(fig);
toc;

fprintf(['\nFigure 1 (NodeSize_NodesVsTime) is the answer: the same size bands\n' ...
         'counted by nodes on the left and by time on the right. Most nodes are\n' ...
         'single time points; most of the recording is not.\n' ...
         'Figure 2 (NodeSize_Histogram) is the distribution itself, log-log.\n\n']);
