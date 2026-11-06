%% ===== PURPLE COLOUR VERSION =====
% The figures of WholeGraphsCycles_Above3Min_03July26 with Casual Chat solid purple and
% Conflict light purple (DYMO_conditionColorsPurple, the colours for figures
% without states). Figures go to folders ending in _Purple. No tables are
% written: the numbers are those of WholeGraphsCycles_Above3Min_03July26.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
% ====================================================

%% ==================== Whole Graph Cycle Metrics (paired t-test) ====================
% Loads the cycle files named in DYMO_files.m; metrics from
% wholeGraphCycleMetrics (NaN, not 0, for a dyad missing in one condition);
% figures by plotCycleMetric.

if ~exist('wholeGraphCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Pairedttest');

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
% (not written in the purple copy) DYMO_writeTable(CycleWholeStats, 'CycleWholeGraph_Pairedttest.csv');

%% ==================== FIGURES ====================
cycFigFolder = DYMO_figureFolder('Cycles_PairedTtest', 'WholeGraph_Purple');
% ---- the key to the two conditions, as its own figure ----
% The result figures carry no legend; the key is saved
% once here instead. The colours come from DYMO_conditionColors, the same
% function the bars use, so the two cannot drift apart.
figLegend = plotLegendFigure({'Casual Chat','Conflict'}, DYMO_conditionColorsPurple(), 'Condition');
BRMSavePublicationFigure('ConditionLegend', figLegend, cycFigFolder, [7 5]);   % narrower key
close(figLegend);

% The y-axis label is left empty on purpose: the metric
% name is already the title at the top of the figure, so repeating it down the
% side was redundant. The plotters skip the label when it is ''.
% plotCycleMetric always uses the teal / salmon colours, so the purple copy
% draws the same figure directly: plotWholePairedBar, saved at [13 16] as
% plotCycleMetric does.
cycMetrics = {'CycleCount','CycleLenMean','meanEntropy','cycleDensity'};
cycTitles  = {'CycleCount','Cycle Mean Length','mean Entropy','Cycle Density'};
for m = 1:numel(cycMetrics)
    R   = Results.(cycMetrics{m});
    fig = plotWholePairedBar(R.rawGtk, R.rawMan, R.pvals, cycTitles{m}, '', ...
                             DYMO_conditionColorsPurple());
    BRMSavePublicationFigure(['WGCycle_' cycMetrics{m}], fig, cycFigFolder, [13 16]);
    close(fig);
end
