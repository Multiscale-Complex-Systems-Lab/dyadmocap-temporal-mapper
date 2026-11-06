function fig = plotTMNodeGallery(members, skeletonData, timeVel, Cat, zVelocity, numNodesShown, titleText)
%PLOTTMNODEGALLERY  A static grid of the skeletons of the largest TM nodes.
%
%   fig = plotTMNodeGallery(members, skeletonData, timeVel, Cat, zVelocity)
%   fig = plotTMNodeGallery(..., numNodesShown, titleText)
%
% This is the printable version of exploreTMNodes: instead of clicking nodes
% one at a time, it draws the representative moment of the largest nodes in one
% figure, so the figure can be saved, shown to someone else, or put in a slide.
%
% Each panel shows one node:
%   * the two partners at that node's most typical moment (the member whose
%     z-velocity is closest to the node's mean velocity), Person 1 blue and
%     Person 2 red;
%   * the panel title gives the node number, how many moments it holds, how
%     many seconds that is, and its behavioural category.
% Nodes are ordered by size, largest first, so the panels are the states the
% pair spent most time in.
%
% Remember what a node is: the graph is built from angular VELOCITY, so a node
% groups moments of similar MOVEMENT, not of similar posture. The posture shown
% is the posture during that movement state.
%
% INPUTS (the same as exploreTMNodes, minus the graph itself)
%   members       : filtergraph's members, numNodes-by-1 cell array.
%   skeletonData  : 1-by-2 cell, one per partner, frames-by-joints-by-3.
%   timeVel       : time vector of the velocity samples (s).
%   Cat           : struct from categorizeVelocity.
%   zVelocity     : z-scored velocity used for the graph; [] to take the
%                   middle member of each node instead.
%   numNodesShown : (optional) how many of the largest nodes to draw.
%                   Default 12, which fits a 3-by-4 grid.
%   titleText     : (optional) figure title, e.g. "GTK dyad001".
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 6 || isempty(numNodesShown), numNodesShown = 12; end
if nargin < 7 || isempty(titleText),     titleText = 'TM nodes'; end

personColors = DYMO_personColors();
dt           = median(diff(timeVel));          % one sample in seconds

% ---- the largest nodes, in order ----
nodeSizes      = cellfun(@numel, members);
[~, order]     = sort(nodeSizes, 'descend');
numNodesShown  = min(numNodesShown, numel(order));
nodesToDraw    = order(1:numNodesShown);

% ---- grid shape: as square as possible, a little wider than tall ----
nCols = ceil(sqrt(numNodesShown * 4/3));
nRows = ceil(numNodesShown / nCols);

fig = figure('Color', 'w', 'Position', [100 100 1600 1000]);
tl  = tiledlayout(fig, nRows, nCols, 'TileSpacing', 'compact', 'Padding', 'compact');

for iNode = 1:numNodesShown
    node = nodesToDraw(iNode);
    m    = members{node};

    % representative moment of this node
    if isempty(zVelocity)
        repIdx = m(ceil(numel(m)/2));
    else
        V  = zVelocity(m, :);
        dv = vecnorm(V - mean(V, 1), 2, 2);
        [~, iMin] = min(dv);
        repIdx = m(iMin);
    end

    ax = nexttile(tl);
    hold(ax, 'on');
    hPerson = gobjects(1,2);
    hSeat   = gobjects(1,1);
    for sub = 1:2
        P = skeletonData{sub};
        f = min(repIdx, size(P,1));            % velocity sample i -> frame i
        hPerson(sub) = plot3(ax, P(f,:,1), P(f,:,2), P(f,:,3), 'o', 'MarkerSize', 4, ...
            'MarkerFaceColor', personColors(sub,:), 'MarkerEdgeColor', personColors(sub,:));
        hSeat = plot3(ax, P(f,1,1), P(f,1,2), P(f,1,3), 'o', 'MarkerSize', 6, ...
            'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'k');    % seat
    end
    hold(ax, 'off');

    % one legend for the whole grid, taken from the first panel's handles
    if iNode == 1
        legend(ax, [hPerson hSeat], {'Person 1', 'Person 2', 'Seat'}, ...
            'Location', 'southoutside', 'Orientation', 'horizontal', 'FontSize', 8, ...
            'AutoUpdate', 'off');
    end
    axis(ax, 'equal');  axis(ax, 'off');
    view(ax, 97.17, 1.99);

    catOfNode = mode(Cat.colorvar(m));
    title(ax, {sprintf('Node %d  (%d moments, %.1f s)', node, numel(m), numel(m)*dt), ...
               Cat.BehaviouralCategory{catOfNode}}, 'FontSize', 9);
end

title(tl, sprintf(['%s: the %d largest TM nodes, most typical moment of each ' ...
    '(Person 1 blue, Person 2 red)'], titleText, numNodesShown));
end
