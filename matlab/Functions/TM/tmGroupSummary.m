function S = tmGroupSummary(grp, GraphData, CategoryAll, AnglesAll, VelocityAll, Fs, bandEdges)
%TMGROUPSUMMARY  Across-dyad (group-level) summaries of the TM stage.
%
%   S = tmGroupSummary(grp, GraphData, CategoryAll, AnglesAll, VelocityAll, Fs)
%   S = tmGroupSummary(..., bandEdges)
%
% The TM scripts make one figure per dyad. This function adds the overall
% picture across all included dyads of one condition: the same quantities,
% summarised over dyads, as figures and tables. Both TM scripts call it, so
% there is one copy of this code.
%
% WHAT IT PRODUCES  (grp is 'GTK' or 'MAN'; <tag> is added by DYMO_writeTable)
%   Tables (in Tables_<tag>\):
%     <grp>_Group_CategoryPercent   % of time in each behavioural category, per dyad
%     <grp>_Group_GraphSize         samples, nodes, edges and compression, per dyad
%     <grp>_Group_AngleSummary      mean and SD of each joint angle, per dyad and person
%     <grp>_Group_VelocityBands     % of angular-velocity power per frequency band
%   Figures (in Figures_<tag>\TM_<grp>\09_GroupSummary\<name>\):
%     CategoryPercent   bar of the mean % per category across dyads, with SEM and
%                       one grey dot per dyad
%     GraphSize         one box per quantity (nodes, edges, compression)
%     AngleSpread       per angle, the spread across dyads of that angle's SD
%     VelocityBands     per frequency band, the spread across dyads
%
% INPUTS
%   grp         : 'GTK' or 'MAN', used in titles and file names.
%   GraphData   : the cell array saved by the TM script (one struct per dyad,
%                 empty where a dyad was excluded).
%   CategoryAll : the velocity-category cell array (one struct per dyad).
%   AnglesAll   : the angle cell array (nDyads-by-2 of structs from
%                 computeJointAngles). Pass [] to skip the angle summary.
%   VelocityAll : the velocity cell array (one struct per dyad with field
%                 velocity_all). Pass [] to skip the band summary.
%   Fs          : sampling rate (Hz), measured by the TM script.
%   bandEdges   : (optional) band edges in Hz for the velocity bands.
%                 Default [0 2 5 10]; the last band runs to Nyquist.
%
% OUTPUT
%   S : struct of the tables, so a script can print or reuse them.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 7 || isempty(bandEdges), bandEdges = [0 2 5 10]; end

dyads   = find(~cellfun(@isempty, GraphData));      % dyads that have a graph
nDyads  = numel(dyads);
figRoot = {['TM_' grp], '09_GroupSummary'};
S       = struct();

if nDyads == 0
    warning('tmGroupSummary: no dyads with a graph, nothing to summarise.');
    return
end

catNames = GraphData{dyads(1)}.BehaviouralCategory;
cmap     = GraphData{dyads(1)}.cmap;
nCat     = numel(catNames);

% ================= 1. time spent in each behavioural category =================
% One row per dyad, one column per category.
pct = nan(nDyads, nCat);
for i = 1:nDyads
    C = CategoryAll{dyads(i)};
    if isempty(C), continue; end
    pct(i,:) = 100 * histcounts(C.colorvar, 0.5:1:nCat+0.5) / numel(C.colorvar);
end

T = array2table(pct, 'VariableNames', matlab.lang.makeValidName(catNames));
T = addvars(T, dyads(:), 'Before', 1, 'NewVariableNames', 'Dyad');
DYMO_writeTable(T, [grp '_Group_CategoryPercent.csv']);
S.CategoryPercent = T;

fig = figure('Color','w', 'Position', [100 100 1000 700]);
b = bar(mean(pct, 1, 'omitnan'), 'FaceColor', 'flat');
b.CData = cmap;
hold on;
% SEM across dyads, and every dyad as a grey dot, so the spread is visible
sem = std(pct, 0, 1, 'omitnan') ./ sqrt(sum(~isnan(pct), 1));
errorbar(1:nCat, mean(pct, 1, 'omitnan'), sem, 'k', 'LineStyle', 'none', 'LineWidth', 1.2);
for c = 1:nCat
    x = c + 0.12 * (rand(nDyads,1) - 0.5) * 2;      % small horizontal jitter
    plot(x, pct(:,c), 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.6 0.6 0.6], ...
        'MarkerEdgeColor', 'none');
