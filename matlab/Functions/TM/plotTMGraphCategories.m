function [fig, ax, cb] = plotTMGraphCategories(g, colorvar, members, cmap, catNames, colorvarname, titleText, varargin)
%PLOTTMGRAPHCATEGORIES  Draw a temporal mapper network coloured by the four
%behavioural categories, with a labelled category colour bar.
%
%   fig = plotTMGraphCategories(g, colorvar, members, cmap, catNames, ...
%                               colorvarname, titleText)
%   fig = plotTMGraphCategories(..., 'nodescatter', true)   % extra
%         name/value pairs are passed straight to tmapper2's plottmgraph
%
% plottmgraph is called directly rather than plotgraphtcm: plotgraphtcm also
% draws the geodesic recurrence plot, which needs an N-by-N matrix over ALL
% time points (huge). plottmgraph gives the same network figure with none of
% that cost.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

nCat = numel(catNames);

fig = figure('Position',[10 10 1000 800]);
ax  = axes(fig);

[ax, cb] = plottmgraph(g, colorvar, members, ...
    'nodesizerange', [3 8], ...
    'colorlabel',    colorvarname, ...
    'labelmethod',   'mode', ...
    'nodesizemode',  'log', ...
    'cmap',          cmap, ...
    'nodeclim',      [1 nCat], ...
    'ax',            ax, ...
    varargin{:});

colormap(ax, cmap);
clim(ax, [1 nCat]);

cb.Ticks                = 1:nCat;
cb.TickLabels           = catNames;
cb.Label.String         = colorvarname;
cb.TickLabelInterpreter = 'none';

title(ax, titleText, 'Interpreter', 'none');
end
