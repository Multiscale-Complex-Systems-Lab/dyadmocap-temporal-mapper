%% ============ WHAT ARE THE BIGGEST NODES? ============
% The mean node size can be small even when a few nodes are very large: with
% thousands of nodes, one node of several thousand samples barely moves the
% mean if most other nodes hold a single time point (e.g. (1x4000 + 4000x1)/4001
% is slightly under 2). sum(nodesize) = N for every graph, so no time point is
% duplicated or lost.
%
% WHAT THIS SCRIPT ADDS
% Part 1 - the four largest nodes of each behavioural state, in each condition,
% with their span and the number of runs of consecutive time points ("visits").
% Part 2 - one dyad, both of its conversations, the largest node of each state,
% as a table and a raster figure.
%
% VISITS IS THE COLUMN THAT MATTERS. A large node with ONE visit is a single
% uninterrupted episode - a genuine long stay. A large node with many visits is
% the same velocity configuration revisited again and again. The two mean
% completely different things, and node size alone cannot tell them apart.
% Node size is RECURRENCE, not dwell time: a large node with many visits is a
% state the dyad returns to, not one it stays in.
%
% Output is a short table per state. No dyad is identified; the only per-dyad
% quantity reported is a node's share of its own recording, as a percentage.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('DYMO_files','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

Fs    = 50;    % recording rate, Hz - change here if a run uses another rate
topN  = 4;     % how many of the largest nodes to report per state

load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
cmap                = GTK_AllDyads_GraphData{first}.cmap;
numCategories       = numel(BehaviouralCategory);

conditions = {'Casual Chat', 'GTK'; 'Conflict', 'MAN'};
sets       = {GTK_AllDyads_GraphData, MAN_AllDyads_GraphData};
nC         = size(conditions,1);

%% ============ PART 1: THE FOUR LARGEST NODES OF EACH STATE ============
OutCond = strings(0,1);  OutCat  = strings(0,1);  OutRank = [];
OutSize = [];            OutSec  = [];            OutSpan = [];
OutBlk  = [];            OutPct  = [];

for k = 1:nC

    AllDyads = sets{k};
    allSize = [];  allCat = [];  allSpan = [];  allBlk = [];  allTot = [];

    for d = 1:numel(AllDyads)

        data = AllDyads{d};
        if isempty(data) || ~isstruct(data), continue; end

        s       = double(data.nodesize(:));
        nodeCat = findnodelabel(data.members, data.colorvar, 'labelmethod', 'mode');
        total   = sum(s);

        nNode = numel(data.members);
        span  = nan(nNode,1);
        blk   = nan(nNode,1);
        for i = 1:nNode
            m = sort(double(data.members{i}(:)));
            if isempty(m), continue; end
            span(i) = m(end) - m(1) + 1;
            blk(i)  = 1 + sum(diff(m) > 1);
        end

        allSize = [allSize; s];                       %#ok<AGROW>
        allCat  = [allCat;  double(nodeCat(:))];      %#ok<AGROW>
        allSpan = [allSpan; span];                    %#ok<AGROW>
        allBlk  = [allBlk;  blk];                     %#ok<AGROW>
        allTot  = [allTot;  repmat(total, nNode, 1)]; %#ok<AGROW>
    end

    fprintf('\n================ %s ================\n', conditions{k,1});

    for c = 1:numCategories

        idx = find(allCat == c);
        if isempty(idx), continue; end

        [~, ord] = sort(allSize(idx), 'descend');
        pick     = idx(ord(1:min(topN, numel(ord))));

        fprintf('\n%s  (largest %d nodes)\n', BehaviouralCategory{c}, numel(pick));
        fprintf('  %4s %10s %10s %10s %8s %10s\n', ...
            'rank', 'points', 'seconds', 'span (s)', 'visits', '% of rec');
        for j = 1:numel(pick)
            i = pick(j);
            fprintf('  %4d %10g %10.2f %10.2f %8g %10.1f\n', ...
                j, allSize(i), allSize(i)/Fs, allSpan(i)/Fs, allBlk(i), ...
                100*allSize(i)/allTot(i));

            OutCond(end+1,1) = string(conditions{k,1});        %#ok<SAGROW>
            OutCat(end+1,1)  = string(BehaviouralCategory{c}); %#ok<SAGROW>
            OutRank(end+1,1) = j;                              %#ok<SAGROW>
            OutSize(end+1,1) = allSize(i);                     %#ok<SAGROW>
            OutSec(end+1,1)  = allSize(i)/Fs;                  %#ok<SAGROW>
            OutSpan(end+1,1) = allSpan(i)/Fs;                  %#ok<SAGROW>
            OutBlk(end+1,1)  = allBlk(i);                      %#ok<SAGROW>
            OutPct(end+1,1)  = 100*allSize(i)/allTot(i);       %#ok<SAGROW>
        end
    end
end

TopNodes = table(OutCond, OutCat, OutRank, OutSize, OutSec, OutSpan, OutBlk, OutPct, ...
    'VariableNames', {'Condition','BehaviouralState','Rank','Size_points', ...
                      'Size_seconds','Span_seconds','Visits','PctOfRecording'});
