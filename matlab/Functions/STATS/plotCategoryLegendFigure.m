function fig = plotCategoryLegendFigure(catNames, cmap, seriesNames)
%PLOTCATEGORYLEGENDFIGURE  A figure that is nothing but the category key.
%
%   fig = plotCategoryLegendFigure(catNames, cmap)
%   fig = plotCategoryLegendFigure(catNames, cmap, {'Casual Chat','Conflict'})
%
% The metric figures stay uncluttered: the key to the behavioural categories is
% saved once, as its own figure, instead of being repeated inside every metric
% figure.
%
% INPUTS
%   catNames    : behavioural category names, in category order
%                 (BehaviouralCategory from the temporal mapper data).
%   cmap        : the category colour map, same order (cmap from that data).
%   seriesNames : optional, the two condition names. Given, the key is a grid:
%                 one row per category, one column per condition, each category
%                 shown in its own colour for the first condition and in the
%                 lighter shade for the second - exactly how
%                 plotCategoryPairedBars draws them. Left out, the key is a
%                 single column of the four category colours, which is what the
%                 per-category scatter figures use.
%
% Everything is drawn directly rather than with a MATLAB legend object: a legend
% sits in one corner of its axes and leaves the middle of the figure empty,
% while this key fills the figure.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3, seriesNames = {}; end

nCat = numel(catNames);

fig = figure('Color','w');
% This figure places everything by hand, so the shared layout step in
% fitFigureLayout must leave it alone (see the note there).
fig.UserData.SkipLayout = true;
ax  = axes(fig, 'Position', [0.02 0.02 0.96 0.96]);   % the axes fills the figure,
                                                      % with a small margin so no
                                                      % label touches the edge
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0 1]);
ylim(ax, [0 1]);

if isempty(seriesNames)
    % just the category colours: that is exactly what plotLegendFigure draws,
    % so use it rather than repeating the drawing here
    close(fig);
    fig = plotLegendFigure(catNames, cmap(1:nCat,:), 'Behavioural categories');
    return
end

% ---------- grid: categories down the side, conditions across the top ----------
headerY = 0.93;
top     = 0.84;
bottom  = 0.08;
rowH    = (top - bottom) / nCat;

labelX   = 0.03;                 % category names (inside the axes margin above)
swatchW  = 0.17;
colX     = [0.50, 0.75];         % left edge of each condition's swatch

% condition names above their column
for k = 1:min(2, numel(seriesNames))
    text(ax, colX(k) + swatchW/2, headerY, seriesNames{k}, ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'FontSize',32, 'FontWeight','bold', 'Interpreter','none');
end

for c = 1:nCat
    yC = top - (c - 0.5)*rowH;

    % category name
    text(ax, labelX, yC, catNames{c}, 'VerticalAlignment','middle', ...
        'HorizontalAlignment','left', 'FontSize',30, 'FontWeight','bold', ...
        'Interpreter','none');

    % first condition in the category colour, second in the lighter shade
    % (plotCategoryPairedBars uses min(colour + 0.7, 1) for the second)
    drawSwatch(ax, colX(1), swatchW, yC, 0.55*rowH, cmap(c,:));
    drawSwatch(ax, colX(2), swatchW, yC, 0.55*rowH, min(cmap(c,:) + 0.7, 1));
end
end

% ---------------------------------------------------------------------------
function drawSwatch(ax, x, w, yCentre, h, faceColor)
% One colour patch, outlined at the same weight as the bar outlines (4.5).
patch(ax, ...
    'XData', [x, x+w, x+w, x], ...
    'YData', yCentre + [-h/2, -h/2, h/2, h/2], ...
    'FaceColor', faceColor, ...
    'EdgeColor', 'k', ...
    'LineWidth', 4.5);
end
