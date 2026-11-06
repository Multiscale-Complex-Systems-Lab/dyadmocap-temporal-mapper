function [figs, chosenNodes] = plotTMCategoryNodeFigures(g_simp, members, skeletonData, timeVel, Cat, zVelocity, titleText, showSpread)
%PLOTTMCATEGORYNODEFIGURES  One FIGURE PER CATEGORY in the clickable format.
%
%   [figs, chosenNodes] = plotTMCategoryNodeFigures(g_simp, members, skeletonData, timeVel, Cat, zVelocity)
%   [figs, chosenNodes] = plotTMCategoryNodeFigures(..., titleText, showSpread)
%
% Same layout as the clickable figure (exploreTMNodes), but static and one
% figure per behavioural category, so each figure is large and easy to read:
%   left  : the TM graph, coloured by category, with THIS figure's node ringed
%           in white;
%   right : that node's skeletons, drawn by drawNodeSkeletons, the same
%           function the clickable figure uses.
%
% Four categories give four figures. The caller saves them, so each can go in
% its own folder or slide.
%
% WHICH NODE PER CATEGORY
%   The LARGEST node whose majority category is that category: the state the
%   pair spent most time in within that category. A category with no node of
%   its own returns an empty figure handle and NaN.
%
% Remember that a node groups moments of similar angular VELOCITY, so each
% figure shows the posture during that movement state, not "the posture of the
% category".
%
% INPUTS  (as in exploreTMNodes)
%   g_simp, members, skeletonData, timeVel, Cat, zVelocity
%   titleText  : (optional) prefix for the figure titles, e.g. "GTK dyad001".
%   showSpread : (optional) grey moments drawn behind. Default 5.
%
% OUTPUTS
%   figs        : 1-by-numCategories figure handles (gobjects(1) where a
%                 category has no node).
%   chosenNodes : 1-by-numCategories node numbers (NaN where none).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 7 || isempty(titleText),  titleText  = 'TM node'; end
if nargin < 8 || isempty(showSpread), showSpread = 5; end

catNames = Cat.BehaviouralCategory;
nCat     = numel(catNames);
numNodes = numel(members);

% ---- category and size of every node ----
nodeCategory = zeros(numNodes, 1);
nodeSize     = zeros(numNodes, 1);
for n = 1:numNodes
    nodeCategory(n) = mode(Cat.colorvar(members{n}));    % majority category
    nodeSize(n)     = numel(members{n});
end

figs        = gobjects(1, nCat);
chosenNodes = nan(1, nCat);

for iCat = 1:nCat

    % ---- the largest node of this category ----
    candidates = find(nodeCategory == iCat);
    if isempty(candidates)
        fprintf('No node has %s as its majority category; no figure made.\n', catNames{iCat});
        continue
    end
    [~, iBig] = max(nodeSize(candidates));
    node      = candidates(iBig);
    chosenNodes(iCat) = node;

    % ---- representative moment: closest to the node's mean velocity ----
    m = members{node};
    if isempty(zVelocity)
        repIdx = m(ceil(numel(m)/2));
    else
        V  = zVelocity(m, :);
        dv = vecnorm(V - mean(V, 1), 2, 2);
        [~, iMin] = min(dv);
        repIdx = m(iMin);
    end

    % ---- the figure: graph on the left, skeletons on the right ----
    fig = figure('Color', 'w', 'Position', [60 60 1500 750]);
    tl  = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact');

    axGraph = nexttile(tl);
    plotTMGraphMarkNodes(axGraph, g_simp, members, Cat, node, ...
        {sprintf('node %d', node)}, [1 1 1]);       % white ring
    title(axGraph, sprintf('TM graph, node %d ringed in white', node));

    axSkel = nexttile(tl);
    drawNodeSkeletons(axSkel, node, m, repIdx, skeletonData, timeVel, Cat, ...
        showSpread, true);

    title(tl, sprintf('%s   |   %d. %s', titleText, iCat, catNames{iCat}), ...
        'Interpreter', 'none', 'FontWeight', 'bold');

    figs(iCat) = fig;
end
end
