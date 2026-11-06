function r = columnSpearman(X, Y)
%COLUMNSPEARMAN  Spearman correlation of every column pair (X(:,b), Y(:,b)).
%
%   r = columnSpearman(X, Y)     X, Y : n-by-B,  r : 1-by-B
%
% Identical to corr(X(:,b), Y(:,b), 'Type','Spearman') for each column b
% (Pearson correlation of tie-averaged ranks), but for all B columns in one
% vectorised pass. Used to run 10,000 bootstrap / permutation resamples
% without 10,000 separate corr() calls. A constant column gives NaN, as
% corr() does. Inputs must not contain NaN.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

RX = tiedRanksCols(X);
RY = tiedRanksCols(Y);

RX = RX - mean(RX, 1);
RY = RY - mean(RY, 1);
r  = sum(RX .* RY, 1) ./ sqrt(sum(RX.^2, 1) .* sum(RY.^2, 1));
r(~isfinite(r)) = NaN;
end

function R = tiedRanksCols(X)
% column-wise ranks, ties get the average rank (same as tiedrank)
[n, B] = size(X);
[S, I] = sort(X, 1);
newGroup = [true(1, B); diff(S, 1, 1) ~= 0];
gid = cumsum(newGroup, 1);                         % tie-group id within column
offsets = [0, cumsum(gid(end, 1:end-1))];          % make ids unique across columns
G = gid + offsets;
pos = repmat((1:n)', 1, B);
avgRank = accumarray(G(:), pos(:)) ./ accumarray(G(:), 1);
R = zeros(n, B);
R(sub2ind([n B], I, repmat(1:B, n, 1))) = avgRank(G);
end
