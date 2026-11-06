function [fig, chosenNodes] = plotTMCategoryNodePanels(g_simp, members, skeletonData, timeVel, Cat, zVelocity, titleText, showSpread)
%PLOTTMCATEGORYNODEPANELS  Static version of the clickable node figure: the TM
%graph plus one skeleton panel for each of the four behavioural categories.
%
%   [fig, chosenNodes] = plotTMCategoryNodePanels(g_simp, members, skeletonData, timeVel, Cat, zVelocity)
%   [fig, chosenNodes] = plotTMCategoryNodePanels(..., titleText, showSpread)
%
% WHAT IT SHOWS
%   Left, spanning the full height: the temporal mapper graph, coloured by
%   behavioural category, with the four chosen nodes circled in black and
%   numbered 1 to 4 to match the panels.
%   Right, in a 2-by-2 grid: one node per category, drawn exactly as in the
%   clickable figure (the same function draws both) - the two partners at that
%   node's most typical moment in colour, a few other moments of the same node
%   in grey, the seat in yellow.
%
% WHICH NODE IS CHOSEN PER CATEGORY
%   The LARGEST node whose majority category is that category, i.e. the state
%   the pair spent most time in within that category. A category with no node
%   of its own gets an empty panel saying so.
%
% Remember that a node groups moments of similar angular VELOCITY, so each
% panel shows the posture during that movement state, not "the posture of the
% category".
%
% INPUTS  (the same as exploreTMNodes)
%   g_simp       : simplified graph from filtergraph.
%   members      : filtergraph's members, numNodes-by-1 cell array.
%   skeletonData : 1-by-2 cell, one per partner, frames-by-joints-by-3.
%   timeVel      : time vector of the velocity samples (s).
%   Cat          : struct from categorizeVelocity.
%   zVelocity    : z-scored velocity used for the graph; [] to take the middle
%                  member of each node instead.
%   titleText    : (optional) figure title, e.g. "GTK dyad001".
%   showSpread   : (optional) grey moments per panel. Default 5.
%
% OUTPUT
%   fig          : the figure handle.
%   chosenNodes  : 1-by-numCategories node numbers (NaN where a category has
%                  no node), so the choice can be reported or checked.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 7 || isempty(titleText),  titleText  = 'TM nodes by category'; end
if nargin < 8 || isempty(showSpread), showSpread = 5; end

numNodes = numel(members);
catNames = Cat.BehaviouralCategory;
nCat     = numel(catNames);

% ---- category and size of every node ----
nodeCategory = zeros(numNodes, 1);
nodeSize     = zeros(numNodes, 1);
for n = 1:numNodes
    nodeCategory(n) = mode(Cat.colorvar(members{n}));    % majority category
    nodeSize(n)     = numel(members{n});
end

% ---- the largest node of each category ----
chosenNodes = nan(1, nCat);
for iCat = 1:nCat
    candidates = find(nodeCategory == iCat);
    if ~isempty(candidates)
        [~, iBig] = max(nodeSize(candidates));
        chosenNodes(iCat) = candidates(iBig);
    end
end

% ---- representative moment of each chosen node ----
% the member whose velocity is closest to that node's mean velocity
repIdx = nan(1, nCat);
for iCat = 1:nCat
    if isnan(chosenNodes(iCat)), continue; end
    m = members{chosenNodes(iCat)};
    if isempty(zVelocity)
        repIdx(iCat) = m(ceil(numel(m)/2));
    else
        V  = zVelocity(m, :);
        dv = vecnorm(V - mean(V, 1), 2, 2);
        [~, iMin]    = min(dv);
        repIdx(iCat) = m(iMin);
    end
end

% ---- figure: graph on the left, 2-by-2 skeleton panels on the right ----
fig = figure('Color', 'w', 'Position', [50 50 1700 900]);
tl  = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');

% the graph spans both rows of the first column.
% plotTMGraphMarkNodes draws the graph, puts the category NAMES on the colour
% bar (not the numbers 1..4) and rings the chosen nodes in WHITE with a thin
% dark outline, which reads more clearly than a plain black ring.
axGraph = nexttile(tl, 1, [2 1]);

marked      = chosenNodes(~isnan(chosenNodes));          % nodes that exist
markedLabel = cell(1, numel(marked));
iLabel      = 0;
for iCat = 1:nCat
    if isnan(chosenNodes(iCat)), continue; end
    iLabel = iLabel + 1;
    markedLabel{iLabel} = sprintf('%d', iCat);           % matches the panel number
end

plotTMGraphMarkNodes(axGraph, g_simp, members, Cat, marked, markedLabel, [1 1 1]);
title(axGraph, 'TM graph (nodes ringed in white are shown on the right)');

% ---- one skeleton panel per category, in the 2-by-2 grid ----
% tiles 2 and 3 are the top row, 5 and 6 the bottom row of a 2-by-3 layout
panelTiles = [2 3 5 6];
for iCat = 1:nCat
    if iCat > numel(panelTiles)
        break                                  % only four panels fit
    end
    ax = nexttile(tl, panelTiles(iCat));

    if isnan(chosenNodes(iCat))
        axis(ax, 'off');
        title(ax, sprintf('%d. %s: no node in this category', iCat, catNames{iCat}), ...
            'Interpreter', 'none');
        continue
    end

    node = chosenNodes(iCat);
    drawNodeSkeletons(ax, node, members{node}, repIdx(iCat), skeletonData, ...
        timeVel, Cat, showSpread, iCat == 1);   % one legend, on the first panel

    % keep the category number in the title, so panel and graph match
    t = get(ax, 'Title');
    set(t, 'String', [{sprintf('%d. %s', iCat, catNames{iCat})}; t.String(:)]);
end

title(tl, sprintf(['%s: the largest node of each behavioural category, ' ...
    'most typical moment of each'], titleText), 'Interpreter', 'none');
end
