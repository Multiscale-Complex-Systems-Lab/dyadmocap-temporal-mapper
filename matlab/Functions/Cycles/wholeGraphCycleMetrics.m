function M = wholeGraphCycleMetrics(Cycles, Vis)
%WHOLEGRAPHCYCLEMETRICS  Dyad-level (whole graph) cycle metrics.
%
%   M = wholeGraphCycleMetrics(GTKCycles, GTKVis)
%
% Used by WholeGraphsCycles_Above3Min and SpearCorr_CycWholeGraph.
%
% Output fields (numDyads-by-1 unless noted)
%   CycleCount    total number of cycles
%   CycleLenMean  mean cycle length
%   meanEntropy   mean Shannon entropy of the cycles
%   cycleDensity  total cycles / number of nodes
%   winnerProp    (cell) winner category of every cycle
%   CycleModeCat  (cell) same as winnerProp
%
% Dyads without data are NaN, not 0: a 0 would pair a dyad missing from one
% condition as "0 cycles" against the other condition's real value in the
% paired t-test / Spearman correlation. A dyad whose graph has no cycles keeps
% CycleCount = 0 but gets NaN for the mean length / mean entropy (a mean over
% zero cycles is undefined).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

n = numel(Vis);

M.CycleCount   = nan(n,1);
M.CycleLenMean = nan(n,1);
M.meanEntropy  = nan(n,1);
M.cycleDensity = nan(n,1);
M.winnerProp   = cell(n,1);
M.CycleModeCat = cell(n,1);

for i = 1:n

    if i > numel(Cycles) || isempty(Vis{i}) || isempty(Cycles{i})
        continue
    end

    cycLen      = cellfun(@numel, Cycles{i}.allcycles(:));
    winnerCat   = Cycles{i}.cycleWinnerCategory(:);
    entropyVals = Cycles{i}.cycleEntropy(:);

    % safety alignment (lengths always agree for files made by Cycles_WinShannon)
    nCommon     = min([numel(cycLen), numel(winnerCat), numel(entropyVals)]);
    cycLen      = cycLen(1:nCommon);
    winnerCat   = winnerCat(1:nCommon);
    entropyVals = entropyVals(1:nCommon);

    M.CycleCount(i) = nCommon;
    if nCommon > 0
        M.CycleLenMean(i) = mean(cycLen);
        M.meanEntropy(i)  = mean(entropyVals, 'omitnan');
    end
    M.cycleDensity(i) = Vis{i}.cycleDensity;
    M.winnerProp{i}   = winnerCat;
    M.CycleModeCat{i} = winnerCat;
end
end
