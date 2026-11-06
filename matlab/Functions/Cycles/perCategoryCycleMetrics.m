function M = perCategoryCycleMetrics(Cycles, Vis, numCats, absentValue)
%PERCATEGORYCYCLEMETRICS  Cycle metrics per behavioural (winner) category.
%
%   M = perCategoryCycleMetrics(GTKCycles, GTKVis)
%   M = perCategoryCycleMetrics(GTKCycles, GTKVis, numCats, absentValue)
%
% Used by EntroWinner_Cycle_Category_Visualization and
% EntroWinner_Cycle_Cat_SpCorr.
%
% Output fields (numDyads-by-numCats unless noted)
%   CycleCount          number of cycles whose winner category is c
%   winnerProp          proportion of cycles whose winner category is c
%   CycleLenMean        mean length of the cycles won by category c
%   meanEntropy         mean Shannon entropy of the cycles won by c
%   cycleDensity        (#cycles won by c) / (#cycles)  -- note: this is
%                       the same number as winnerProp whenever a dyad has
%                       at least one cycle, so it is a SHARE, not a density,
%                       and is not comparable with the whole-graph
%                       cycleDensity. Use cyclesPerNode for that.
%   nodesInCat          number of nodes carrying category c
%   cyclesPerNode       (#cycles won by c) / (#nodes carrying c)
%                       The whole-graph measure is total cycles / total nodes,
%                       so this is the same formula applied locally and the
%                       two can be read on one axis.
%   cycleCategoryCounts mean node-category composition of the cycles
%   CycleModeCat        (cell, numDyads-by-1) winner category per cycle
%
% absentValue (default NaN): value of CycleLenMean / meanEntropy for a
% category that wins NO cycle in a dyad. 0 would average "no cycles" in as
% "length 0 / entropy 0"; pass 0 only to reproduce that convention.
%
% Dyads without data are NaN in every field (never 0, which would be paired
% against the other condition's real values).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(numCats)
    first = find(~cellfun(@isempty, Vis), 1);
    numCats = numel(Vis{first}.BehaviouralCategory);
end
if nargin < 4
    absentValue = NaN;
end

n = numel(Vis);

M.CycleCount          = nan(n, numCats);
M.winnerProp          = nan(n, numCats);
M.CycleLenMean        = nan(n, numCats);
M.meanEntropy         = nan(n, numCats);
M.cycleDensity        = nan(n, numCats);
M.nodesInCat          = nan(n, numCats);
M.cyclesPerNode       = nan(n, numCats);
M.cycleCategoryCounts = nan(n, numCats);
M.CycleModeCat        = cell(n,1);

for i = 1:n

    if i > numel(Cycles) || isempty(Vis{i}) || isempty(Cycles{i})
        continue
    end

    cycLen      = cellfun(@numel, Cycles{i}.allcycles(:));
    winnerCat   = Cycles{i}.cycleWinnerCategory(:);
    entropyVals = Cycles{i}.cycleEntropy(:);

    nCommon     = min([numel(cycLen), numel(winnerCat), numel(entropyVals)]);
    cycLen      = cycLen(1:nCommon);
    winnerCat   = winnerCat(1:nCommon);
    entropyVals = entropyVals(1:nCommon);

    % winner-takes-all counts
    countPerCat = histcounts(winnerCat, 0.5:1:numCats+0.5);
    M.CycleCount(i,:) = countPerCat;

    % Nodes carrying each category, so the GLOBAL formula can be applied
    % LOCALLY: the whole graph reports total cycles / total nodes, and this
    % reports a category's cycles / that category's nodes. Same units, so the
    % two can go on one axis and be compared directly.
    if isfield(Vis{i}, 'colorvar_nodes')
        nodeCat = double(Vis{i}.colorvar_nodes(:));
        M.nodesInCat(i,:)    = histcounts(nodeCat, 0.5:1:numCats+0.5);
        withNodes            = M.nodesInCat(i,:) > 0;
        cpn                  = nan(1, numCats);
        cpn(withNodes)       = countPerCat(withNodes) ./ M.nodesInCat(i, withNodes);
        M.cyclesPerNode(i,:) = cpn;
    end

    if nCommon > 0
        M.winnerProp(i,:)   = countPerCat / nCommon;
        M.cycleDensity(i,:) = countPerCat / nCommon;
    else
        M.winnerProp(i,:)   = 0;     % no cycles -> proportion 0
        % cycleDensity stays NaN (0/0)
    end

    % mean cycle length and entropy per winner category
    for c = 1:numCats
        idx = (winnerCat == c);
        if any(idx)
            M.CycleLenMean(i,c) = mean(cycLen(idx));
            M.meanEntropy(i,c)  = mean(entropyVals(idx), 'omitnan');
        else
            M.CycleLenMean(i,c) = absentValue;
            M.meanEntropy(i,c)  = absentValue;
        end
    end

    % mean behavioural composition across cycles
    cycleCounts = Cycles{i}.cycleCategoryCounts;
    if ~isempty(cycleCounts)
        propCounts = cycleCounts ./ sum(cycleCounts, 2);
        M.cycleCategoryCounts(i,:) = mean(propCounts, 1, 'omitnan');
    else
        M.cycleCategoryCounts(i,:) = 0;
    end

    M.CycleModeCat{i} = winnerCat;
end
end
