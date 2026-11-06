function [ax, cb] = plotTMGraphMarkNodes(ax, g_simp, members, Cat, markNodes, markLabels, ringColor)
%PLOTTMGRAPHMARKNODES  Draw the TM graph in one axes and ring chosen nodes.
%
%   [ax, cb] = plotTMGraphMarkNodes(ax, g_simp, members, Cat)
%   [ax, cb] = plotTMGraphMarkNodes(ax, g_simp, members, Cat, markNodes, markLabels, ringColor)
%
% The graph is coloured by behavioural category, and the colour bar shows the
% category NAMES (not the numbers 1..4).
%
% INPUTS
%   ax         : axes to draw into.
%   g_simp     : simplified graph from filtergraph.
%   members    : filtergraph's members (numNodes-by-1 cell array).
%   Cat        : struct from categorizeVelocity (colorvar, cmap,
%                BehaviouralCategory, colorvarname).
%   markNodes  : (optional) node numbers to ring, e.g. the node shown beside
%                the graph. [] = ring nothing.
%   markLabels : (optional) cell array of short labels drawn next to each ring.
%                [] = no labels.
%   ringColor  : (optional) colour of the ring. Default white [1 1 1].
%                A thin dark ring is drawn underneath, so a white ring stays
%                visible over pale nodes and over the white background.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 5, markNodes  = []; end
if nargin < 6, markLabels = {}; end
if nargin < 7 || isempty(ringColor), ringColor = [1 1 1]; end

nCat = numel(Cat.BehaviouralCategory);

[~, cb] = plottmgraph(g_simp, Cat.colorvar, members, ...
    'nodesizerange', [3 8], ...
    'colorlabel',    Cat.colorvarname, ...
    'labelmethod',   'mode', ...
    'nodesizemode',  'log', ...
    'cmap',          Cat.cmap, ...
    'nodeclim',      [1 nCat], ...
    'ax',            ax);

% ---- colour bar with the category names ----
colormap(ax, Cat.cmap);
clim(ax, [1 nCat]);
cb.Ticks                = 1:nCat;
cb.TickLabels           = Cat.BehaviouralCategory;
cb.Label.String         = Cat.colorvarname;
cb.TickLabelInterpreter = 'none';

% ---- ring the chosen nodes ----
if ~isempty(markNodes)
    hg = findobj(ax, 'Type', 'GraphPlot');
    if ~isempty(hg)
        hg = hg(1);
        hold(ax, 'on');
        for iMark = 1:numel(markNodes)
            n  = markNodes(iMark);
            nx = hg.XData(n);
            ny = hg.YData(n);

            % dark ring first, ring colour on top: this keeps a white ring
            % visible whatever is behind it
            plot(ax, nx, ny, 'o', 'MarkerSize', 20, 'LineWidth', 3.5, ...
                'MarkerEdgeColor', [0.15 0.15 0.15]);
            plot(ax, nx, ny, 'o', 'MarkerSize', 20, 'LineWidth', 2, ...
                'MarkerEdgeColor', ringColor);

            if ~isempty(markLabels)
                text(ax, nx, ny, ['  ' markLabels{iMark}], 'FontSize', 11, ...
                    'FontWeight', 'bold', 'Color', ringColor, ...
                    'Interpreter', 'none');
            end
        end
        hold(ax, 'off');
    end
end
end
