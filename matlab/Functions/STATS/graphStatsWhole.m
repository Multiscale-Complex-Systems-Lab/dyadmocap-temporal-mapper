function S = graphStatsWhole(AllDyads)
%GRAPHSTATSWHOLE  Whole-graph metrics of every dyad's TM network.
%
%   S = graphStatsWhole(GTK_AllDyads_GraphData)
%
% Used by GTK_MAN_WholeStats_Pairedttest and SpearCorr_WholeGraph.
% Fields are numDyads-by-1 (NaN = no data):
%   numNodes, numEdges, density, meanInDeg, meanOutDeg, nodesizes,
%   numComponents, largestComponent, largestFrac,
%   Embed_numNodes, Embed_numEdges, Embed_density, Embed_meanInDeg,
%   Embed_meanOutDeg, Embed_nodesizes
%
% Note: for the WHOLE graph the Embed_* values are by definition the same
% as the plain ones (all nodes are "embedded"); they are reported anyway,
% to show that the embedded metrics give the same results as the induced ones.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

n = numel(AllDyads);
names = {'numNodes','numEdges','density','meanInDeg','meanOutDeg','nodesizes', ...
         'numComponents','largestComponent','largestFrac', ...
         'Embed_numNodes','Embed_numEdges','Embed_density','Embed_meanInDeg', ...
         'Embed_meanOutDeg','Embed_nodesizes'};
for f = 1:numel(names)
    S.(names{f}) = nan(n,1);
end

for d = 1:n
    data = AllDyads{d};
    if isempty(data) || ~isstruct(data)
        continue
    end

    g  = data.g_simp;
    nn = numnodes(g);
    ne = numedges(g);

    S.numNodes(d) = nn;                      % number of behavioural states
    S.numEdges(d) = ne;                      % number of transitions
    if nn > 1
        S.density(d) = ne / (nn*(nn-1));     % directed graph
    else
        S.density(d) = 0;
    end

    inDeg  = indegree(g);
    outDeg = outdegree(g);
    S.meanInDeg(d)  = mean(inDeg);
    S.meanOutDeg(d) = mean(outDeg);
    S.nodesizes(d)  = mean(data.nodesize);

    % weakly connected components (edge direction ignored)
    comp  = conncomp(g, 'Type', 'weak');
    csize = accumarray(comp(:), 1);
    S.numComponents(d)    = numel(csize);
    S.largestComponent(d) = max(csize);
    if nn > 0
        S.largestFrac(d) = max(csize) / nn;
    end

    % embedding metrics (all nodes of the original graph)
    if nn >= 2
        S.Embed_numNodes(d)   = nn;
        S.Embed_numEdges(d)   = nnz(adjacency(g));
        S.Embed_density(d)    = S.Embed_numEdges(d) / (nn*(nn-1));
        S.Embed_meanInDeg(d)  = mean(inDeg);
        S.Embed_meanOutDeg(d) = mean(outDeg);
        S.Embed_nodesizes(d)  = mean(data.nodesize);
    end
end
end