TopNodes = DYMO_roundTable(TopNodes);
DYMO_writeTable(TopNodes, 'TopNodes.csv');
DYMO_writeTable(TopNodes, 'TopNodes.xlsx');
disp(TopNodes)

%% ====== PART 2: ONE DYAD, BOTH CONVERSATIONS, SIDE BY SIDE ======
% The comparison is casual chat against conflict, so BOTH conversations of the
% SAME dyad are shown. Using a different dyad in each column, or each state's
% largest node from wherever it happens to live, would not be a comparison.
% The dyad chosen is the one holding the overall largest node in casual chat,
% and the same dyad's conflict conversation is used beside it.
%
% The figure is rasters only; the visit counts in the table carry the rest of
% the information.
tic;
figureFolder = DYMO_figureFolder('GraphMetrics_PairedTtest','TopNodes');

pickD = 0; pickMax = -1;
for d = 1:numel(GTK_AllDyads_GraphData)
    data = GTK_AllDyads_GraphData{d};
    if isempty(data) || ~isstruct(data), continue; end
    if d > numel(MAN_AllDyads_GraphData), continue; end
    other = MAN_AllDyads_GraphData{d};
    if isempty(other) || ~isstruct(other), continue; end   % needs BOTH
    mx = max(double(data.nodesize));
    if mx > pickMax, pickMax = mx; pickD = d; end
end
if pickD == 0, error('No dyad has both conversations.'); end

VCond = strings(0,1);  VCat = strings(0,1);
VPts  = [];  VVis = [];  VMean = [];  VLong = [];  VPct = [];

fig = figure('Color','w');
for k = 1:nC
    data    = sets{k}{pickD};
    s       = double(data.nodesize(:));
    nodeCat = findnodelabel(data.members, data.colorvar, 'labelmethod', 'mode');
    durS    = sum(s) / Fs;

    for c = 1:numCategories

        idx = find(nodeCat == c);
        ax  = subplot(numCategories, nC, (c-1)*nC + k);
        if isempty(idx)
            axis(ax, 'off');
            continue
        end

        [~, j] = max(s(idx));
        m      = sort(double(data.members{idx(j)}(:)));
        t      = (m - 1) / Fs;

        brk  = find(diff(m) > 1);
        lens = [brk; numel(m)] - [1; brk+1] + 1;

        plot(ax, t, zeros(size(t)), '|', 'Color', cmap(c,:), ...
             'MarkerSize', 20, 'LineWidth', 1.5);
        % y = 0 sits low in the panel so the label has clear space above it
        xlim(ax, [0 durS]);  ylim(ax, [-1 3]);
        set(ax, 'YTick', []);
        text(ax, 0.015, 0.96, sprintf('%s - %d points, %d visits', ...
            BehaviouralCategory{c}, numel(m), numel(lens)), ...
            'Units','normalized', 'FontWeight','bold', 'FontSize', 22, ...
            'VerticalAlignment','top');
        if c == 1, title(ax, conditions{k,1}); end
        if c == numCategories, xlabel(ax, 'Time in the conversation (s)'); end
        box(ax, 'on');

        VCond(end+1,1) = string(conditions{k,1});        %#ok<SAGROW>
        VCat(end+1,1)  = string(BehaviouralCategory{c}); %#ok<SAGROW>
        VPts(end+1,1)  = numel(m);                       %#ok<SAGROW>
        VVis(end+1,1)  = numel(lens);                    %#ok<SAGROW>
        VMean(end+1,1) = numel(m)/numel(lens);           %#ok<SAGROW>
        VLong(end+1,1) = max(lens);                      %#ok<SAGROW>
        VPct(end+1,1)  = 100*numel(m)/sum(s);            %#ok<SAGROW>
    end
end

SavePublicationFigure('TopNode_Raster_BothConditions', fig, figureFolder, [25 16]);
close(fig);
toc;

LargestNodeByState = table(VCond, VCat, VPts, VVis, VMean, VLong, VPct, ...
    'VariableNames', {'Condition','BehaviouralState','TimePoints','Visits', ...
                      'MeanVisit_points','LongestVisit_points','PctOfRecording'});
LargestNodeByState = DYMO_roundTable(LargestNodeByState);
DYMO_writeTable(LargestNodeByState, 'LargestNodeByState.csv');
DYMO_writeTable(LargestNodeByState, 'LargestNodeByState.xlsx');

fprintf('\nOne dyad, both of its conversations, largest node of each state:\n');
disp(LargestNodeByState)

fprintf(['\nREAD THE VISITS COLUMN.\n' ...
         'Visits near 1 = one uninterrupted episode, so node size IS a dwell\n' ...
         'time. Visits in the hundreds spanning the whole recording = the same\n' ...
         'configuration revisited many times, so node size is RECURRENCE and\n' ...
         'the manuscript must say "returns to", not "stays in".\n\n']);
