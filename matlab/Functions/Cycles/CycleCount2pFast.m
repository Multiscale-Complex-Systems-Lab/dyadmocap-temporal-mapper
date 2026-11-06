function [cycCount,cycLen,cycPath,allcycles] = CycleCount2pFast(A,varargin)
%CYCLECOUNT2PFAST  Same outputs as tmapper2's CycleCount2p, much faster.
%
%   [cycCount,cycLen,cycPath,allcycles] = CycleCount2pFast(A)
%   [...] = CycleCount2pFast(A,'simple',false)
%
% CycleCount2p finds, for every pair of nodes (s,t), the shortest path
% s->t and t->s and joins them into a cycle. It calls shortestpath() twice
% per PAIR, i.e. N*(N-1) breadth-first searches, and preallocates a cell
% for all N*(N-1)/2 pairs. Here one shortest-path tree is computed per
% NODE (N searches) and every s->t path is read off the tree of s, which
% is the same breadth-first search shortestpath() runs for a single target.
%
% Because tie-breaking between equally short paths is decided inside
% MATLAB's graph code, the Cycles script checks this function against
% CycleCount2p on the first dyad (verifyFastCycles = true) and falls back
% to CycleCount2p automatically if they ever disagree.
%
% input / output: identical to CycleCount2p (see its help).
%
% Based on CycleCount2p of Temporal Mapper (tmapper2).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

p = inputParser;
p.addParameter('simple',true); % only count simple cycles
p.parse(varargin{:});
par = p.Results;

G  = digraph(A);
Nn = G.numnodes;

% -- one shortest-path tree per source node (predecessor vectors)
PRED = zeros(Nn, Nn, 'uint32');   % PRED(s,v) = predecessor of v on the s->v path
REACH = false(Nn, Nn);            % REACH(s,v) = v reachable from s
for s = 1:Nn
    [tr, dist] = shortestpathtree(G, s, 'OutputForm', 'vector');
    ok = isfinite(dist(:)') & ~isnan(tr(:)');
    pr = tr(:)';
    pr(~ok) = 0;
    PRED(s,:)  = uint32(pr);
    REACH(s,:) = isfinite(dist(:)');
end

% -- walk every pair, exactly as CycleCount2p does
CYC = cell(max(16, 4*Nn), 1);
n = 0;
for s = 1:Nn
    for t = s+1:Nn
        if REACH(s,t) && REACH(t,s)          % path closed
            spf = treePath(PRED, s, t);      % forward path  s -> t
            spb = treePath(PRED, t, s);      % backward path t -> s
            cycle = [spf, spb(2:end-1)];
            if ~par.simple || (numel(unique(cycle)) == numel(cycle))
                n = n + 1;
                if n > numel(CYC)
                    CYC{2*numel(CYC)} = [];  % grow geometrically
                end
                [~,rootIdx] = min(cycle);
                CYC{n} = circshift(cycle, 1-rootIdx);   % start with smallest idx
            end
        end
    end
end
CYC(n+1:end) = [];

% -- identical post-processing to CycleCount2p
CYC_LEN = cellfun(@length, CYC);
cycLen  = unique(CYC_LEN);

N_len    = length(cycLen);
cycPath  = cell(N_len,1);
cycCount = zeros(N_len,1);
for lenIdx = 1:N_len
    cycPath{lenIdx}  = unique(cell2mat(CYC(CYC_LEN == cycLen(lenIdx))), 'rows');
    cycCount(lenIdx) = size(cycPath{lenIdx},1);
end

allcycles = cell(sum(cycCount),1);
idx = 1;
for ncl = 1:N_len
    rowsC = num2cell(cycPath{ncl}, 2);
    allcycles(idx:idx+numel(rowsC)-1) = rowsC;
    idx = idx + numel(rowsC);
end
end

function path = treePath(PRED, s, t)
% nodes on the tree path s -> t (row vector, starts at s, ends at t)
path = t;
v = t;
while v ~= s
    v = double(PRED(s, v));
    path(end+1) = v; %#ok<AGROW>
end
path = fliplr(path);
end
