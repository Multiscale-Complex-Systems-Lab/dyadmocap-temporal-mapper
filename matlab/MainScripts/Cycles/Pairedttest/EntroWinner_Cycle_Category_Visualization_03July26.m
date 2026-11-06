%% ==========================================================
% Per Category Cycle Behaviour Analysis (paired t-tests)
% ===========================================================
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the cycle files named in DYMO_files.m. Per-category metrics from
% perCategoryCycleMetrics; dyads without data are NaN, not 0.
% absentCategoryValue: value used when a category wins no cycle in a dyad (mean
% length / mean entropy). NaN = leave that dyad out for that category; 0 counts
% it as zero. Figures by plotMetric.

if ~exist('perCategoryCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Pairedttest');

absentCategoryValue = NaN;

%% Load the data
tic
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');
toc;

first               = find(~cellfun(@isempty, GTKVis), 1);
BehaviouralCategory = GTKVis{first}.BehaviouralCategory;
numCats             = numel(BehaviouralCategory);

%% ==================== Per-Category Cycle Metrics ====================
G = perCategoryCycleMetrics(GTKCycles, GTKVis, numCats, absentCategoryValue);
M = perCategoryCycleMetrics(MANCycles, MANVis, numCats, absentCategoryValue);

Stats.GTK = G;
Stats.MAN = M;
Stats.GTK.CycleModeCat = vertcat(G.CycleModeCat{:});
Stats.MAN.CycleModeCat = vertcat(M.CycleModeCat{:});

idxG1 = [1 2];
idxG2 = [3 4];
fprintf('\nSymmetric Interaction: %s\n', strjoin(BehaviouralCategory(idxG1), ', '));
fprintf('Asymmetric Interaction: %s\n\n', strjoin(BehaviouralCategory(idxG2), ', '));

%% ==================== DATASET COMPARISON ====================
% CYCLE DENSITY FOR A CATEGORY
% 'cyclesPerNode' is a category's cycles divided by its OWN nodes - the
% whole-graph formula (total cycles / total nodes) applied locally - so the
% global and the local figure sit on one scale and one formula. It is reported
% as 'Cycle Density' here and in the figure.
%
% 'cycleDensity' has been DROPPED from this script. For a category it was a
% SHARE of the dyad's cycles, arithmetically identical to winnerProp, so it
% duplicated a row that is already in the table under its proper name and
% invited the reader to compare it with the whole-graph density, which it was
% not. perCategoryCycleMetrics still computes it; nothing here reports it.
metrics      = {'winnerProp', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'cyclesPerNode'};
metricLabels = {'Share of cycles won', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'Cycle Density'};

Results = struct;

fprintf('Paired t-test (GTK vs MAN)\n')
fprintf('---------------------------------------\n')

for m = 1:numel(metrics)

    metric = metrics{m};
    fprintf('\n=== %s ===\n', metricLabels{m})

    XC_all = Stats.GTK.(metric);
    XS_all = Stats.MAN.(metric);

    pvals  = nan(1, numCats);
    tstats = nan(1, numCats);   % kept for the results table below
    dfs    = nan(1, numCats);
    nPairs = nan(1, numCats);
    for c = 1:numCats

        XC = XC_all(:,c);
        XS = XS_all(:,c);
        validIdx = isfinite(XC) & isfinite(XS);
        XC = XC(validIdx);
        XS = XS(validIdx);

        if numel(XC) < 2
            fprintf('%s: not enough paired data\n', BehaviouralCategory{c})
            continue
        end

        [~, p, ~, stats_t] = ttest(XC, XS);
        pvals(c)  = p;
        tstats(c) = stats_t.tstat;
        dfs(c)    = stats_t.df;
        nPairs(c) = numel(XC);

        fprintf('%s;\n', BehaviouralCategory{c})
        fprintf('  GTK %.3f ± %.3f (N=%d)\n', mean(XC), std(XC)/sqrt(numel(XC)), numel(XC));
        fprintf('  MAN %.3f ± %.3f (N=%d)\n\n', mean(XS), std(XS)/sqrt(numel(XS)), numel(XS));
        fprintf('  Paired t-test: t=%.3f, df=%d, p=%.4f\n\n', stats_t.tstat, stats_t.df, p);
    end

    Results.(metric).pvals  = pvals;
    Results.(metric).tstats = tstats;
    Results.(metric).dfs    = dfs;
    Results.(metric).nPairs = nPairs;
    Results.(metric).mGtk   = mean(XC_all, 1, 'omitnan');
    Results.(metric).mMan   = mean(XS_all, 1, 'omitnan');
    Results.(metric).seGtk  = std(XC_all, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(XC_all), 1));
    Results.(metric).seMan  = std(XS_all, 0, 1, 'omitnan') ./ sqrt(sum(isfinite(XS_all), 1));
    Results.(metric).rawGtk = XC_all;
    Results.(metric).rawMan = XS_all;
