%% ==================== METRICS FOR EMBEDDED AND NON-EMBEDDED SUBGRAPH STATS ====================
% This code studies the metrics on;
% i) Non-Embedded subgraphs: "What is the topology of the induced subnetwork for each behavioral state?"
% ii) Embedded subgraphs: "How are the behavioral states embedded within the original transition topology?"
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the TM data files named in DYMO_files.m; metrics from
% graphStatsByCategory; figures by plotCategoryPairedBars.

if ~exist('graphStatsByCategory','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Piaredttest');

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
cmap                = GTK_AllDyads_GraphData{first}.cmap;
colorvarname        = GTK_AllDyads_GraphData{first}.colorvarname;
numCategories       = numel(BehaviouralCategory);

%% ==================== PIPELINE ====================
tic;
Stats.GTK = graphStatsByCategory(GTK_AllDyads_GraphData, numCategories);
Stats.MAN = graphStatsByCategory(MAN_AllDyads_GraphData, numCategories);
toc;

idxG1 = [1 2];
idxG2 = [3 4];
fprintf('Symmetric Interaction: %s\n',  strjoin(BehaviouralCategory(idxG1), ', '));
fprintf('Asymmetric Interaction: %s\n', strjoin(BehaviouralCategory(idxG2), ', '));

% The 8 metrics, the same in the paired t-tests and the correlations
metrics      = {'numNodes','density','nodesizes','numComponents','largestFrac', ...
                'Embed_numNodes','Embed_density','Embed_nodesizes'};
metricLabels = {'Number of Nodes','Edge Density','Node size','number of Connected Components', ...
                'Dominance of the main Cluster','Embedded Number of Nodes', ...
                'Embedded Edge Density','Embedded Node Sizes'};

%% ==================== DATASET COMPARISON + TABLE ====================
nRows = numel(metrics) * numCategories;
AllResults = table(strings(nRows,1), strings(nRows,1), strings(nRows,1), zeros(nRows,1), ...
    nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), nan(nRows,1), ...
    'VariableNames', {'Metric','Group','BehaviouralCategory','N', ...
                      'GTK_Mean','GTK_SEM','MAN_Mean','MAN_SEM','P_Value'});
for c = 1:numCategories
    fprintf('\nBehavioural Category: %s\n---------------------------\n', BehaviouralCategory{c});

    for m = 1:numel(metrics)
        metric = metrics{m};

        xC = Stats.GTK.(metric)(:,c);
        xS = Stats.MAN.(metric)(:,c);
        valid = isfinite(xC) & isfinite(xS);
        xC = xC(valid);
        xS = xS(valid);
        N  = numel(xC);

        p = NaN; tstat = NaN; df = NaN;
        if N > 1
            [~, p, ~, st] = ttest(xC, xS);
            tstat = st.tstat; df = st.df;
        end

        fprintf('%s:\n', metricLabels{m})
        fprintf('  GTK %.3f ± %.3f (N=%d)\n', mean(xC), std(xC)/sqrt(N), N);
        fprintf('  MAN %.3f ± %.3f (N=%d)\n\n', mean(xS), std(xS)/sqrt(N), N);
        fprintf('  Paired t-test: t=%.3f, df=%d, p=%.4f\n\n', tstat, df, p);

        if c <= 2
            group = "Symmetric Interaction";
        else
            group = "Asymmetric Interaction";
        end
        row = (m-1)*numCategories + c;          % metric-major rows, as before
        AllResults(row,:) = {string(metricLabels{m}), group, string(BehaviouralCategory{c}), N, ...
                             mean(xC), std(xC)/sqrt(N), mean(xS), std(xS)/sqrt(N), p};
    end
end

AllResults = DYMO_roundTable(AllResults);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(AllResults, 'GTKMAN_SubgCatsStat.csv');
DYMO_writeTable(AllResults, 'GTKMAN_SubgCatsStat.xlsx');
disp(AllResults)

