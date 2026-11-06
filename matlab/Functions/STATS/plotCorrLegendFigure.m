function fig = plotCorrLegendFigure(pointNames, pointColors, titleText, style)
%PLOTCORRLEGENDFIGURE  The key to a scatter figure: dyads, CI band, fitted line.
%
%   fig = plotCorrLegendFigure({'Dyads'}, olive)
%   fig = plotCorrLegendFigure(catNames, cmap, '', 'category')
%
% WHY THIS IS NOT plotLegendFigure
% plotLegendFigure draws a filled square with a heavy black outline per entry -
% the swatch that matches a BAR. The key to a correlation panel would then show
% three bar swatches labelled Dyads, 95% CI and Linear fit, none of which is a
% bar.
%
% ONE COLOUR PER SERIES
% Every mark of a series - the dyad points, the confidence band and the fitted
% line - is drawn in that series' own colour, in the panels and here, so the
% whole-graph and the per-category panels are drawn alike and this one key
% describes both.
%
% THE TWO STYLES
%   'whole'    one series: three rows - the point, the band, the line - all in
%              that series' colour.
%   'category' one row per behavioural category, each a composite of band, line
%              and point in that category's colour, with a two-line note along
%              the bottom of the figure saying what the three parts are. Three
%              rows per category would run to twelve rows and say the same
%              thing four times.
%
% The panels' exact values are the constants below, so the key cannot drift from
% the figures. The marker alone is scaled up: at the panel's 45-50 pt^2 it would
% be a speck beside 34 pt text in a 13 x 10 inch figure. Its shape, colour, edge
% and translucency are the panel's.
%
% INPUTS
%   pointNames  : cell array (or string array) of labels - the point series for
%                 'whole' (normally {'Dyads'}), the categories for 'category'.
%   pointColors : n-by-3 RGB, same order as pointNames.
%   titleText   : optional title. Left out, the figure has no title.
%   style       : 'whole' (default) or 'category'.
%
% Everything is placed by hand and the axes is switched off, so the figure sets
% UserData.SkipLayout and fitFigureLayout leaves it alone - the title is drawn as
% an annotation in a reserved band, for the reason given in plotLegendFigure.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3, titleText = ''; end
if nargin < 4 || isempty(style), style = 'whole'; end

style      = validatestring(style, {'whole','category'});
pointNames = cellstr(string(pointNames));
nPts       = numel(pointNames);

if size(pointColors,1) ~= nPts
    error('plotCorrLegendFigure:sizeMismatch', ...
        'pointColors must have one row per name (%d names, %d rows).', ...
        nPts, size(pointColors,1));
end

% ---- the panels' marks, so the key cannot drift from the figures ----
isCat      = strcmp(style, 'category');
BAND_ALPHA = 0.20;                 % fill(..., colour, 'FaceAlpha',0.20)
LINE_WIDTH = 2.5;                  % plot(..., 'Color',colour, 'LineWidth',2.5)
PT_SIZE    = 900;                  % scaled up for the key; see the note above

if isCat
    PT_ALPHA = 1.0;   PT_EDGE = 'k';      % per-category: opaque, black edge
else
    PT_ALPHA = 0.7;   PT_EDGE = 'none';   % plotSpearmanComparison: translucent
end

if isCat
    nRows = nPts;          % one row per category; the explanation goes BELOW
else
    nRows = 3;             % point, band, line
end

hasTitle = ~isempty(titleText);

fig = figure('Color','w');
fig.UserData.SkipLayout = true;

% The category key explains its marks in a line of text. At 34 pt that line
% would run off the right edge, so it is not a row inside the axes: a band is
% reserved for it at the BOTTOM of the figure and it is drawn there as an
% annotation, in figure-normalised units, on two shorter lines at a smaller
% size. Being an annotation, it cannot fall outside the figure however long it
% is - the same reasoning as the title.
noteBand = 0.14 * isCat;

axTop = 0.96;
if hasTitle
    axTop = 0.80;                       % room for the title band above
end
axPos = [0.02, 0.02 + noteBand, 0.96, axTop - noteBand];

ax = axes(fig, 'Position', axPos);
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0 1]);
ylim(ax, [0 1]);

top     = 0.92;
bottom  = 0.08;
rowH    = (top - bottom) / nRows;
markX   = 0.08;                  % left edge of the mark column
markW   = 0.16;
labelX  = markX + markW + 0.04;
markMid = markX + markW/2;

rowY = @(r) top - (r - 0.5)*rowH;

if isCat

    for i = 1:nPts
        yC = rowY(i);
        drawBand(ax, markX, markW, yC, 0.45*rowH, pointColors(i,:), BAND_ALPHA);
        plot(ax, [markX, markX+markW], [yC yC], ...
            'Color', pointColors(i,:), 'LineWidth', LINE_WIDTH);
        scatter(ax, markMid, yC, PT_SIZE, pointColors(i,:), 'filled', ...
            'MarkerFaceAlpha', PT_ALPHA, 'MarkerEdgeColor', PT_EDGE);
        addLabel(ax, labelX, yC, pointNames{i});
    end


else

    c = pointColors(1,:);

    % the dyads
    yC = rowY(1);
    scatter(ax, markMid, yC, PT_SIZE, c, 'filled', ...
        'MarkerFaceAlpha', PT_ALPHA, 'MarkerEdgeColor', PT_EDGE);
    addLabel(ax, labelX, yC, pointNames{1});

    % the confidence band
    yC = rowY(2);
    drawBand(ax, markX, markW, yC, 0.55*rowH, c, BAND_ALPHA);
    addLabel(ax, labelX, yC, '95% CI');

    % the fitted line
    yC = rowY(3);
    plot(ax, [markX, markX+markW], [yC yC], ...
        'Color', c, 'LineWidth', LINE_WIDTH);
    addLabel(ax, labelX, yC, 'Linear fit');

end

if isCat
    annotation(fig, 'textbox', [0.02 0.01 0.96 0.12], ...
        'String', {'each colour is one behavioural category', ...
                   'point = dyad    band = 95% CI    line = linear fit'}, ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'FontSize', 26, 'FontWeight','bold', ...
        'EdgeColor','none', 'FitBoxToText','off', 'Interpreter','none');
end

if hasTitle
    annotation(fig, 'textbox', [0.02 0.84 0.96 0.13], ...
        'String', titleText, ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'FontSize', 34, 'FontWeight','bold', ...
        'EdgeColor','none', 'FitBoxToText','off', 'Interpreter','none');
end
end

% ---------------------------------------------------------------------------
function drawBand(ax, x, w, yC, h, color, alpha)
patch(ax, 'XData', [x, x+w, x+w, x], 'YData', yC + [-h/2, -h/2, h/2, h/2], ...
    'FaceColor', color, 'FaceAlpha', alpha, 'EdgeColor', 'none');
end

% ---------------------------------------------------------------------------
function addLabel(ax, x, y, str)
% 'none' so a category name with an underscore is not read as TeX
text(ax, x, y, str, ...
    'VerticalAlignment','middle', 'HorizontalAlignment','left', ...
    'FontSize', 34, 'FontWeight','bold', 'Interpreter','none');
end
