function fig = plotLegendFigure(names, colors, titleText)
%PLOTLEGENDFIGURE  A figure that is nothing but a key: one swatch per name.
%
%   fig = plotLegendFigure({'Casual Chat','Conflict'}, [c1; c2])
%   fig = plotLegendFigure(names, colors, 'Series')
%
% The result figures carry no legend; the key is saved once as its own figure
% instead. This draws that key for any set of names and colours: the two
% conditions for the bar figures, or the points / CI band / fitted line for the
% correlation figures.
%
% INPUTS
%   names     : cell array of labels, one per row of colors.
%   colors    : n-by-3 RGB, in the same order.
%   titleText : optional title. Left out, the figure has no title.
%
% Everything is placed by hand and the axes is switched off, so the figure sets
% UserData.SkipLayout and fitFigureLayout leaves it alone (a figure laid out by
% hand must not be re-laid out; see the note there).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3, titleText = ''; end

n = numel(names);

hasTitle = ~isempty(titleText);

fig = figure('Color','w');
fig.UserData.SkipLayout = true;

% WHERE THE TITLE GOES, AND WHY IT IS NOT A title()
% This figure sets UserData.SkipLayout, so the shared layout step (fitFigureLayout)
% leaves it alone and reserves no space for anything. A MATLAB title() is drawn
% ABOVE its axes, so with an axes that fills the figure the title falls off the top
% edge and is cut, and placing the text inside the axes near the top is still
% marginal.
% So when there is a title the axes is SHRUNK to leave a band at the top, and the
% title is drawn in that band as an annotation, whose coordinates are normalised to
% the FIGURE rather than to the axes. That makes it impossible for the title to sit
% outside the figure, whatever the figure's size or the length of the text.
if hasTitle
    axPos = [0.02 0.02 0.96 0.80];      % room for the title band above
else
    axPos = [0.02 0.02 0.96 0.96];
end

ax = axes(fig, 'Position', axPos);
hold(ax, 'on');
axis(ax, 'off');
xlim(ax, [0 1]);
ylim(ax, [0 1]);

top     = 0.92;                          % rows use the full height of the axes,
bottom  = 0.08;                          % which is already shortened above
rowH    = (top - bottom) / n;
swatchX = 0.08;
swatchW = 0.16;
labelX  = swatchX + swatchW + 0.04;

for i = 1:n
    yC = top - (i - 0.5)*rowH;
    h  = 0.55 * rowH;

    patch(ax, ...
        'XData', [swatchX, swatchX+swatchW, swatchX+swatchW, swatchX], ...
        'YData', yC + [-h/2, -h/2, h/2, h/2], ...
        'FaceColor', colors(i,:), ...
        'EdgeColor', 'k', ...
        'LineWidth', 4.5);      % the same weight as the bar outlines

    text(ax, labelX, yC, names{i}, ...
        'VerticalAlignment','middle', 'HorizontalAlignment','left', ...
        'FontSize', 34, 'FontWeight','bold', 'Interpreter','none');
end

if hasTitle
    % the reserved band, in figure-normalised units, so it is inside by construction
    annotation(fig, 'textbox', [0.02 0.84 0.96 0.13], ...
        'String', titleText, ...
        'HorizontalAlignment','center', 'VerticalAlignment','middle', ...
        'FontSize', 34, 'FontWeight','bold', ...
        'EdgeColor','none', 'FitBoxToText','off', 'Interpreter','none');
end
end
