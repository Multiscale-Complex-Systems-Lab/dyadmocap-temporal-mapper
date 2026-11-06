%% ==================== SUBGRAPH METRICS: SPEARMAN CORRELATIONS ====================
% Symmetric (Both Inactive + Both Active) vs Asymmetric (Person 1 / Person 2
% Active): Spearman correlation GTK vs MAN and a BCa bootstrap CI of the
% difference; then category-level correlations with bootstrap CIs.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the TM data files named in DYMO_files.m. Metrics from
% graphStatsByCategory; the bootstrap runs in spearmanGroupDelta (fixed seed,
% so reproducible). Hand-set axis limits are OFF by default
% (useFixedAxisLimits), since they can cut off points.

if ~exist('graphStatsByCategory','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Correlation');

% The final figure set replaces this script's
% figures with the correlation bar figures (SpearCorr_*_Bars_29Oct26, CorrPairBars_PerCategory_28Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


useFixedAxisLimits = false;
nBoot = 10000;

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

first               = find(~cellfun(@isempty, GTK_AllDyads_GraphData), 1);
BehaviouralCategory = GTK_AllDyads_GraphData{first}.BehaviouralCategory;
cmap                = GTK_AllDyads_GraphData{first}.cmap;
numCategories       = numel(BehaviouralCategory);

%% ==================== PIPELINE ====================
tic;
Stats.GTK = graphStatsByCategory(GTK_AllDyads_GraphData, numCategories);
Stats.MAN = graphStatsByCategory(MAN_AllDyads_GraphData, numCategories);
toc;

idxG1 = [1 2];
idxG2 = [3 4];
fprintf('\nSymmetric Interaction: %s\n',  strjoin(BehaviouralCategory(idxG1), ', '));
fprintf('Asymmetric Interaction: %s\n\n', strjoin(BehaviouralCategory(idxG2), ', '));

% The 8 metrics, the same in the paired t-tests and the correlations
metrics      = {'numNodes','density','nodesizes','numComponents','largestFrac', ...
                'Embed_numNodes','Embed_density','Embed_nodesizes'};
metricLabels = {'Number of Nodes','Edge Density','Node size','number of Connected Components', ...
                'Dominance of the main Cluster','Embedded Number of Nodes', ...
                'Embedded Edge Density','Embedded node sizes'};

%% ==================== SYMMETRIC vs ASYMMETRIC ====================
tic;
CorrCompare = struct();

for m = 1:numel(metrics)

    metric = metrics{m};

    % Dyad-level BCa bootstrap: the function stacks the
    % categories itself, so one draw of dyads builds BOTH groups and the
    % dependence between the two correlations is preserved.
    R = spearmanGroupDelta(Stats.GTK.(metric), Stats.MAN.(metric), idxG1, idxG2, nBoot);

    CorrCompare(m).metric      = metric;
    CorrCompare(m).metricLabel = metricLabels{m};
    CorrCompare(m).Group1Names = BehaviouralCategory(idxG1);
    CorrCompare(m).Group2Names = BehaviouralCategory(idxG2);
    % Per-group BCa intervals rather than p-values from corr() on the STACKED
    % rows, which would assume twice the independent observations the design
    % has. See the note in spearmanGroupDelta.
    CorrCompare(m).rhoG1 = R.rhoG1;   CorrCompare(m).ciG1 = R.ciG1;
    CorrCompare(m).rhoG2 = R.rhoG2;   CorrCompare(m).ciG2 = R.ciG2;
    CorrCompare(m).nDyads = R.nDyads;
    CorrCompare(m).delta = R.delta;
    CorrCompare(m).CI    = R.CI;

    fprintf('\n========================================\n%s\n========================================\n', metricLabels{m});
    fprintf('rho(Symmetric Interaction)  = %.4f, 95%% CI [%.4f, %.4f]\n', ...
        R.rhoG1, R.ciG1(1), R.ciG1(2));
    fprintf('rho(Asymmetric Interaction) = %.4f, 95%% CI [%.4f, %.4f]\n', ...
        R.rhoG2, R.ciG2(1), R.ciG2(2));
    fprintf('Difference = %.4f\n', R.delta);
    fprintf('95%% CI = [%.4f, %.4f]\n', R.CI(1), R.CI(2));
end
toc;

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
DYMO_writeTable(ResultsTable, 'CorrComparison.csv');
DYMO_writeTable(ResultsTable, 'CorrComparison.xlsx');
disp(ResultsTable)

if makeFigures   % see the note at the top
figureFolder2 = DYMO_figureFolder('GraphMetrics_Correlation','Subgraph_DeltaRho');
for m = 1:nMetrics
    fig = plotDeltaRho(CorrCompare(m), metricLabels{m});
    % single-panel figure, so the narrower canvas, like the whole-graph ones
    %. The four-panel scatter figures below keep 25 x 16.
    SavePublicationFigure(metrics{m}, fig, figureFolder2, [13 16]);
    close(fig)
end
end   % if makeFigures

%% ==================== CATEGORY-LEVEL SPEARMAN CORRELATIONS ====================
if makeFigures   % see the note at the top
figureFolder1 = DYMO_figureFolder('GraphMetrics_Correlation','Subgraph_Scatter');

% One legend figure for the four category colours, saved on its own so the
% scatter panels stay uncluttered. These
% panels use one colour per category, so no second condition is shown here.
% The scatter key now shows the category marks as the panels draw them - a
% translucent filled circle per category - plus the CI band and the fitted
% line, which plotCorrLegendFigure adds itself. plotCategoryLegendFigure drew
% bar swatches, which belong to the bar figures, not a scatter.
figLegend = plotCorrLegendFigure(BehaviouralCategory, cmap, '', 'category');
SavePublicationFigure('CategoryLegend', figLegend, figureFolder1, [13 10]);
close(figLegend);
end   % if makeFigures

xLimits = {[300 2000], [0.5e-3 1.8e-3], [0.2 1.3], [1.5 4], [50 500], [0 1000], [0 1], ...
           [400 2000], [5.0e-4 2.0e-3], [1 2], [0 5]};
yLimits = {[300 1600], [0.2e-3 2.4e-3], [0.2 1.3], [1 5], [50 550], [0 1000], [0 1], ...
           [200 1800], [5.0e-4 3.0e-3], [1.0 2], [1 4]};
lineWidth = 2.5;

% --- statistics once (re-used for figures AND the table) ---
catRes = struct('rho',[],'p',[],'CI',[],'N',[]);
for m = 1:nMetrics
    for c = 1:numCategories
        [catRes(m,c).rho, catRes(m,c).p, catRes(m,c).CI, catRes(m,c).N] = ...
            spearmanWithCI(Stats.GTK.(metrics{m})(:,c), Stats.MAN.(metrics{m})(:,c), nBoot);
    end
end

if makeFigures   % see the note at the top
for m = 1:nMetrics

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
        end

        text(0.05, 0.95, sprintf('\\rho = %s\n%s', DYMO_numText(catRes(m,c).rho), DYMO_pText(catRes(m,c).p)), ...
            'Color', DYMO_sigColor(catRes(m,c).p), ...
             'Units','normalized', 'VerticalAlignment','top', ...
             'FontSize',30, 'FontWeight','bold');   % rho and p inside the panel

        xlabel('Casual Chat','FontWeight','bold')
        ylabel('Conflict','FontWeight','bold')
        title(BehaviouralCategory{c}, 'Interpreter','none','FontSize',20,'FontWeight','bold')

        if useFixedAxisLimits
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

%% ==================== CATEGORY-LEVEL TABLE ====================
nRows = nMetrics * numCategories;
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
for m = 1:nMetrics
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
DYMO_writeTable(CatTable, 'CategoryLevelSpearCorr.csv');
DYMO_writeTable(CatTable, 'CategoryLevelSpearCorr.xlsx');
disp(CatTable)
