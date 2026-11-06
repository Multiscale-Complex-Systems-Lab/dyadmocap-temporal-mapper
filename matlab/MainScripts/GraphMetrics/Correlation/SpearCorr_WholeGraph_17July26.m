%%%%%=========Correlation per metric for the Whole Graph Across Condition===============%%%%%%%%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.
%
% Loads the TM data files named in DYMO_files.m. Metrics from graphStatsWhole.
% Each metric's rho / p / bootstrap CI is computed ONCE (spearmanWithCI) and
% re-used for the figure and the table.

if ~exist('graphStatsWhole','file'), error('Run DYMO_setup.m first.'); end
F = DYMO_files('GraphMetrics_Correlation');

% The final figure set replaces this script's
% figures with the correlation bar figures (SpearCorr_*_Bars_29Oct26, CorrPairBars_PerCategory_28Oct26).
% This script is kept for its TABLES; its figures are made only if
% makeFigures = true.
makeFigures = false;


nBoot = 10000;

tic;
load(F.GTK_TM, 'GTK_AllDyads_GraphData');
load(F.MAN_TM, 'MAN_AllDyads_GraphData');
toc;

%% ==================== Temporal Mapper Whole Graph STATS ====================
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

%% ==================== CORRELATIONS (once) ====================
tic;
nM = numel(metrics);
rhoAll = nan(nM,1);   % rho and p per metric, for the scatter panels further down
pAll   = nan(nM,1);
% ONE FORMAT FOR EVERY CORRELATION TABLE
% rho, its bootstrap interval, and the verdict that interval implies. The
% p-value is no longer reported: the confidence interval is the inference
% throughout this pipeline, and where the two disagreed - as they did for two
% cycles rows, p < .05 with an interval straddling zero - the reader was left
% to choose between them.
% The Metric column now carries the readable label, as every other table does.
ResultsTable = table(strings(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), nan(nM,1), strings(nM,1), ...
    'VariableNames', {'Metric','N_dyads','SpearmanRho','CI_Lower','CI_Upper','Verdict'});

fprintf('Whole-Graph Correlation Analysis (GTK vs MAN)\n')
fprintf('---------------------------\n')

for m = 1:nM
    metric = metrics{m};
    [rho, p, CI, N] = spearmanWithCI(Stats.GTK.(metric), Stats.MAN.(metric), nBoot);

    % for the scatter panels below: the table carries no p-value, but the
    % figures annotate one
    rhoAll(m) = rho;
    pAll(m)   = p;

    ResultsTable(m,:) = {string(metricLabels{m}), N, rho, CI(1), CI(2), DYMO_ciVerdict(CI, 'Positive association', ...
                           'Negative association', 'No significant association')};

    fprintf('%s:\n', metricLabels{m})
    fprintf('GTK and MAN:   rho=%.4f, p=%.4f\n', rho, p);
end
disp(ResultsTable)
ResultsTable = DYMO_roundTable(ResultsTable);   % 3 significant figures, p to 3 dp (APA)
DYMO_writeTable(ResultsTable, 'WhGSpearCorr.csv');
DYMO_writeTable(ResultsTable, 'WhGSpearCorr.xlsx');
toc;

%% ==================== VISUALIZE GTK vs MAN ====================
tic;
if makeFigures   % see the note at the top
olive = [0.71, 0.73, 0.02];
figureFolder = DYMO_figureFolder('GraphMetrics_Correlation','WholeGraph_Scatter');

% ---- the key to the scatter, as its own figure ----
% The panels carry no legend.
% plotCorrLegendFigure draws the panel's own marks - a translucent filled
% circle, the 30 % grey CI band and the 2 pt fitted line - instead of the three
% bar swatches plotLegendFigure gave. It adds the CI and fit
% rows itself, so only the point series is passed in.
figLegend = plotCorrLegendFigure({'Dyads'}, olive);
SavePublicationFigure('SeriesLegend', figLegend, figureFolder, [13 10]);
close(figLegend);

for m = 1:nM

    metric = metrics{m};
    xC = Stats.GTK.(metric);
    xS = Stats.MAN.(metric);
    valid = isfinite(xC) & isfinite(xS);
    xC = xC(valid);
    xS = xS(valid);
    if numel(xC) < 3
        continue
    end
    rho = rhoAll(m);
    p   = pAll(m);

    fig = figure('Position',[100 100 700 600]);
    hold on;

    scatter(xC, xS, 50, 'filled', 'MarkerEdgeColor',olive, 'MarkerFaceColor',olive, 'LineWidth',2.5);

    % A metric that is the same in every dyad (all graphs connected, say, so
    % numComponents is 1 everywhere) gives a rank-deficient design matrix: the
    % slope is undefined, and the fitted line and CI band would be meaningless.
    % MATLAB only warns, so the guard is here. Spearman's rho is NaN for a
    % constant variable too, which is what the table will show.
    if std(xC) > 0 && std(xS) > 0
        mdl = fitlm(xC, xS);
        xx  = linspace(min(xC), max(xC), 100)';
        [yy, CIreg] = predict(mdl, xx);
        fill([xx; flipud(xx)], [CIreg(:,1); flipud(CIreg(:,2))], olive, ...
             'FaceAlpha',0.20, 'EdgeColor','none');
        plot(xx, yy, 'Color',olive, 'LineWidth',2);
    else
        fprintf(['%s: no line fitted - %s has no variation across dyads ' ...
                 '(SD: Casual Chat %.3g, Conflict %.3g)\n'], ...
                 metric, metric, std(xC), std(xS));
        text(0.05, 0.05, 'no variation: no line fitted', 'Units','normalized', ...
            'FontSize',26, 'FontWeight','bold', 'Color',[0.4 0.4 0.4]);
    end

    text(0.05, 0.95, sprintf('rho = %s\n%s', DYMO_numText(rho), DYMO_pText(p)), ...
        'Color', DYMO_sigColor(p), ...
        'Units','normalized', 'VerticalAlignment','top', ...
        'FontSize',30, 'FontWeight','bold');   % matches the NodeDistance corr plots

    xlabel('Casual Chat','FontWeight','bold','FontSize',14);
    ylabel('Conflict',   'FontWeight','bold','FontSize',14);
    title(metricLabels{m}, 'FontWeight','bold', 'FontSize',18, 'Interpreter','none');

    box on; grid on;
    set(gca, 'LineWidth',1.5, 'FontSize',14, 'FontWeight','bold');

    % [13 16] inches: these are single-panel scatters, so the 25-inch width of a
    % two-panel figure made them far too wide. Same size
    % as the whole-graph bar figures.
    SavePublicationFigure(metric, fig, figureFolder, [13 16]);
    close(fig)
end
toc;

end   % if makeFigures