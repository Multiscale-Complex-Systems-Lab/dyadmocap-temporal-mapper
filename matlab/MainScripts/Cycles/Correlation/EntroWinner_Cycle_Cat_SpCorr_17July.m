%% ==========================================================
% Per Category Cycle Behaviour Correlation Analysis
% ===========================================================
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the cycle files named in DYMO_files.m. Per-category metrics from
% perCategoryCycleMetrics (NaN, not 0, for missing dyads; absentCategoryValue for
% categories with no cycles). The symmetric vs asymmetric comparison runs in
% spearmanGroupDelta (BCa bootstrap, fixed seed). Hand-set axis limits are OFF
% by default (useFixedAxisLimits), since they can cut off points.

if ~exist('perCategoryCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Correlation');

% The final figure set replaces this script's
% figures with the correlation bar figures (SpearCorr_*_Bars_29Oct26, CorrPairBars_PerCategory_28Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


absentCategoryValue = NaN;    % 0 counts a category with no cycles as zero
useFixedAxisLimits  = false;
nBoot = 10000;

%% Load the data
tic
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');
toc;

first               = find(~cellfun(@isempty, GTKVis), 1);
BehaviouralCategory = GTKVis{first}.BehaviouralCategory;
numCategories       = numel(BehaviouralCategory);
cmap                = GTKVis{first}.cmap;

%% ==================== Per-Category Cycle Metrics ====================
Stats.GTK = perCategoryCycleMetrics(GTKCycles, GTKVis, numCategories, absentCategoryValue);
Stats.MAN = perCategoryCycleMetrics(MANCycles, MANVis, numCategories, absentCategoryValue);

idxG1 = [1 2];   % Symmetric
idxG2 = [3 4];   % Asymmetric
fprintf('\nSymmetric : %s\n',  strjoin(BehaviouralCategory(idxG1), ', '));
fprintf('Asymmetric : %s\n\n', strjoin(BehaviouralCategory(idxG2), ', '));

% CYCLE DENSITY FOR A CATEGORY
% The same list, in the same order, with the same labels as the paired t-test
% script (EntroWinner_Cycle_Category_Visualization), so a metric carries one
% name in both.
%
% 'cyclesPerNode' is a category's cycles divided by its OWN nodes - the
% whole-graph formula (total cycles / total nodes) applied locally - and is
% reported as 'Cycle Density'. 'cycleDensity' is dropped: for a category it is a
% SHARE of the dyad's cycles, arithmetically identical to winnerProp.
metrics      = {'winnerProp', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'cyclesPerNode'};
metricLabels = {'Share of cycles won', 'CycleLenMean', 'meanEntropy', 'cycleCategoryCounts', 'Cycle Density'};

%% ==================== DATASET COMPARISON =====================
%% Spearman Correlation + Bootstrap CI + Permutation Test
%% Symmetric = Categories 1 & 2, Asymmetric = Categories 3 & 4
tic;
CorrCompare = struct;

for m = 1:numel(metrics)

    metric = metrics{m};
    fprintf('\n========================================\n%s\n========================================\n', metricLabels{m});

    % Dyad-level BCa bootstrap: the function stacks the
    % categories itself, so one draw of dyads builds BOTH groups and the
    % dependence between the two correlations is preserved.
    R = spearmanGroupDelta(Stats.GTK.(metric), Stats.MAN.(metric), idxG1, idxG2, nBoot);

    CorrCompare(m).metric          = metric;
    CorrCompare(m).metricLabel     = metricLabels{m};
    CorrCompare(m).SymmetricNames  = BehaviouralCategory(idxG1);
    CorrCompare(m).AsymmetricNames = BehaviouralCategory(idxG2);
    % Per-group BCa intervals rather than p-values from corr() on the STACKED
    % rows, which would assume twice the independent observations the design
    % has. See the note in spearmanGroupDelta.
    CorrCompare(m).rhoG1 = R.rhoG1;   CorrCompare(m).ciG1 = R.ciG1;
    CorrCompare(m).rhoG2 = R.rhoG2;   CorrCompare(m).ciG2 = R.ciG2;
    CorrCompare(m).nDyads = R.nDyads;
    CorrCompare(m).delta = R.delta;
    CorrCompare(m).CI    = R.CI;

    fprintf('Symmetric rho  = %.4f, 95%% CI [%.4f, %.4f]\n', ...
        R.rhoG1, R.ciG1(1), R.ciG1(2));
    fprintf('Asymmetric rho = %.4f, 95%% CI [%.4f, %.4f]\n', ...
        R.rhoG2, R.ciG2(1), R.ciG2(2));
    fprintf('Delta rho = %.4f\n', R.delta);
    fprintf('95%% CI = [%.4f %.4f]\n', R.CI(1), R.CI(2));
end
toc;

%% ==================== Export comparison table ====================
nMetrics = numel(metrics);
% N_dyads is reported so the unit of replication is visible: every interval
% here is built by resampling dyads, not the stacked rows.
ResultsTable = table(strings(nMetrics,1), nan(nMetrics,1), ...
    nan(nMetrics,1), nan(nMetrics,1), nan(nMetrics,1), ...
    nan(nMetrics,1), nan(nMetrics,1), nan(nMetrics,1), ...
    nan(nMetrics,1), nan(nMetrics,1), nan(nMetrics,1), strings(nMetrics,1), ...
    'VariableNames', {'Metric','N_dyads', ...
                      'Symmetric_rho','Symmetric_CI_Lower','Symmetric_CI_Upper', ...
                      'Asymmetric_rho','Asymmetric_CI_Lower','Asymmetric_CI_Upper', ...
                      'Delta_rho','Delta_CI_Lower','Delta_CI_Upper','Verdict'});
for m = 1:nMetrics
    ResultsTable(m,:) = {string(CorrCompare(m).metricLabel), CorrCompare(m).nDyads, ...
        CorrCompare(m).rhoG1, CorrCompare(m).ciG1(1), CorrCompare(m).ciG1(2), ...
        CorrCompare(m).rhoG2, CorrCompare(m).ciG2(1), CorrCompare(m).ciG2(2), ...
        CorrCompare(m).delta, CorrCompare(m).CI(1), CorrCompare(m).CI(2), ...
        DYMO_ciVerdict(CorrCompare(m).CI, 'Symmetric correlation stronger', ...
                                          'Asymmetric correlation stronger')};
end
ResultsTable = DYMO_roundTable(ResultsTable);   % 3 significant figures, p to 3 dp (APA)

DYMO_writeTable(ResultsTable, 'SpearmanCorrCycle.csv');
DYMO_writeTable(ResultsTable, 'SpearmanCorrCycle.xlsx');
disp(ResultsTable)

%% ==================== Plot Spearman Correlation Comparison ====================
if makeFigures   % see the note at the top
figureFolder2 = DYMO_figureFolder('Cycles_Correlation','PerCategory_DeltaRho');

for m = 1:numel(metrics)
    fig = plotDeltaRho(CorrCompare(m), metricLabels{m});
    SavePublicationFigure(metrics{m}, fig, figureFolder2);
    close(fig)
end
end   % if makeFigures

%% ==================== Category-level Spearman correlations ====================
if makeFigures   % see the note at the top
figureFolder1 = DYMO_figureFolder('Cycles_Correlation','PerCategory_Scatter');

% The category key as its own figure, so the scatter panels carry no legend
%. One colour per category here, so no
% condition names: both axes of every panel are already Casual Chat vs Conflict.
% The scatter key now shows the category marks as the panels draw them - a
% translucent filled circle per category - plus the CI band and the fitted
% line, which plotCorrLegendFigure adds itself. plotCategoryLegendFigure drew
% bar swatches, which belong to the bar figures, not a scatter.
figLegend = plotCorrLegendFigure(BehaviouralCategory, cmap, '', 'category');
SavePublicationFigure('CategoryLegend', figLegend, figureFolder1, [13 10]);
close(figLegend);
end   % if makeFigures

% One entry per metric, in the metric order above (these lists are indexed by
% m).
xLimits = {[0 0.8], [0 60], [0.5 1.4], [-0.1 0.8], []};
yLimits = {[-0.1 0.8], [-5 50], [0.6 1.4], [-0.1 0.8], []};   % [] = autoscale for Cycle Density
lineWidth = 2.5;

% --- statistics once (re-used for figures AND the table) ---
catRes = struct('rho',[],'p',[],'CI',[],'N',[]);
for m = 1:numel(metrics)
    for c = 1:numCategories
        [catRes(m,c).rho, catRes(m,c).p, catRes(m,c).CI, catRes(m,c).N] = ...
            spearmanWithCI(Stats.GTK.(metrics{m})(:,c), Stats.MAN.(metrics{m})(:,c), nBoot);
    end
end

if makeFigures   % see the note at the top
for m = 1:numel(metrics)

    metric = metrics{m};
    fig = figure('Position',[100 100 2000 500],'Color','w');

    for c = 1:numCategories

        subplot(1,numCategories,c)
        hold on

        x = Stats.GTK.(metric)(:,c);
        y = Stats.MAN.(metric)(:,c);
        valid = isfinite(x) & isfinite(y);
        x = x(valid);
        y = y(valid);

        % A category whose values are identical in every dyad gives a
        % rank-deficient design matrix, so no line is fitted for it.
        if numel(x) >= 3 && std(x) > 0 && std(y) > 0
            scatter(x, y, 50, cmap(c,:), 'filled', 'MarkerEdgeColor','k');

            mdl = fitlm(x, y);
            xx  = linspace(min(x), max(x), 100)';
            [yy, CIreg] = predict(mdl, xx);

            fill([xx; flipud(xx)], [CIreg(:,1); flipud(CIreg(:,2))], cmap(c,:), ...
                       'FaceAlpha',0.20, 'EdgeColor','none');
            plot(xx, yy, 'Color',cmap(c,:), 'LineWidth',lineWidth);

            % No legend inside the panels. The key is
            % saved once, as its own figure, just below.
        end

        text(0.05, 0.95, sprintf('\\rho = %s\n%s', DYMO_numText(catRes(m,c).rho), DYMO_pText(catRes(m,c).p)), ...
            'Color', DYMO_sigColor(catRes(m,c).p), ...
             'Units','normalized', 'VerticalAlignment','top', ...
             'FontSize',30, 'FontWeight','bold');   % rho and p inside the panel

        xlabel('Casual Chat','FontWeight','bold')
        ylabel('Conflict','FontWeight','bold')
        title(BehaviouralCategory{c}, 'Interpreter','none','FontSize',12,'FontWeight','bold')

        if useFixedAxisLimits && ~isempty(xLimits{m}) && ~isempty(yLimits{m})
            xlim(xLimits{m});
            ylim(yLimits{m});
        end
        box on
        grid on
    end

    sgtitle(metricLabels{m}, 'FontSize',34, 'FontWeight','bold');   % same as a panel title
    SavePublicationFigure(metric, fig, figureFolder1);
    close(fig)
end
end   % if makeFigures

%% ==================== Category-level table ====================
nRows = numel(metrics) * numCategories;
% ONE FORMAT FOR EVERY CORRELATION TABLE
% rho, its bootstrap interval, and the verdict that interval implies. The
% p-value is no longer reported: the confidence interval is the inference
% throughout this pipeline, and where the two disagreed - as they did for two
% cycles rows, p < .05 with an interval straddling zero - the reader was left
% to choose between them.
CatTable = table(strings(nRows,1), strings(nRows,1), zeros(nRows,1), nan(nRows,1), ...
    nan(nRows,1), nan(nRows,1), strings(nRows,1), ...
    'VariableNames', {'Metric','BehaviouralCategory','N_dyads','SpearmanRho', ...
                      'CI_Lower','CI_Upper','Verdict'});
row = 1;
for m = 1:numel(metrics)
    for c = 1:numCategories
        r = catRes(m,c);
        CatTable(row,:) = {string(metricLabels{m}), string(BehaviouralCategory{c}), r.N, ...
                           r.rho, r.CI(1), r.CI(2), DYMO_ciVerdict(r.CI, 'Positive association', ...
                           'Negative association', 'No significant association')};
        row = row + 1;
    end
end

% tables go to the current folder (figure folders hold figures only)
CatTable = DYMO_roundTable(CatTable);
DYMO_writeTable(CatTable, 'CategoryCyclesSpearCorr.csv');
DYMO_writeTable(CatTable, 'CategoryCyclesSpearCorr.xlsx');
disp(CatTable)
