%% ====== CORRELATION BARS WITH PAIRWISE CATEGORY COMPARISONS ======
% Pairwise category comparisons by bootstrap, with only the significant pairs
% shown.
% One figure per metric:
%   * one bar per behavioural category = Spearman rho between Casual Chat and
%     Conflict across dyads, in the category colour, with its BCa 95% CI
%   * a bracket between two categories ONLY when their rho differ:
%         *   95 % CI of delta rho excludes 0
%         **  99 % CI excludes 0
%         *** 99.9 % CI excludes 0
%     non-significant pairs are not drawn. Six pairs per metric, no correction.
%
% Saved in
%   GraphMetrics_Correlation\Figures\...\Subgraph_CorrBars_Pairwise
%   Cycles_Correlation\Figures\...\PerCategory_CorrBars_Pairwise
% Table of the pairwise results (aggregate only) in each area's Tables folder:
%   CorrPairwise_Subgraph_<tag>.csv, CorrPairwise_CyclesPerCategory_<tag>.csv
%
% The bar heights and CIs come from spearmanWithCI with the same seed as the
% correlation scripts, so they equal the CategoryLevelSpearCorr tables.
% Runtime: a few minutes per family (6 pairs x metrics x 10,000 resamples).
%
% BEFORE RUNNING
%   clear all; close all; clc
%   DYMO_setup
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%
% A star on each bar whose rho differs from 0 (p of the Spearman correlation),
% so one plot holds all the information: star on a bar = rho differs from 0;
% star on a bracket = two bars differ. A key to the stars is saved in each
% figure folder as StarKey. The whole-graph bars are made by the whole-graph
% scripts (SpearCorr_WholeGraph_Bars_29Oct26, SpearCorr_CycWholeGraph_Bars_29Oct26).
% The script also lists any bar where that p-value and the BCa CI disagree.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('spearmanPairDelta','file'), error('Run DYMO_setup.m first.'); end

RUN     = {'Subgraphs', 'Cycles'};   % drop one to run the other alone
nBoot   = 10000;
pairIdx = nchoosek(1:4, 2);          % the six category pairs
summary = {};
disagree = {};   % bars whose p-value and CI disagree