end

%% ==================== RESULTS TABLE ====================
% One row per metric and category. No figure is added by this block.
% absentCategoryValue (NaN here) decides what a category with no cycles
% contributes: with NaN it is left out of that row's N, with 0 it counts as zero.
nRows   = numel(metrics) * numCats;
Name    = strings(nRows,1);        Category = strings(nRows,1);
N_dyads = nan(nRows,1);            MeanGTK  = nan(nRows,1);
MeanMAN = nan(nRows,1);            MeanDiff = nan(nRows,1);
tStat   = nan(nRows,1);            dfOut    = nan(nRows,1);
pValue  = nan(nRows,1);

row = 0;
for m = 1:numel(metrics)
    R = Results.(metrics{m});
    for c = 1:numCats
        row = row + 1;
        Name(row)     = string(metricLabels{m});
        Category(row) = string(BehaviouralCategory{c});
        N_dyads(row)  = R.nPairs(c);
        MeanGTK(row)  = R.mGtk(c);
        MeanMAN(row)  = R.mMan(c);
        MeanDiff(row) = R.mGtk(c) - R.mMan(c);   % positive = larger in Casual Chat
        tStat(row)    = R.tstats(c);
        dfOut(row)    = R.dfs(c);
        pValue(row)   = R.pvals(c);
    end
end

CycleCategoryStats = table(Name, Category, N_dyads, MeanGTK, MeanMAN, MeanDiff, ...
    tStat, dfOut, pValue, ...
    'VariableNames', {'Metric','BehaviouralCategory','N_dyads','MeanGTK','MeanMAN', ...
                      'MeanDiff_GTKminusMAN','t','df','p'});
disp(CycleCategoryStats);
CycleCategoryStats = DYMO_roundTable(CycleCategoryStats);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(CycleCategoryStats, 'CycleCategory_Pairedttest.csv');

%% ============ SYMMETRIC vs ASYMMETRIC: THE CONDITION EFFECT ============
% This matches the block in the subgraph paired script and the
% symmetric-vs-asymmetric table the cycle CORRELATION script writes. That
% one asks whether the across-dyad correlation between the conversations
% differs between the two kinds of category; this asks whether the CONDITION
% EFFECT (Casual Chat minus Conflict) differs between them.
%
% One value per dyad per group - the mean of its two symmetric categories and
% the mean of its two asymmetric ones - so the difference of differences is a
% within-dyad quantity and the dyad is the unit throughout.
%
% THE CI IS THE INFERENCE:
%   CI entirely above 0 -> the condition effect is larger in symmetric
%   CI entirely below 0 -> the condition effect is larger in asymmetric
%   CI contains 0       -> no significant difference
% BCa, 10,000 resamples, dyads resampled, fixed seed, as everywhere else.
fprintf('\n===== Symmetric vs Asymmetric: difference in the condition effect =====\n');

