%% ==================== Whole Graph Cycle Metrics (paired t-test) ====================
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the cycle files named in DYMO_files.m; metrics from
% wholeGraphCycleMetrics (NaN, not 0, for a dyad missing in one condition);
% figures by plotCycleMetric.

if ~exist('wholeGraphCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Pairedttest');

% The final figure set replaces this script's
% figures with the purple whole-graph figures (GTK_MAN_WholeStats_Purple_29Oct26 / WholeGraphsCycles_Purple_29Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


%% Load the data (node labels from findnodelabel, consistent with TM plotting)
tic
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');
toc;

%% ==================== Whole Graph Cycle Metrics ====================
Stats.GTK = wholeGraphCycleMetrics(GTKCycles, GTKVis);
Stats.MAN = wholeGraphCycleMetrics(MANCycles, MANVis);

%% ==================== DATASET COMPARISON ====================
metrics      = {'CycleCount', 'CycleLenMean', 'meanEntropy', 'cycleDensity'};
% The table labels are the figure titles, and the same strings the correlation
% script uses for these metrics, so one metric reads the same everywhere
%.
metricLabels = {'CycleCount', 'Cycle Mean Length', 'mean Entropy', 'Cycle Density'};

Results = struct;

fprintf('Paired t-test (GTK vs MAN)\n')
fprintf('---------------------------------------\n')

for m = 1:numel(metrics)

    metric = metrics{m};
    fprintf('\n=== %s ===\n', metricLabels{m})

    XC = Stats.GTK.(metric);
    XS = Stats.MAN.(metric);

    validIdx = isfinite(XC) & isfinite(XS);
    XC = XC(validIdx);
    XS = XS(validIdx);

    [~, p, ~, stats_t] = ttest(XC, XS);

    Results.(metric).pvals  = p;
    Results.(metric).mGtk   = mean(XC);
    Results.(metric).mMan   = mean(XS);
    Results.(metric).seGtk  = std(XC)/sqrt(numel(XC));
    Results.(metric).seMan  = std(XS)/sqrt(numel(XS));
    Results.(metric).rawGtk = XC;   % raw GTK dyad-level data
    Results.(metric).rawMan = XS;   % raw MAN dyad-level data
    Results.(metric).tstat  = stats_t.tstat;   % kept for the results table below
    Results.(metric).df     = stats_t.df;
    Results.(metric).N      = numel(XC);

    fprintf('  GTK %.3f ± %.3f (N=%d)\n', mean(XC), std(XC)/sqrt(numel(XC)), numel(XC));
    fprintf('  MAN %.3f ± %.3f (N=%d)\n\n', mean(XS), std(XS)/sqrt(numel(XS)), numel(XS));
    fprintf('  Paired t-test: t=%.3f, df=%d, p=%.4f\n\n', stats_t.tstat, stats_t.df, p);
end

%% ==================== RESULTS TABLE ====================
% One row per metric, so the numbers are on disk and not only in the Command
% Window. No figure is added by this block.
Name    = strings(numel(metrics),1);
N_dyads = nan(numel(metrics),1);   MeanGTK  = nan(numel(metrics),1);
MeanMAN = nan(numel(metrics),1);   MeanDiff = nan(numel(metrics),1);
tStat   = nan(numel(metrics),1);   dfOut    = nan(numel(metrics),1);
pValue  = nan(numel(metrics),1);

for m = 1:numel(metrics)
    R = Results.(metrics{m});
    Name(m)     = string(metricLabels{m});
    N_dyads(m)  = R.N;
    MeanGTK(m)  = R.mGtk;
    MeanMAN(m)  = R.mMan;
    MeanDiff(m) = R.mGtk - R.mMan;      % positive = larger in Casual Chat
    tStat(m)    = R.tstat;
    dfOut(m)    = R.df;
    pValue(m)   = R.pvals;
end

CycleWholeStats = table(Name, N_dyads, MeanGTK, MeanMAN, MeanDiff, tStat, dfOut, pValue, ...
    'VariableNames', {'Metric','N_dyads','MeanGTK','MeanMAN', ...
                      'MeanDiff_GTKminusMAN','t','df','p'});
disp(CycleWholeStats);
CycleWholeStats = DYMO_roundTable(CycleWholeStats);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(CycleWholeStats, 'CycleWholeGraph_Pairedttest.csv');

%% ==================== FIGURES ====================
if makeFigures   % see the note at the top
cycFigFolder = DYMO_figureFolder('Cycles_PairedTtest','WholeGraph');
% ---- the key to the two conditions, as its own figure ----
% The result figures carry no legend; the key is saved
% once here instead. The colours come from DYMO_conditionColors, the same
% function the bars use, so the two cannot drift apart.
figLegend = plotLegendFigure({'Casual Chat','Conflict'}, DYMO_conditionColors(), 'Condition');
BRMSavePublicationFigure('ConditionLegend', figLegend, cycFigFolder, [13 10]);
close(figLegend);

% The y-axis label is left empty on purpose: the metric
% name is already the title at the top of the figure, so repeating it down the
% side was redundant. The plotters skip the label when it is ''.
plotCycleMetric(Results, 'CycleCount',   GTKVis, '',        'CycleCount', cycFigFolder);
plotCycleMetric(Results, 'CycleLenMean', GTKVis, '',  'Cycle Mean Length', cycFigFolder);
plotCycleMetric(Results, 'meanEntropy',  GTKVis, '',       'mean Entropy', cycFigFolder);
plotCycleMetric(Results, 'cycleDensity', GTKVis, '',       'Cycle Density', cycFigFolder);

end   % if makeFigures