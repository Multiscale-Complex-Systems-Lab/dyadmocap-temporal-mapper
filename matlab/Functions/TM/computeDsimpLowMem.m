function D_simp = computeDsimpLowMem(g, members, maxRows)
%COMPUTEDSIMPLOWMEM  The 4th output of tmapper2's filtergraph (D_simp),
%computed WITHOUT ever building the full N-by-N geodesic matrix.
%
%   D_simp = computeDsimpLowMem(g, members)
%   D_simp = computeDsimpLowMem(g, members, maxRows)
%
% filtergraph(g,d) only computes D_simp when asked for 4 outputs, and then
% calls distances(g) on the full time-point graph: N-by-N doubles
% (e.g. 45,000 time points -> 16 GB). This function gives the SAME matrix
% -- D_simp(a,b) = shortest path length in g from any member of node a to
% any member of node b -- by running distances() from a batch of source
% time points at a time, so peak memory is ~maxRows*N*8 bytes.
%
% Inputs
%   g        : the time-point graph from tknndigraph (digraph)
%   members  : the members output of filtergraph (cell array; positional
%              node indices of g, which is what filtergraph returns for a
%              graph with no Node names)
%   maxRows  : (optional) max number of source time points per batch.
%              Default picks ~400 MB per batch.
%
% Output
%   D_simp   : numNodes-by-numNodes, stored as SINGLE to halve memory.
%              Path lengths are integers, so single is exact (Inf stays Inf).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

N = numnodes(g);
K = numel(members);
if nargin < 3 || isempty(maxRows)
    maxRows = max(1, floor(50e6 / max(N,1)));   % ~400 MB of doubles per batch
end

% -- node label of every time point, and column order grouped by node
lab = zeros(N,1);
for kk = 1:K
    lab(members{kk}) = kk;
end
if any(lab == 0)
    error('computeDsimpLowMem:badMembers', ...
        'members must cover every node of g exactly once.');
end
[~, colOrder] = sort(lab);
colLab    = lab(colOrder);
colStart  = [1; find(diff(colLab) ~= 0) + 1];
colEnd    = [colStart(2:end) - 1; N];

D_simp = inf(K, K, 'single');
sizes  = cellfun(@numel, members);

k = 1;
while k <= K
    % -- gather whole nodes into one batch of source rows
    k2   = k;
    rows = sizes(k);
    while k2 < K && rows + sizes(k2+1) <= maxRows
        k2   = k2 + 1;
        rows = rows + sizes(k2);
    end
    src = cell2mat(cellfun(@(x) x(:), members(k:k2), 'UniformOutput', false));

    Dsrc = distances(g, src);          % rows-by-N (same method as filtergraph)
    Dsrc = Dsrc(:, colOrder);          % columns grouped by target node

    % -- min over the source rows of each node in the batch
    nb     = k2 - k + 1;
    rowMin = zeros(nb, N);
    r0 = 0;
    for b = 1:nb
        nr = sizes(k + b - 1);
        rowMin(b,:) = min(Dsrc(r0+1:r0+nr, :), [], 1);
        r0 = r0 + nr;
    end
    clear Dsrc

    % -- min over the target columns of each node
    blk = zeros(nb, K);
    for m = 1:K
        blk(:,m) = min(rowMin(:, colStart(m):colEnd(m)), [], 2);
    end
    D_simp(k:k2, :) = single(blk);

    k = k2 + 1;
end
end
