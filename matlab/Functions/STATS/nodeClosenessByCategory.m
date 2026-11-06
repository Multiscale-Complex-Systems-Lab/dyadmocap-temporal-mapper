function [C, nNodes] = nodeClosenessByCategory(AllDyads, numCategories)
%NODECLOSENESSBYCATEGORY  How far each behavioural category sits from the rest
%of the network: mean graph distance per node, averaged within category.
%
%   C = nodeClosenessByCategory(GTK_AllDyads_GraphData)
%   [C, nNodes] = nodeClosenessByCategory(AllDyads, 4)
%
% OUTPUT
%   C      : numDyads-by-numCategories. C(d,c) is the mean, over the nodes of
%            category c in dyad d, of that node's mean distance to every other
%            node of the WHOLE graph. NaN where the category has no node, or no
%            node with a finite distance to anything.
%   nNodes : numDyads-by-numCategories, how many nodes each mean is built from.
%
% WHAT THIS MEASURES, AND WHY IT IS THE RIGHT TEST OF "HUB VS PERIPHERY"
% A node that is central is close to everything; a node at the periphery is far
% from everything. This is closeness centrality, written as a distance so the
% direction reads plainly: LOW C = central (hub), HIGH C = peripheral.
%
% It is the measure that matches the claim, where the metrics this pipeline
% already reports do not:
%   * The induced-subgraph metrics (density, meanInDeg, numComponents,
%     largestFrac) delete the rest of the graph before measuring, so they
%     describe how a category's nodes connect TO EACH OTHER. A tight clump out
%     at the edge scores well on all of them. That is cohesion, not position.
%   * Degree in the whole graph (Embed_meanInDeg/Embed_meanOutDeg) is a
%     position measure, but it rises mechanically with node size: a node
%     holding more time points has more transitions in and out of it whatever
%     its position. Distance has no such dependence.
%   * The figures cannot settle it either. The layout is force-directed, so
%     where a node is drawn is computed FROM the adjacency - "green sits at the
%     edge" is a picture of the connectivity, not independent evidence of it.
%
% TWO PROPERTIES THAT MAKE THE COMPARISON CLEAN
%   1. Categories are compared WITHIN one dyad's graph, so graph size, density
%      and any difference between dyads cancel. No normalisation is needed and
%      none is applied - there is no free parameter here to choose.
%   2. Distances come from D_simp, the distance matrix of the original graph,
%      so the whole topology is used, not a subgraph of it.
%
% DETAILS
% D_simp is directed, so a node's distance to the rest of the network is taken
% over BOTH directions: the finite entries of row i (distances from i) and of
% column i (distances to i), pooled. Unreachable pairs are Inf and are dropped
% rather than counted, so C is a mean over the reachable part of the graph; a
% node reachable from nothing contributes nothing. The diagonal is removed.
%
% Node categories use findnodelabel(..., 'mode'), the same majority rule the
% plotting and every other per-category metric uses, so the categories here are
% the categories in the figures.
%
% That majority rule is also this measure's main caveat: if one category's
% nodes are large and mixed while another's are small and pure, part of any
% difference is composition rather than position.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(numCategories)
    numCategories = 4;
end

n      = numel(AllDyads);
C      = nan(n, numCategories);
nNodes = nan(n, numCategories);

for d = 1:n

    data = AllDyads{d};
    if isempty(data) || ~isstruct(data)
        continue
    end

    D       = double(data.D_simp);          % stored as single
    nodeCat = findnodelabel(data.members, data.colorvar, 'labelmethod', 'mode');
    N       = size(D, 1);

    if N < 2
        continue
    end

    D(1:N+1:end) = NaN;                     % a node's distance to itself is not
                                            % part of its distance to the rest

    % ---- each node's mean distance to the rest of the network ----
    meanDist = nan(N, 1);
    for i = 1:N
        v = [D(i,:), D(:,i).'];             % from i, and to i
        v = v(isfinite(v));                 % drop NaN (diagonal) and Inf (no path)
        if ~isempty(v)
            meanDist(i) = mean(v);
        end
    end

    % ---- average within each category ----
    for c = 1:numCategories
        idx  = find(nodeCat == c);
        vals = meanDist(idx);
        vals = vals(isfinite(vals));
        nNodes(d,c) = numel(vals);
        if ~isempty(vals)
            C(d,c) = mean(vals);
        end
    end
end
end