%% ============ SYMMETRIC vs ASYMMETRIC: THE CONDITION EFFECT ============
% This is the paired-t-test counterpart of the
% symmetric-vs-asymmetric table the correlation script writes: where that one
% asks whether the ACROSS-DYAD CORRELATION between the conversations differs
% between the two kinds of category, this asks whether the CONDITION EFFECT
% (Casual Chat minus Conflict) differs between them.
%
% Each dyad contributes one value per group - the mean of its two symmetric
% categories, and the mean of its two asymmetric ones - so the difference of
% differences is a within-dyad quantity and the dyad is the unit throughout.
%
% THE CI IS THE INFERENCE, exactly as in the correlation table:
%   CI entirely above 0 -> the condition effect is larger in symmetric
%   CI entirely below 0 -> the condition effect is larger in asymmetric
%   CI contains 0       -> no significant difference
% BCa, 10,000 resamples, dyads resampled, fixed seed - the same procedure as
% every other interval in the pipeline.
fprintf('\n===== Symmetric vs Asymmetric: difference in the condition effect =====\n');

nM = numel(metrics);
% No p-value column: the CI is the inference, exactly as in the correlation
% comparison, which reports a delta and its interval and nothing else.
% pairedGroupDelta still computes a paired t-test p and a sign-flip
% permutation p internally; neither is reported, so the table cannot
% contradict itself.
GroupCompare = table(strings(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), ...
    nan(nM,1), nan(nM,1), strings(nM,1), ...
    'VariableNames', {'Metric','N','Symmetric_MeanDiff','Asymmetric_MeanDiff', ...
                      'Delta_MeanDiff','CI_Lower','CI_Upper','Verdict'});

for m = 1:nM
    metric = metrics{m};

    % one value per dyad per group: the mean across that group's categories
    aG1 = mean(Stats.GTK.(metric)(:, idxG1), 2, 'omitnan');
    bG1 = mean(Stats.MAN.(metric)(:, idxG1), 2, 'omitnan');
    aG2 = mean(Stats.GTK.(metric)(:, idxG2), 2, 'omitnan');
    bG2 = mean(Stats.MAN.(metric)(:, idxG2), 2, 'omitnan');

    R = pairedGroupDelta(aG1, bG1, aG2, bG2);

    fprintf('\n%s\n', metricLabels{m});
    fprintf('  Symmetric  effect (GTK-MAN) = %.4g\n', R.diffG1);
    fprintf('  Asymmetric effect (GTK-MAN) = %.4g\n', R.diffG2);
    fprintf('  Difference = %.4g,  95%% CI [%.4g, %.4g]\n', R.delta, R.CI(1), R.CI(2));

    GroupCompare(m,:) = {string(metricLabels{m}), R.N, R.diffG1, R.diffG2, ...
                         R.delta, R.CI(1), R.CI(2), ...
        DYMO_ciVerdict(R.CI, 'Effect larger in symmetric', ...
                             'Effect larger in asymmetric')};
end

GroupCompare = DYMO_roundTable(GroupCompare);
DYMO_writeTable(GroupCompare, 'GTKMAN_SubgGroupCompare.csv');
DYMO_writeTable(GroupCompare, 'GTKMAN_SubgGroupCompare.xlsx');
disp(GroupCompare)


%% ==================== VISUALIZE GTK vs MAN ====================
tic;
figureFolder = DYMO_figureFolder('GraphMetrics_PairedTtest','Subgraph_ByCategory');

% The key to the four categories is saved ONCE, as its own figure, so that the
% metric figures do not have to carry a legend and stay uncluttered. Both
% shades are shown, with the condition
% names: the category colour is Casual Chat, the lighter shade is Conflict.
figLegend = plotCategoryLegendFigure(BehaviouralCategory, cmap, {'Casual Chat','Conflict'});
BRMSavePublicationFigure('CategoryLegend', figLegend, figureFolder, [13 10]);
close(figLegend);

for m = 1:numel(metrics)
    metric = metrics{m};
    fig = plotCategoryPairedBars(Stats.GTK.(metric), Stats.MAN.(metric), ...
        BehaviouralCategory, cmap, metricLabels{m}, colorvarname);
    BRMSavePublicationFigure(sprintf('BC1fig_%s', metric), fig, figureFolder);
    close(fig)
end
toc;
