function fig = exploreTMNodes(g_simp, members, skeletonData, timeVel, Cat, zVelocity, titleText, showSpread)
%EXPLORETMNODES  Click a node of the TM graph and see the skeletons of that
%state.
%
%   fig = exploreTMNodes(g_simp, members, skeletonData, timeVel, Cat, zVelocity)
%   fig = exploreTMNodes(..., titleText, showSpread)
%
% The figure has two panels. Left: the temporal mapper graph, coloured by
% behavioural category. Right: the two partners' skeletons at a representative
% moment of whichever node you clicked. Click any node (or anywhere near one)
% to update the right panel.
%
% WHAT A NODE IS, AND WHAT THE SKELETON SHOWS
%   The graph is built from the z-scored angular VELOCITY, so a node is a set
%   of moments in which the pair was MOVING in a similar way. It is not a
%   posture: two moments in the same node can look quite different. The right
%   panel therefore shows
%     * in full colour, the posture at the node's representative moment (the
%       member whose velocity is closest to the node's average velocity, i.e.
%       the most typical moment of that movement state), and
%     * in light grey, up to showSpread other members of the same node, so
%       you can see how much the posture varies within the node.
%   Read it as "what the pair looked like during this movement state", not as
%   "the posture of this node".
%
% INPUTS
%   g_simp       : the simplified graph from filtergraph.
%   members      : filtergraph's members, a numNodes-by-1 cell array of the
%                  velocity sample indices belonging to each node.
%   skeletonData : 1-by-2 cell, one entry per partner, each frames-by-joints-by-3
%                  (as built in the TM scripts: X = x, Y = -z, Z = y, joint 1
%                  = seat).
%   timeVel      : time vector of the velocity samples (s), same length as the
%                  number of samples used for the graph.
%   Cat          : the struct from categorizeVelocity (colorvar, cmap,
%                  BehaviouralCategory, colorvarname).
%   zVelocity    : the z-scored velocity used to build the graph
%                  (samples-by-angles). Used to pick the representative
%                  member. Pass [] to use the middle member in time instead.
%   titleText    : (optional) text for the figure title, e.g. "GTK dyad001".
%   showSpread   : (optional) how many other members to draw in grey.
%                  Default 5. Set 0 for the representative moment only.
%
% NOTE ON FRAME NUMBERING
%   Velocity sample i is the change between frames i and i+1 of the recording,
%   so the skeleton of velocity sample i is drawn from frame i.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 7 || isempty(titleText),  titleText  = 'TM node explorer'; end
if nargin < 8 || isempty(showSpread), showSpread = 5; end

personColors = DYMO_personColors();

% ---- the representative member of every node, worked out once ----
% With zVelocity: the member whose velocity vector is closest to the node's
% mean velocity (the "most typical" moment of that movement state).
% Without it: the middle member in time.
numNodes = numel(members);
repMember = zeros(numNodes, 1);
for n = 1:numNodes
    m = members{n};
    if isempty(zVelocity)
        repMember(n) = m(ceil(numel(m)/2));
    else
        V  = zVelocity(m, :);
        dv = vecnorm(V - mean(V, 1), 2, 2);      % distance to the node's mean
        [~, iMin]    = min(dv);
        repMember(n) = m(iMin);
    end
end

% ---- the figure: graph on the left, skeletons on the right ----
fig = figure('Color', 'w', 'Position', [100 100 1500 750]);
tl  = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');

axGraph = nexttile(tl);
nCat = numel(Cat.BehaviouralCategory);
[~, cb, hg] = plottmgraph(g_simp, Cat.colorvar, members, ...
    'nodesizerange', [3 8], ...
    'colorlabel',    Cat.colorvarname, ...
    'labelmethod',   'mode', ...
    'nodesizemode',  'log', ...
    'cmap',          Cat.cmap, ...
    'nodeclim',      [1 nCat], ...
    'ax',            axGraph);

% the colour bar must show the category NAMES, not the numbers 1..4
colormap(axGraph, Cat.cmap);
clim(axGraph, [1 nCat]);
cb.Ticks                = 1:nCat;
cb.TickLabels           = Cat.BehaviouralCategory;
cb.Label.String         = Cat.colorvarname;
cb.TickLabelInterpreter = 'none';
title(axGraph, 'Click a node');

axSkel = nexttile(tl);

% a marker that shows which node is currently selected
hold(axGraph, 'on');
hSel = plot(axGraph, NaN, NaN, 'ko', 'MarkerSize', 14, 'LineWidth', 2);
hold(axGraph, 'off');

% ---- everything the callback needs, kept in one place ----
S = struct();
S.members      = members;
S.repMember    = repMember;
S.skeletonData = skeletonData;
S.timeVel      = timeVel;
S.Cat          = Cat;
S.personColors = personColors;
S.showSpread   = showSpread;
S.axSkel       = axSkel;
S.hSel         = hSel;
S.nodeX        = hg.XData;
S.nodeY        = hg.YData;

% clicks are caught on the graph itself AND on its axes, so a click that
% lands just beside a node still selects the nearest one
hg.ButtonDownFcn      = @(~, evt) onClick(evt, S);
axGraph.ButtonDownFcn = @(~, evt) onClick(evt, S);

title(tl, sprintf(['%s: click a node to see the skeletons of that movement state.  ' ...
    'Grey = other moments in the same node.'], titleText));

% start on the largest node, so the right panel is not empty
[~, biggest] = max(cellfun(@numel, members));
drawNode(biggest, S);
end

% ======================================================================
function onClick(evt, S)
% Find the node nearest to where the user clicked and draw it.
p = evt.IntersectionPoint;                      % [x y z] in axes coordinates
d = hypot(S.nodeX - p(1), S.nodeY - p(2));
[~, node] = min(d);
drawNode(node, S);
end

% ======================================================================
function drawNode(node, S)
% Move the selection marker and draw that node's skeletons in the right panel.
% The drawing itself is done by drawNodeSkeletons, which the static figure
% (plotTMCategoryNodePanels) also uses, so the two look the same.
set(S.hSel, 'XData', S.nodeX(node), 'YData', S.nodeY(node));

drawNodeSkeletons(S.axSkel, node, S.members{node}, S.repMember(node), ...
    S.skeletonData, S.timeVel, S.Cat, S.showSpread, true);
end
