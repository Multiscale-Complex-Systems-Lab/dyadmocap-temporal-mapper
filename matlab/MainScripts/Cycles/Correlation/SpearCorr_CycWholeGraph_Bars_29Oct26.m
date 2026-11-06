%% ====== WHOLE GRAPH CORRELATIONS AS BARS (cycles) ======
% Bar version of the whole-graph cycle scatter plots of
% SpearCorr_CycWholeGraph_17July26: the SAME 4 metrics,
% the SAME rho, p and BCa 95% CI (spearmanWithCI, 10,000 dyad resamples,
% seed 1), drawn as one bar per metric (plotCorrWholeBar):
%   * bar = Spearman rho between Casual Chat and Conflict across dyads
%   * whisker = BCa 95% CI
%   * star above the bar = rho differs from 0 (* .05, ** .01, *** .001),
%     grey n.s. when not
%
% Saved in
%   Cycles_Correlation\Figures\Cycles_Correlation\WholeGraph_Bars
% No tables are written: SpearCorr_CycWholeGraph_17July26 already wrote them,
% with the same numbers.
%
% Every bar shows the rho and p of the matching whole-graph cycle scatter plot.
%
% BEFORE RUNNING
%   clear all; close all; clc
%   DYMO_setup
%   cfg = DYMO_config(); cd(cfg.resultsDir)   % the results folder (DYMO_runAll does this itself)
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if ~exist('wholeGraphCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Correlation');

nBoot = 10000;

tic
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');
Stats.GTK = wholeGraphCycleMetrics(GTKCycles, GTKVis);
Stats.MAN = wholeGraphCycleMetrics(MANCycles, MANVis);
clear GTKCycles GTKVis MANCycles MANVis
toc;

% the same metrics and labels as SpearCorr_CycWholeGraph_17July26
metrics      = {'CycleLenMean', 'meanEntropy', 'cycleDensity', 'CycleCount'};
metricLabels = {'Cycle Mean Length', 'mean Entropy', 'Cycle Density', 'CycleCount'};

figureFolder = DYMO_figureFolder('Cycles_Correlation','WholeGraph_Bars');

% the key to the stars, as its own figure
figKey = plotCorrStarKey();
SavePublicationFigure('StarKey', figKey, figureFolder, [13 10]);
close(figKey);

fprintf('\n===== WHOLE GRAPH CORRELATION BARS (cycles): SUMMARY =====\n');
for m = 1:numel(metrics)
    [rho, p, CI, N] = spearmanWithCI(Stats.GTK.(metrics{m}), Stats.MAN.(metrics{m}), nBoot);
    fprintf('%-20s rho = %.3f, p = %.3f, 95%% CI [%.3f, %.3f], N = %d\n', ...
            metricLabels{m}, rho, p, CI(1), CI(2), N);
    if ~isfinite(rho), continue; end
    if (p < 0.05) ~= (CI(1) > 0 || CI(2) < 0)
        fprintf('   note: p and the 95%% CI disagree for this metric\n');
    end

    yLimits = [min(-0.25, CI(1) - 0.10), max(1.0, CI(2) + 0.15)];

    fig = plotCorrWholeBar(rho, CI(1), CI(2), p, metricLabels{m}, yLimits);
    SavePublicationFigure(metrics{m}, fig, figureFolder, [8 16]);   % narrow
    close(fig)
end
fprintf('Figures in %s\n', figureFolder);
