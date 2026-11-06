%% ====== WHOLE GRAPH CORRELATIONS AS BARS (graph metrics) ======
% Bar version of the whole-graph scatter plots of SpearCorr_WholeGraph_17July26:
% the SAME 8 metrics, the SAME rho, p and BCa 95% CI
% (spearmanWithCI, 10,000 dyad resamples, seed 1), drawn as one bar per metric
% in the style of the by-state correlation bars (plotCorrWholeBar):
%   * bar = Spearman rho between Casual Chat and Conflict across dyads
%   * whisker = BCa 95% CI
%   * star above the bar = rho differs from 0 (* .05, ** .01, *** .001),
%     grey n.s. when not
%
% Saved in
%   GraphMetrics_Correlation\Figures\GraphMetrics_Correlation\WholeGraph_Bars
% No tables are written: SpearCorr_WholeGraph_17July26 already wrote them,
% with the same numbers.
% Note: for the WHOLE graph the Embedded metrics equal the plain ones by
% definition (graphStatsWhole), so those bars repeat Number of Nodes, Edge
% Density and Node size; they are kept to show that the embedded metrics give
% the same results as the induced ones.
%
% Every bar shows the rho and p of the matching whole-graph scatter plot.
%
% BEFORE RUNNING
%   clear all; close all; clc
%   DYMO_setup
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('graphStatsWhole','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Correlation');

nBoot = 10000;

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
Stats.GTK = graphStatsWhole(GTK_AllDyads_GraphData);
Stats.MAN = graphStatsWhole(MAN_AllDyads_GraphData);
clear GTK_AllDyads_GraphData MAN_AllDyads_GraphData
toc;

% the same metrics and labels as SpearCorr_WholeGraph_17July26
metrics      = {'numNodes','density','nodesizes','numComponents','largestFrac', ...
                'Embed_numNodes','Embed_density','Embed_nodesizes'};
metricLabels = {'Number of Nodes','Edge Density','Node size','number of Connected Components', ...
                'Dominance of the main Cluster','Embedded Number of Nodes', ...
                'Embedded Edge Density','Embedded node sizes'};

figureFolder = DYMO_figureFolder('GraphMetrics_Correlation','WholeGraph_Bars');

% the key to the stars, as its own figure
figKey = plotCorrStarKey();
SavePublicationFigure('StarKey', figKey, figureFolder, [13 10]);
close(figKey);

fprintf('\n===== WHOLE GRAPH CORRELATION BARS (graph metrics): SUMMARY =====\n');
for m = 1:numel(metrics)
    [rho, p, CI, N] = spearmanWithCI(Stats.GTK.(metrics{m}), Stats.MAN.(metrics{m}), nBoot);
    fprintf('%-32s rho = %.3f, p = %.3f, 95%% CI [%.3f, %.3f], N = %d\n', ...
            metricLabels{m}, rho, p, CI(1), CI(2), N);
    if ~isfinite(rho), continue; end
    if (p < 0.05) ~= (CI(1) > 0 || CI(2) < 0)
        fprintf('   note: p and the 95%% CI disagree for this metric\n');
    end

    % y-scale as the by-state correlation bars: room for the whisker and star
    yLimits = [min(-0.25, CI(1) - 0.10), max(1.0, CI(2) + 0.15)];

    fig = plotCorrWholeBar(rho, CI(1), CI(2), p, metricLabels{m}, yLimits);
        SavePublicationFigure(metrics{m}, fig, figureFolder, [8 16]);   % narrow
    close(fig)
end
fprintf('Figures in %s\n', figureFolder);