for f = 1:numel(RUN)
    tic;
    switch RUN{f}
        case 'Subgraphs'
            area = 'GraphMetrics_Correlation';  sub = 'Subgraph_CorrBars_Pairwise';
            tblName = 'CorrPairwise_Subgraph.csv';
            F = DYMO_files(area);
            load(F.GTK_TM, 'GTK_AllDyads_GraphData');
            load(F.MAN_TM, 'MAN_AllDyads_GraphData');
            first   = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
            catNames = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
            cmap     = GTK_AllDyads_GraphData{first}.cmap;
            nCat     = numel(catNames);
            Stats.GTK = graphStatsByCategory(GTK_AllDyads_GraphData, nCat);
            Stats.MAN = graphStatsByCategory(MAN_AllDyads_GraphData, nCat);
            Whole.GTK = graphStatsWhole(GTK_AllDyads_GraphData);   % whole graph
            Whole.MAN = graphStatsWhole(MAN_AllDyads_GraphData);
            clear GTK_AllDyads_GraphData MAN_AllDyads_GraphData
            metrics      = {'numNodes','density','nodesizes','numComponents','largestFrac', ...
                            'Embed_numNodes','Embed_density','Embed_nodesizes'};
            metricLabels = {'Number of Nodes','Edge Density','Node size','number of Connected Components', ...
                            'Dominance of the main Cluster','Embedded Number of Nodes', ...
                            'Embedded Edge Density','Embedded node sizes'};
            % the same metric for the whole graph ('' = none: for the whole
            % graph the embedded metrics equal the plain ones)
            wholeMetrics = {'numNodes','density','nodesizes','numComponents','largestFrac', '', '', ''};

        case 'Cycles'
            area = 'Cycles_Correlation';  sub = 'PerCategory_CorrBars_Pairwise';
            tblName = 'CorrPairwise_CyclesPerCategory.csv';
            F = DYMO_files(area);
            load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
            load(F.MAN_Cycles, 'MANCycles', 'MANVis');
            first    = find(~cellfun(@isempty, GTKVis), 1);
            catNames = GTKVis{first}.BehaviouralCategory;
            cmap     = GTKVis{first}.cmap;
            nCat     = numel(catNames);
            Stats.GTK = perCategoryCycleMetrics(GTKCycles, GTKVis, nCat, NaN);
            Stats.MAN = perCategoryCycleMetrics(MANCycles, MANVis, nCat, NaN);
            Whole.GTK = wholeGraphCycleMetrics(GTKCycles, GTKVis);    % whole graph
            Whole.MAN = wholeGraphCycleMetrics(MANCycles, MANVis);
            clear GTKCycles GTKVis MANCycles MANVis
            metrics      = {'winnerProp', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'cyclesPerNode'};
            metricLabels = {'Share of cycles won', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'Cycle Density'};
            % the same metric for the whole graph ('' = none; cyclesPerNode and
            % cycleDensity share one formula, cycles / nodes)
            wholeMetrics = {'', 'CycleLenMean', 'meanEntropy', '', 'cycleDensity'};
    end

    outFolder = DYMO_figureFolder(area, sub);
    rows = {};

    % the key to the stars, saved once per folder as its own figure, like the
    % ConditionLegend figures
    figKey = plotCorrStarKey();
    SavePublicationFigure('StarKey', figKey, outFolder, [13 10]);
    close(figKey);

    for m = 1:numel(metrics)
        XG = Stats.GTK.(metrics{m});
        XM = Stats.MAN.(metrics{m});

        % bars: the same numbers as the CategoryLevel tables
        rho = nan(1,nCat);  ciLo = nan(1,nCat);  ciHi = nan(1,nCat);  pRho = nan(1,nCat);
        for c = 1:nCat
            [rho(c), pRho(c), ci] = spearmanWithCI(XG(:,c), XM(:,c), nBoot);
            ciLo(c) = ci(1);  ciHi(c) = ci(2);
            % p and the BCa CI are two different tests; say so if they disagree
            if (pRho(c) < 0.05) ~= (ciLo(c) > 0 || ciHi(c) < 0)
                disagree{end+1} = sprintf('%s, %s: p = %.3f but CI [%.3f, %.3f]', ...
                    metricLabels{m}, catNames{c}, pRho(c), ciLo(c), ciHi(c)); %#ok<SAGROW>
            end
        end

        % the six pairwise differences
        pairs = struct('i',{},'j',{},'rhoI',{},'rhoJ',{},'delta',{}, ...
                       'CI95',{},'CI99',{},'CI999',{},'stars',{},'nDyads',{});
        for p = 1:size(pairIdx,1)
            pairs(p) = spearmanPairDelta(XG, XM, pairIdx(p,1), pairIdx(p,2), nBoot);
            P = pairs(p);
            rows(end+1,:) = {string(metricLabels{m}), ...
                string(catNames{P.i}) + " vs " + string(catNames{P.j}), P.nDyads, ...
                P.rhoI, P.rhoJ, P.delta, P.CI95(1), P.CI95(2), string(P.stars)}; %#ok<SAGROW>
        end

        fig = plotCorrPairBars(rho, ciLo, ciHi, catNames, cmap, metricLabels{m}, pairs, pRho);
        % saved exactly like the paired t-test bar figures (default size and fonts)
        yl = ylim(findobj(fig, 'Type','axes'));   % the y-scale, for the whole-graph partner
        BRMSavePublicationFigure(metrics{m}, fig, outFolder, [18 16]);   % narrower
        close(fig)

        % ---- the whole-graph partner, on the same y-scale ----
        % One bar, saved next to the by-state figure as <metric>_WholeGraph, on
        % the same y-scale. Off: the whole-graph bars come from the whole-graph
        % scripts (SpearCorr_WholeGraph_Bars_29Oct26 and
        % SpearCorr_CycWholeGraph_Bars_29Oct26).
        MAKE_WHOLE_PARTNER = false;
        if MAKE_WHOLE_PARTNER && ~isempty(wholeMetrics{m})
            [rW, pW, ciW] = spearmanWithCI(Whole.GTK.(wholeMetrics{m}), ...
                                           Whole.MAN.(wholeMetrics{m}), nBoot);
            if (pW < 0.05) ~= (ciW(1) > 0 || ciW(2) < 0)
                disagree{end+1} = sprintf('%s, Whole graph: p = %.3f but CI [%.3f, %.3f]', ...
                    metricLabels{m}, pW, ciW(1), ciW(2)); %#ok<SAGROW>
            end
            yl(1) = min(yl(1), ciW(1) - 0.10);     % room for its own whisker
            yl(2) = max(yl(2), ciW(2) + 0.15);     % and its star
            figW = plotCorrWholeBar(rW, ciW(1), ciW(2), pW, metricLabels{m}, yl);
            BRMSavePublicationFigure([metrics{m} '_WholeGraph'], figW, outFolder, [13 16]);
            close(figW)
            summary{end+1} = sprintf('%-12s %-32s whole graph: rho = %.3f, p = %.3f, 95%% CI [%.3f, %.3f]', ...
                                     RUN{f}, metricLabels{m}, rW, pW, ciW(1), ciW(2)); %#ok<SAGROW>
        end

        sigPairs = pairs(~cellfun(@isempty, {pairs.stars}));
        txt = arrayfun(@(q) sprintf('%s-%s %s', catNames{q.i}, catNames{q.j}, q.stars), ...
                       sigPairs, 'UniformOutput', false);
        if isempty(txt), txt = {'none'}; end
        summary{end+1} = sprintf('%-12s %-32s significant pairs: %s', ...
                                 RUN{f}, metricLabels{m}, strjoin(txt, '; ')); %#ok<SAGROW>
    end

    T = cell2table(rows, 'VariableNames', {'Metric','Pair','N_dyads','Rho_first', ...
        'Rho_second','Delta_rho','CI95_Lower','CI95_Upper','Stars'});
    T = DYMO_roundTable(T);
    DYMO_writeTable(T, tblName);
    fprintf('%s done in %.0f s; figures in %s\n', RUN{f}, toc, outFolder);
end

fprintf('\n===== PAIRWISE CORRELATION BARS: SUMMARY (aggregate only) =====\n');
fprintf('%s\n', summary{:});
if isempty(disagree)
    fprintf('\np-values and CIs agree for every bar.\n');
else
    fprintf('\nBars where the p-value and the 95%% CI disagree:\n');
    fprintf('  %s\n', disagree{:});
end