end
hold off;
set(gca, 'XTick', 1:nCat, 'XTickLabel', catNames, 'FontSize', 11);
ylabel('% of time');
title(sprintf('%s: time in each behavioural category, %d dyads (mean, SEM, one dot per dyad)', ...
    grp, nDyads), 'Interpreter', 'none');
grid on;
AutoSavePublishableFigure([grp '_Group_CategoryPercent'], fig, ...
    DYMO_figureFolder(figRoot{:}, 'CategoryPercent'));
close(fig);

% ================= 2. graph size across dyads =================
% Compression = samples per node: how much the mapper summarised the recording.
nSamples = nan(nDyads,1);  nNodes = nan(nDyads,1);  nEdges = nan(nDyads,1);
for i = 1:nDyads
    D = GraphData{dyads(i)};
    nSamples(i) = D.numSamples;
    nNodes(i)   = numnodes(D.g_simp);
    nEdges(i)   = numedges(D.g_simp);
end
compression = nSamples ./ nNodes;

T = table(dyads(:), nSamples, nSamples/Fs, nNodes, nEdges, compression, ...
    'VariableNames', {'Dyad','Samples','Duration_s','Nodes','Edges','SamplesPerNode'});
DYMO_writeTable(T, [grp '_Group_GraphSize.csv']);
S.GraphSize = T;

fig = figure('Color','w', 'Position', [100 100 1200 600]);
tl  = tiledlayout(fig, 1, 3, 'TileSpacing','compact');
plotOneBox(nexttile(tl), nNodes,      'Nodes');
plotOneBox(nexttile(tl), nEdges,      'Edges');
plotOneBox(nexttile(tl), compression, 'Samples per node');
title(tl, sprintf('%s: TM graph size across %d dyads', grp, nDyads), 'Interpreter','none');
AutoSavePublishableFigure([grp '_Group_GraphSize'], fig, ...
    DYMO_figureFolder(figRoot{:}, 'GraphSize'));
close(fig);

