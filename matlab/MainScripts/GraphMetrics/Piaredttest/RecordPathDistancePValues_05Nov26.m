%% ===== MEAN PATH DISTANCE BY STATE: casual chat vs conflict =====
% The figure BC_PathDistanceByState prints p values that plotCategoryPairedBars
% computes (paired t-test) but does not write to a table. This script computes
% the same numbers, saves them as a table, and draws the figure.
%
% HOW
% Mean path distance per node: D_simp, both directions pooled, unreachable pairs
% and self-distance dropped, averaged over the nodes of each behavioural state
% (label = mode). Casual chat vs conflict is then tested per state with
% pairedDiffStats, whose t-test drops the same incomplete pairs as
% plotCategoryPairedBars, so its p equals the one on the figure.
% pairedDiffStats also gives the BCa bootstrap CI and the Wilcoxon p as checks.
%
% Output is aggregate over dyads (one row per state). Nothing participant-level
% is written.
%
% RUN
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%   DYMO_setup
%   RecordPathDistancePValues_05Nov26
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('pairedDiffStats','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
numCategories       = numel(BehaviouralCategory);

sets  = {GTK_AllDyads_GraphData, MAN_AllDyads_GraphData};
Close = cell(1, 2);

%% ---- mean path distance per state per dyad ----
for k = 1:2
    AllDyads = sets{k};
    n        = numel(AllDyads);
    closeCat = nan(n, numCategories);
    for d = 1:n
        data = AllDyads{d};
        if isempty(data) || ~isstruct(data), continue; end
        D = double(data.D_simp);
        N = size(D, 1);
        if N < 3, continue; end
        D(1:N+1:end) = NaN;
        meanDist = nan(N, 1);
        for i = 1:N
            v = [D(i,:), D(:,i).'];
            v = v(isfinite(v));
            if ~isempty(v), meanDist(i) = mean(v); end
        end
        nodeCat = findnodelabel(data.members, data.colorvar, 'labelmethod', 'mode');
        for c = 1:numCategories
            mc = meanDist(nodeCat == c);
            mc = mc(isfinite(mc));
            if ~isempty(mc), closeCat(d,c) = mean(mc); end
        end
    end
    Close{k} = closeCat;
end

%% ---- casual chat vs conflict, per state ----
State = strings(numCategories,1);  Nd = nan(numCategories,1);
MeanCasual = nan(numCategories,1); MeanConflict = nan(numCategories,1);
MeanDiff = nan(numCategories,1);   CI_Lower = nan(numCategories,1);
CI_Upper = nan(numCategories,1);   tStat = nan(numCategories,1);
dfOut = nan(numCategories,1);      pValue = nan(numCategories,1);
pWilcoxon = nan(numCategories,1);  dz = nan(numCategories,1);

for c = 1:numCategories
    S = pairedDiffStats(Close{1}(:,c), Close{2}(:,c));
    State(c)      = string(BehaviouralCategory{c});
    Nd(c)         = S.N;
    MeanCasual(c) = S.meanA;     MeanConflict(c) = S.meanB;
    MeanDiff(c)   = S.meanDiff;
    CI_Lower(c)   = S.ciBoot(1); CI_Upper(c) = S.ciBoot(2);
    tStat(c)      = S.t;         dfOut(c) = S.df;
    pValue(c)     = S.p;         pWilcoxon(c) = S.pWilcoxon;
    dz(c)         = S.dz;
    fprintf('%-18s N = %d   p = %.3f   (figure shows this p)\n', State(c), S.N, S.p);
end

PathDistance_CasualVsConflict = table(State, Nd, MeanCasual, MeanConflict, ...
    MeanDiff, CI_Lower, CI_Upper, tStat, dfOut, pValue, pWilcoxon, dz, ...
    'VariableNames', {'State','N_dyads','MeanPathDist_Casual', ...
                      'MeanPathDist_Conflict','MeanDiff_CasualMinusConflict', ...
                      'CI_Lower','CI_Upper','t','df','p','p_Wilcoxon','dz'});
PathDistance_CasualVsConflict = DYMO_roundTable(PathDistance_CasualVsConflict);
DYMO_writeTable(PathDistance_CasualVsConflict, 'PathDistance_CasualVsConflict_ByState.csv');
DYMO_writeTable(PathDistance_CasualVsConflict, 'PathDistance_CasualVsConflict_ByState.xlsx');
disp(PathDistance_CasualVsConflict)

%% ---- the figure: mean path distance by state, Casual Chat vs Conflict ----
% (the Python version draws it in run_stats_graph_nodedist.py)
cmap         = GTK_AllDyads_GraphData{first}.cmap;
colorvarname = GTK_AllDyads_GraphData{first}.colorvarname;
figureFolder = DYMO_figureFolder('GraphMetrics_PairedTtest', 'MeanPathDistance');
figLegend = plotCategoryLegendFigure(BehaviouralCategory, cmap, {'Casual Chat','Conflict'});
BRMSavePublicationFigure('CategoryLegend', figLegend, figureFolder, [13 10]);
close(figLegend);
fig = plotCategoryPairedBars(Close{1}, Close{2}, BehaviouralCategory, cmap, ...
    'Mean path distance', colorvarname);
BRMSavePublicationFigure('BC_PathDistanceByState', fig, figureFolder);
close(fig);
