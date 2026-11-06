%% ====================  Whole Graph Cycle Metrics Correlation Analysis ====================
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the cycle files named in DYMO_files.m. Metrics from
% wholeGraphCycleMetrics (NaN, not 0, for missing dyads). Results (rho, p,
% bootstrap CI) are also written to a table.

if ~exist('wholeGraphCycleMetrics','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('Cycles_Correlation');

% The final figure set replaces this script's
% figures with the correlation bar figures (SpearCorr_*_Bars_29Oct26, CorrPairBars_PerCategory_28Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


%% Load the data
tic
load(F.GTK_Cycles, 'GTKCycles', 'GTKVis');
load(F.MAN_Cycles, 'MANCycles', 'MANVis');
toc;

%% ==================== Whole Graph Cycle Metrics ====================
Stats.GTK = wholeGraphCycleMetrics(GTKCycles, GTKVis);
Stats.MAN = wholeGraphCycleMetrics(MANCycles, MANVis);

% (winnerProp is a per-cycle list, not a dyad-level number, so it is not
%  correlated.) The labels are the ones the paired t-test script uses for the
% same metrics (WholeGraphsCycles_Above3Min), so a metric carries one title
% across the whole pipeline.
metrics      = {'CycleLenMean', 'meanEntropy', 'cycleDensity', 'CycleCount'};
metricLabels = {'Cycle Mean Length', 'mean Entropy', 'Cycle Density', 'CycleCount'};

nBoot = 10000;

%% ==================== CORRELATIONS + FIGURES ====================
tic;
if makeFigures   % see the note at the top
figureFolder = DYMO_figureFolder('Cycles_Correlation','WholeGraph_Scatter');

purple = [0.5020, 0.0000, 0.5020];

% ---- the key to the scatter, as its own figure ----
% The panels carry no legend.
% plotCorrLegendFigure draws the panel's own marks - a translucent filled
% circle, the 30 % grey CI band and the 2 pt fitted line - instead of the three
% bar swatches plotLegendFigure gave. It adds the CI and fit
% rows itself, so only the point series is passed in.
figLegend = plotCorrLegendFigure({'Dyads'}, purple);
SavePublicationFigure('SeriesLegend', figLegend, figureFolder, [13 10]);
close(figLegend);
end   % if makeFigures

% ONE FORMAT FOR EVERY CORRELATION TABLE
% rho, its bootstrap interval, and the verdict that interval implies. The
% p-value is no longer reported: the confidence interval is the inference
% throughout this pipeline, and where the two disagreed - as they did for two
% cycles rows, p < .05 with an interval straddling zero - the reader was left
% to choose between them.
ResultsTable = table(strings(numel(metrics),1), nan(numel(metrics),1), nan(numel(metrics),1), ...
    nan(numel(metrics),1), nan(numel(metrics),1), strings(numel(metrics),1), ...
    'VariableNames', {'Metric','N_dyads','SpearmanRho','CI_Lower','CI_Upper','Verdict'});

fprintf('Whole-Graph Correlation Analysis (GTK vs MAN)\n')
fprintf('---------------------------\n')

for m = 1:numel(metrics)

    metric = metrics{m};
    xC = Stats.GTK.(metric);
    xS = Stats.MAN.(metric);

    [rho, p, CI, N] = spearmanWithCI(xC, xS, nBoot);
    fprintf('%s:  GTK and MAN: rho=%.4f, p=%.4f (N=%d)\n', metricLabels{m}, rho, p, N);

    ResultsTable(m,:) = {string(metricLabels{m}), N, rho, CI(1), CI(2), DYMO_ciVerdict(CI, 'Positive association', ...
                           'Negative association', 'No significant association')};

if makeFigures   % see the note at the top
    valid = isfinite(xC) & isfinite(xS);
    xC = xC(valid);
    xS = xS(valid);
    if N < 3
        continue
    end

    fig = figure('Position',[100 100 700 600]);
    hold on;

    scatter(xC, xS, 50, 'filled', 'MarkerEdgeColor',purple, 'MarkerFaceColor',purple, 'LineWidth',2.5);

    % A metric that is the same in every dyad (all graphs connected, say, so
    % numComponents is 1 everywhere) gives a rank-deficient design matrix: the
    % slope is undefined, and the fitted line and CI band would be meaningless.
    % MATLAB only warns, so the guard is here. Spearman's rho is NaN for a
    % constant variable too, which is what the table will show.
    if std(xC) > 0 && std(xS) > 0
        mdl = fitlm(xC, xS);
        xx  = linspace(min(xC), max(xC), 100)';
        [yy, CIreg] = predict(mdl, xx);

        fill([xx; flipud(xx)], [CIreg(:,1); flipud(CIreg(:,2))], purple, ...
             'FaceAlpha',0.20, 'EdgeColor','none');
        plot(xx, yy, 'Color',purple, 'LineWidth',2);
    else
        fprintf(['%s: no line fitted - it has no variation across dyads ' ...
                 '(SD: Casual Chat %.3g, Conflict %.3g)\n'], metric, std(xC), std(xS));
        text(0.05, 0.05, 'no variation: no line fitted', 'Units','normalized', ...
            'FontSize',26, 'FontWeight','bold', 'Color',[0.4 0.4 0.4]);
    end

    text(0.05, 0.95, sprintf('rho = %s\n%s', DYMO_numText(rho), DYMO_pText(p)), ...
        'Color', DYMO_sigColor(p), ...
        'Units','normalized', 'VerticalAlignment','top', ...
        'FontSize',30, 'FontWeight','bold');   % rho and p inside the panel

    xlabel('Casual Chat','FontWeight','bold','FontSize',14);
    ylabel('Conflict',   'FontWeight','bold','FontSize',14);
    % No legend inside the figure: the points, the band
    % and the fitted line are the same in every panel of every metric, so the key
    % does not need repeating in each one.
    title(sprintf('Correlation Analysis: %s', metricLabels{m}), 'FontWeight','bold', 'FontSize',18);

    box on; grid on;
    set(gca, 'LineWidth',1.5, 'FontSize',14, 'FontWeight','bold');

    % [13 16] inches: a single-panel scatter, so not the 25-inch width of a
    % multi-panel figure.
    SavePublicationFigure(metric, fig, figureFolder, [13 16]);
    close(fig)
end   % if makeFigures
end

disp(ResultsTable)
ResultsTable = DYMO_roundTable(ResultsTable);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(ResultsTable, 'WholeGraphCycle_SpearCorr.csv');   % table in the current folder
toc;
