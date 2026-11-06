function dMean = dyadCatDistance_weighted(data, catFrom, catTo)
% %DYADCATDISTANCE_WIEGHTED is a dyad level function that uses a Weighted
% %D_simp(directed) to compute for one dyad, the average distance 
% % between nodes belonging to two specified velocity categories
% % weight the distances by the products of the node size.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if isempty(data) || ~isstruct(data)
    dMean = NaN;
    return
end

Dsimp        = double(data.D_simp);   % D_simp is stored as single
members  = data.members;
colorvar = data.colorvar;
nodeSize = data.nodesize(:); % use stored node sizes (column, so W is an outer product)

% gsimp    = data.g_simp;
% 
% numNodes = numnodes(gsimp);  % node count       
% % nodeCat  = zeros(numNodes,1);

% for n = 1:numNodes
%     nodeCat(n) = round(mean(colorvar(members{n})));
% end

% ---- Assign node categories (same method as plotting) ----
nodeCat = findnodelabel(members, colorvar,'labelmethod','mode');

% ---- Nodes belonging to each category ----
fromNodes = find(nodeCat == catFrom);
toNodes   = find(nodeCat == catTo);

if isempty(fromNodes) || isempty(toNodes)
    dMean = NaN;
    return
end

% ---- Distances from the ORIGINAL graph topology ----
% extracting a subgraph
Dsub = Dsimp(fromNodes, toNodes);

% ---- Weight by node sizes ----
% Outer product of node sizes
W = nodeSize(fromNodes) * nodeSize(toNodes)'; %weights

valid = isfinite(Dsub);

if ~any(valid(:))
    dMean = NaN;      % no path between the two categories
    return
end

dMean = sum(Dsub(valid) .* W(valid)) / sum(W(valid));

% valid = isfinite(Dsub);
% if ~any(valid(:))
%     dMean = sum(Dsub(valid) .* W(valid)) / sum(W(valid));
% else
%     dMean = NaN;
% end

% if any(valid(:))
%     dMean = NaN;
%     return
% end
% dMean = sum(Dsub(valid) .* W(valid)) / sum(W(valid));
% 
end
