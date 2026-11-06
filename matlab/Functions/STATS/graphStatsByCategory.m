function S = graphStatsByCategory(AllDyads, numCategories)
%GRAPHSTATSBYCATEGORY  Subgraph (induced) and embedded metrics of every
%dyad's TM network, per behavioural category.
%
%   S = graphStatsByCategory(GTK_AllDyads_GraphData)
%   S = graphStatsByCategory(GTK_AllDyads_GraphData, 4)
%
% Used by GTK_MAN_Subgraphstats_Pairedttest and
% SpearCorr_SubgraphStats_AsySymBoot. Fields are numDyads-by-numCategories
% (NaN = category absent / fewer than 2 nodes):
%   numNodes, numEdges, density, meanInDeg, meanOutDeg, nodesizes,
%   numComponents, largestComponent, largestFrac          (induced subgraph)
%   Embed_numNodes, Embed_numEdges, Embed_density, Embed_meanInDeg,
%   Embed_meanOutDeg, Embed_nodesizes                      (within whole graph)
%
% Speed-up (same numbers): node categories come from findnodelabel (mode),
% exactly as before. Because every time point belongs to exactly one node,
%   subgraphFromMembers(g, members, unique(cell2mat(members(nodeidx))))
% always returns subgraph(g, nodeidx); calling subgraph directly skips an
% intersect() over every node's member list. adjacency() and the degrees
% are computed once per dyad instead of once per category.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(numCategories)
    numCategories = 4;
end

n = numel(AllDyads);
names = {'numNodes','numEdges','density','meanInDeg','meanOutDeg','nodesizes', ...
         'numComponents','largestComponent','largestFrac', ...
         'Embed_numNodes','Embed_numEdges','Embed_density','Embed_meanInDeg', ...
         'Embed_meanOutDeg','Embed_nodesizes'};
for f = 1:numel(names)
    S.(names{f}) = nan(n, numCategories);
end

for d = 1:n
    data = AllDyads{d};
    if isempty(data) || ~isstruct(data)
        continue
    end

    g        = data.g_simp;
    nodeCat  = findnodelabel(data.members, data.colorvar, 'labelmethod', 'mode');
    A        = adjacency(g);
    inDegG   = indegree(g);
    outDegG  = outdegree(g);
    nsz      = data.nodesize(:);

    for c = 1:numCategories

        nodeidx = find(nodeCat == c);
        if numel(nodeidx) < 2
            continue       % empty and 1-node subgraphs are skipped
        end

        % ---- induced subgraph ----
        gs = subgraph(g, nodeidx);
        nn = numnodes(gs);
        ne = numedges(gs);

        S.numNodes(d,c)   = nn;
        S.numEdges(d,c)   = ne;
        S.density(d,c)    = ne / (nn*(nn-1));
        S.meanInDeg(d,c)  = mean(indegree(gs));
        S.meanOutDeg(d,c) = mean(outdegree(gs));
        S.nodesizes(d,c)  = mean(nsz(nodeidx));

        comp  = conncomp(gs, 'Type', 'weak');
        csize = accumarray(comp(:), 1);
        S.numComponents(d,c)    = numel(csize);
        S.largestComponent(d,c) = max(csize);
        S.largestFrac(d,c)      = max(csize) / nn;

        % ---- embedded in the original graph ----
        ne2 = nnz(A(nodeidx, nodeidx));
        S.Embed_numNodes(d,c)   = nn;
        S.Embed_numEdges(d,c)   = ne2;
        S.Embed_density(d,c)    = ne2 / (nn*(nn-1));
        S.Embed_meanInDeg(d,c)  = mean(inDegG(nodeidx));
        S.Embed_meanOutDeg(d,c) = mean(outDegG(nodeidx));
        S.Embed_nodesizes(d,c)  = mean(nsz(nodeidx));
    end
end
end