nM = numel(metrics);
% No p-value column: the CI is the inference, exactly as in the correlation
% comparison, which reports a delta and its interval and nothing else.
% pairedGroupDelta still computes a paired t-test p and a sign-flip
% permutation p internally; neither is reported, so the table cannot
% contradict itself.
CycleGroupCompare = table(strings(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), ...
    nan(nM,1), nan(nM,1), strings(nM,1), ...
    'VariableNames', {'Metric','N','Symmetric_MeanDiff','Asymmetric_MeanDiff', ...
                      'Delta_MeanDiff','CI_Lower','CI_Upper','Verdict'});

for m = 1:nM
    metric = metrics{m};

    aG1 = mean(Stats.GTK.(metric)(:, idxG1), 2, 'omitnan');
    bG1 = mean(Stats.MAN.(metric)(:, idxG1), 2, 'omitnan');
    aG2 = mean(Stats.GTK.(metric)(:, idxG2), 2, 'omitnan');
    bG2 = mean(Stats.MAN.(metric)(:, idxG2), 2, 'omitnan');

    R = pairedGroupDelta(aG1, bG1, aG2, bG2);

    fprintf('\n%s\n', metricLabels{m});
    fprintf('  Symmetric  effect (GTK-MAN) = %.4g\n', R.diffG1);
    fprintf('  Asymmetric effect (GTK-MAN) = %.4g\n', R.diffG2);
    fprintf('  Difference = %.4g,  95%% CI [%.4g, %.4g]\n', R.delta, R.CI(1), R.CI(2));

    CycleGroupCompare(m,:) = {string(metricLabels{m}), R.N, R.diffG1, R.diffG2, ...
                              R.delta, R.CI(1), R.CI(2), ...
        DYMO_ciVerdict(R.CI, 'Effect larger in symmetric', ...
                             'Effect larger in asymmetric')};
end

CycleGroupCompare = DYMO_roundTable(CycleGroupCompare);
DYMO_writeTable(CycleGroupCompare, 'CycleGroupCompare.csv');
DYMO_writeTable(CycleGroupCompare, 'CycleGroupCompare.xlsx');
disp(CycleGroupCompare)

%% ==================== ALL VISUALIZATIONS ====================
catFigFolder = DYMO_figureFolder('Cycles_PairedTtest','PerCategory');

% the category key as its own figure, so the metric figures stay uncluttered
%
firstVis  = find(~cellfun(@isempty, GTKVis), 1);
figLegend = plotCategoryLegendFigure(GTKVis{firstVis}.BehaviouralCategory, ...
                                     GTKVis{firstVis}.cmap, {'Casual Chat','Conflict'});
BRMSavePublicationFigure('CategoryLegend', figLegend, catFigFolder, [13 10]);
close(figLegend);
% The y-axis label is left empty on purpose: the metric
% name is already the title at the top of the figure, so repeating it down the
% side was redundant. The plotters skip the label when it is ''.
plotMetric(Results, 'winnerProp',          GTKVis, '',      'Cycle Winner Proportion', catFigFolder);
plotMetric(Results, 'CycleLenMean',        GTKVis, '',      'Cycle Mean Length', catFigFolder);
plotMetric(Results, 'meanEntropy',         GTKVis, '',           'mean Entropy', catFigFolder);
% 'cyclesPerNode', NOT 'cycleDensity'. The per-category
% cycleDensity is a SHARE of the dyad's cycles and is the same number as
% winnerProp above, so the figure titled 'Cycle Density' was not a density and
% could not be compared with the whole-graph figure. cyclesPerNode applies the
% whole-graph formula (cycles / nodes) within each category, so global and
% local now share one formula and one scale.
plotMetric(Results, 'cyclesPerNode',       GTKVis, '',           'Cycle Density', catFigFolder);
plotMetric(Results, 'cycleCategoryCounts', GTKVis, '',  'cycle Category Counts', catFigFolder);