% ================= 3. joint angles across dyads =================
% A time series cannot be averaged across dyads (different lengths, no common
% alignment), so each dyad contributes the MEAN and the SD of each angle, and
% the figure shows how those vary across dyads.
if ~isempty(AnglesAll)
    angleNames = fieldnames(AnglesAll{dyads(1),1});
    nAng       = numel(angleNames);
    rows = {};
    meanSD = nan(nDyads, nAng, 2);      % dyad x angle x person: the SD
    for i = 1:nDyads
        d = dyads(i);
        for personIdx = 1:2
            A = AnglesAll{d, personIdx};
            if isempty(A), continue; end
            for a = 1:nAng
                x = A.(angleNames{a});
                rows(end+1,:) = {d, personIdx, angleNames{a}, mean(x,'omitnan'), std(x,'omitnan')}; %#ok<AGROW>
                meanSD(i,a,personIdx) = std(x, 'omitnan');
            end
        end
    end
    T = cell2table(rows, 'VariableNames', {'Dyad','Person','Angle','Mean_deg','SD_deg'});
    DYMO_writeTable(T, [grp '_Group_AngleSummary.csv']);
    S.AngleSummary = T;

    fig = figure('Color','w', 'Position', [100 100 1500 700]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing','compact');
    for personIdx = 1:2
        ax = nexttile(tl);
        drawBoxes(ax, meanSD(:,:,personIdx));
        set(ax, 'XTick', 1:nAng, 'XTickLabel', strrep(angleNames,'_',' '), ...
            'XTickLabelRotation', 45, 'FontSize', 9);
        ylabel(ax, 'SD of the angle over time (degrees)');
        title(ax, sprintf('Person %d', personIdx));
        grid(ax, 'on');
    end
    title(tl, sprintf(['%s: how much each joint angle varied, %d dyads ' ...
        '(one box per angle, one value per dyad)'], grp, nDyads), 'Interpreter','none');
    AutoSavePublishableFigure([grp '_Group_AngleSpread'], fig, ...
        DYMO_figureFolder(figRoot{:}, 'AngleSpread'));
    close(fig);
end

% ================= 4. angular-velocity frequency bands across dyads =========
% The same diagnostic the test script runs on one dyad (powerInBands), here for
% every dyad: it shows whether the velocity is movement-dominated (most power
% below 5 Hz) or jitter-dominated (a large share near Nyquist) across the sample.
if ~isempty(VelocityAll)
    rows = {};
    for i = 1:nDyads
        d = dyads(i);
        V = VelocityAll{d};
        if isempty(V) || ~isfield(V, 'velocity_all'), continue; end
        nF = size(V.velocity_all, 2) / 2;               % columns per person
        for personIdx = 1:2
            if personIdx == 1
                X = V.velocity_all(:, 1:nF);
            else
                X = V.velocity_all(:, nF+1:end);
            end
            [bandPct, bandLabels] = powerInBands(X, Fs, bandEdges);
            for b = 1:numel(bandPct)
                rows(end+1,:) = {d, personIdx, char(bandLabels(b)), bandPct(b)}; %#ok<AGROW>
            end
        end
    end
    if ~isempty(rows)
        T = cell2table(rows, 'VariableNames', {'Dyad','Person','Band','PercentOfPower'});
        DYMO_writeTable(T, [grp '_Group_VelocityBands.csv']);
        S.VelocityBands = T;

        bands = unique(T.Band, 'stable');
        fig = figure('Color','w', 'Position', [100 100 1000 700]);
        vals = nan(height(T)/numel(bands), numel(bands));
        for b = 1:numel(bands)
            v = T.PercentOfPower(strcmp(T.Band, bands{b}));
            vals(1:numel(v), b) = v;
        end
        drawBoxes(gca, vals);
        set(gca, 'XTick', 1:numel(bands), 'XTickLabel', bands, 'FontSize', 11);
        ylabel('% of angular-velocity power');
        title(sprintf(['%s: where the angular-velocity power sits, %d dyads ' ...
            '(both partners, one value each)'], grp, nDyads), 'Interpreter','none');
        grid on;
        AutoSavePublishableFigure([grp '_Group_VelocityBands'], fig, ...
            DYMO_figureFolder(figRoot{:}, 'VelocityBands'));
        close(fig);
    end
end

fprintf('%s: group-level summary written for %d dyads.\n', grp, nDyads);
end

% =====================================================================
function plotOneBox(ax, values, label)
% One box plus the individual dyad values, so n is visible in the figure.
drawBoxes(ax, values(:));
hold(ax, 'on');
x = 1 + 0.12 * (rand(numel(values),1) - 0.5) * 2;      % small horizontal jitter
plot(ax, x, values, 'o', 'MarkerSize', 4, 'MarkerFaceColor', [0.6 0.6 0.6], ...
    'MarkerEdgeColor', 'none');
hold(ax, 'off');
set(ax, 'XTick', []);
ylabel(ax, label);
grid(ax, 'on');
end

% =====================================================================
function drawBoxes(ax, M)
% Draw one box per COLUMN of M (rows are observations, NaN allowed).
%
% boxchart takes EITHER a matrix on its own (one box per column) OR two
% vectors (group index, value). Passing a group MATRIX with a data matrix is
% an error ("Passing xgroupdata is not supported when ydata is a matrix").
% Vectors are used here: the
% matrix is unrolled into one value per row with its column as the group, and
% NaNs (dyads without a value) are dropped.
%
% boxchart needs R2020b or newer, so older MATLAB falls back to boxplot
% (Statistics Toolbox) and, failing that, to mean +/- SD bars, so a run never
% stops at the last figure because of a MATLAB version.
if exist('boxchart', 'file') == 2 || exist('boxchart', 'builtin') == 5
    groupIdx = repmat(1:size(M,2), size(M,1), 1);
    keep     = ~isnan(M);
    boxchart(ax, groupIdx(keep), M(keep));
elseif exist('boxplot', 'file') == 2
    boxplot(ax, M);
else
    m = mean(M, 1, 'omitnan');
    sd = std(M, 0, 1, 'omitnan');
    bar(ax, m);
    hold(ax, 'on');
    errorbar(ax, 1:numel(m), m, sd, 'k', 'LineStyle', 'none');
    hold(ax, 'off');
end
end
