%% ==================== METRICS FOR Whole Graph STATS (paired t-test) ====================
% This code studies the metrics on the whole graph;
% i) Non-Embedded subgraphs: "What is the topology of the induced subnetwork for each behavioral state?"
% ii) Embedded subgraphs: "How are the behavioral states embedded within the original transition topology?"
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the TM data files named in DYMO_files.m; metrics from graphStatsWhole;
% figures by plotWholePairedBar.

if ~exist('graphStatsWhole','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

% The final figure set replaces this script's
% figures with the purple whole-graph figures (GTK_MAN_WholeStats_Purple_29Oct26 / WholeGraphsCycles_Purple_29Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

%% ==================== PIPELINE ====================
tic;
Stats.GTK = graphStatsWhole(GTK_AllDyads_GraphData);
Stats.MAN = graphStatsWhole(MAN_AllDyads_GraphData);
toc;

% The 8 metrics, the same in the paired t-tests and the correlations
metrics      = {'numNodes','density','nodesizes','numComponents','largestFrac', ...
                'Embed_numNodes','Embed_density','Embed_nodesizes'};
metricLabels = {'Number of Nodes','Edge Density','Node size','number of Connected Components', ...
                'Dominance of the main Cluster','Embedded Number of Nodes', ...
                'Embedded Edge Density','Embedded node sizes'};

%% ==================== DATASET COMPARISON + TABLE ====================
fprintf('Whole-Graph Paired t-tests (GTK vs MAN)\n')
fprintf('---------------------------\n')

% The table carries the mean difference, the test statistic, the paired
% effect size and a BOOTSTRAP CI of the difference, so the paired tests report
% the same way the correlation tables do. The CI is BCa with 10,000 resamples,
% resampling dyads - the same procedure as spearmanWithCI, spearmanGroupDelta
% and pairedGroupDelta, so one methods sentence covers every interval in the
% pipeline.
nRows = numel(metrics);
AllResults = table(strings(nRows,1), zeros(nRows,1), nan(nRows,1), nan(nRows,1), ...
    nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), ...
    nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), ...
    'VariableNames', {'Metric','N','GTK_Mean','GTK_SEM','MAN_Mean','MAN_SEM', ...
                      'MeanDiff_GTKminusMAN','t','df','dz','CI_Lower','CI_Upper','P_Value'});
pvals = nan(1, nRows);

for m = 1:numel(metrics)
    metric = metrics{m};

    xC = Stats.GTK.(metric);
    xS = Stats.MAN.(metric);
    valid = isfinite(xC) & isfinite(xS);
    xC = xC(valid);
    xS = xS(valid);
    N  = numel(xC);

    S = pairedDiffStats(xC, xS);      % t-test, dz and the BCa bootstrap CI
    pvals(m) = S.p;

    fprintf('%s:\n', metricLabels{m})
    fprintf('  GTK %.3f ± %.3f (N=%d)\n', mean(xC), std(xC)/sqrt(N), N);
    fprintf('  MAN %.3f ± %.3f (N=%d)\n\n', mean(xS), std(xS)/sqrt(N), N);
    fprintf('  Paired t-test: t=%.3f, df=%d, p=%.4f, dz=%.3f\n', S.t, S.df, S.p, S.dz);
    fprintf('  Mean difference %.4g, bootstrap 95%% CI [%.4g, %.4g]\n\n', ...
        S.meanDiff, S.ciBoot(1), S.ciBoot(2));

    AllResults(m,:) = {string(metricLabels{m}), N, mean(xC), std(xC)/sqrt(N), ...
                       mean(xS), std(xS)/sqrt(N), S.meanDiff, S.t, S.df, S.dz, ...
                       S.ciBoot(1), S.ciBoot(2), S.p};
end

AllResults = DYMO_roundTable(AllResults);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(AllResults, 'GTKMAN_WhSubgCatsStat.csv');
DYMO_writeTable(AllResults, 'GTKMAN_WhSubgCatsStat.xlsx');
disp(AllResults)

%% ==================== VISUALIZE GTK vs MAN ====================
tic;
if makeFigures   % see the note at the top
figureFolder = DYMO_figureFolder('GraphMetrics_PairedTtest','WholeGraph');
% ---- the key to the two conditions, as its own figure ----
% The result figures carry no legend; the key is saved
% once here instead. The colours come from DYMO_conditionColors, the same
% function the bars use, so the two cannot drift apart.
figLegend = plotLegendFigure({'Casual Chat','Conflict'}, DYMO_conditionColors(), 'Condition');
BRMSavePublicationFigure('ConditionLegend', figLegend, figureFolder, [13 10]);
close(figLegend);


for m = 1:numel(metrics)
    metric = metrics{m};
    fig = plotWholePairedBar(Stats.GTK.(metric), Stats.MAN.(metric), pvals(m), metricLabels{m});
    % [13 16] inches: one pair of bars does not need the full 25-inch width of a
    % two-panel figure. It is the same proportion as one
    % panel of the NodeDistance figures.
    BRMSavePublicationFigure(sprintf('WG1_%s', metric), fig, figureFolder, [13 16]);
    close(fig)
end
toc;

end   % if makeFigures