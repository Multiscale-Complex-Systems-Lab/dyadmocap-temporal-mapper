function [R, nodeOfTime, idx] = tmRecurrenceMatrix(members, D_simp, numSamples, maxPoints)
%TMRECURRENCEMATRIX  Recurrence (time connectivity) matrix from a TM graph.
%
%   [R, nodeOfTime, idx] = tmRecurrenceMatrix(members, D_simp, numSamples)
%   [R, nodeOfTime, idx] = tmRecurrenceMatrix(members, D_simp, numSamples, maxPoints)
%
% WHAT IT IS
%   R(i,j) is the number of steps between time point i and time point j in
%   the simplified temporal mapper graph: 0 if both belong to the same node
%   (the system is in the same state), 1 if their nodes are neighbours, and
%   so on. Inf means the two are in different connected components.
%   This is the same quantity as tmapper2's TCMdistance, and it is what the
%   toolbox draws next to the network in plotgraphtcm.
%
%   It differs from the plain distance matrix of the z-velocity: that one
%   measures how far apart two moments are in the 22-dimensional velocity
%   space, while this one measures how far apart they are along the graph,
%   after the mapper has grouped similar moments into nodes. The block
%   structure of R is therefore the recurrence structure the TM analysis
%   actually works with.
%
% INPUTS
%   members    : the members output of filtergraph, a numNodes-by-1 cell
%                array; members{n} lists the time points belonging to node n.
%   D_simp     : numNodes-by-numNodes geodesic distances between nodes
%                (computeDsimpLowMem, or the 4th output of filtergraph).
%   numSamples : number of time points in the analysis (N). Used to build
%                the time-point-to-node mapping.
%   maxPoints  : (optional) the matrix is built on at most this many evenly
%                spaced time points, because a full N-by-N matrix is large
%                (13,000 time points would be 1.4 GB as double). Default
%                4000, which is about 64 MB as single. Inf = all points.
%
% OUTPUTS
%   R          : numel(idx)-by-numel(idx) single. Step distances, as above.
%   nodeOfTime : numSamples-by-1, the node each time point belongs to.
%   idx        : the time points used, so you can label the axes with
%                time(idx).
%
% WHY THE LOOKUP IS CHEAP
%   Every time point in a node has the same graph distance to every time
%   point in another node, so R is just D_simp indexed by node membership.
%   Nothing is recomputed from the data.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 4 || isempty(maxPoints)
    maxPoints = 4000;
end

% ---- which node does each time point belong to? ----
nodeOfTime = zeros(numSamples, 1);
for n = 1:numel(members)
    nodeOfTime(members{n}) = n;
end
if any(nodeOfTime == 0)
    warning(['tmRecurrenceMatrix: %d time points belong to no node and are ' ...
             'left out of the matrix.'], nnz(nodeOfTime == 0));
end

% ---- evenly spaced subset of time points, for a matrix that fits ----
step = max(1, ceil(numSamples / maxPoints));
idx  = 1:step:numSamples;
idx  = idx(nodeOfTime(idx) > 0);          % skip any unassigned points

% ---- the matrix itself: node distances, read through the mapping ----
R = single(D_simp(nodeOfTime(idx), nodeOfTime(idx)));
end
