function R = pairedGroupDelta(aG1, bG1, aG2, bG2, nBoot, nPerm, seed)
%PAIREDGROUPDELTA  Compare the GTK-minus-MAN effect between two groups (e.g. two
%behavioural categories): the difference of mean paired differences, a bootstrap
%95% CI of that difference, and a two-sided permutation p-value.
%
%   R = pairedGroupDelta(aG1, bG1, aG2, bG2)
%   R = pairedGroupDelta(aG1, bG1, aG2, bG2, nBoot, nPerm, seed)
%
% This is the paired-t-test counterpart of spearmanGroupDelta, which does the
% same job for two Spearman correlations. Where that function asks "is the
% across-dyad correlation different in group 1 than in group 2", this one asks
% "is the CONDITION EFFECT different in group 1 than in group 2".
%
% INPUT
%   aG1, bG1 : group 1's values, GTK and MAN, one per dyad, same dyad order
%   aG2, bG2 : group 2's values, likewise, for the SAME dyads in the same order
%   nBoot    : bootstrap resamples, default 10000
%   nPerm    : permutations, default 10000
%   seed     : private random stream seed, default 1, so a rerun reproduces
%
% OUTPUT struct
%   N         dyads with all four values finite
%   diffG1    mean(aG1 - bG1), the condition effect in group 1
%   diffG2    mean(aG2 - bG2), the condition effect in group 2
%   delta     diffG1 - diffG2
%   CI        bootstrap 95 % CI of delta
%   pPerm     two-sided permutation p-value for delta
%   pPaired   paired t-test on the per-dyad delta, for comparison
%
% WHY THE TWO GROUPS ARE TREATED AS PAIRED, NOT POOLED
% Shuffling group labels over the pooled pairs would treat the two groups as
% independent samples. Here the two groups are two measures of the SAME dyads -
% two behavioural categories of one conversation - so they
% are not independent, and pooling would throw away that structure and give a
% test with the wrong standard error.
%
% Instead the quantity is formed per dyad,
%       delta_i = (aG1_i - bG1_i) - (aG2_i - bG2_i)
% which is an ordinary within-dyad difference of differences, and the two
% resampling procedures follow from that:
%   bootstrap   : resample DYADS with replacement, recompute mean(delta).
%   permutation : under the null that the condition effect is the same in both
%                 groups, delta_i is equally likely to have come out with the
%                 opposite sign, so each dyad's delta_i is sign-flipped at
%                 random. This is the same sign-flipping logic as
%                 pairedDiffStats, applied one level up.
%
% A dyad is used only if all four of its values are finite, so a category absent
% in either conversation removes that dyad from this comparison rather than
% contributing a zero.
%
% Note on reading pPerm: with nPerm = 10000 the smallest value it can return is
% 0, meaning no permutation reached the observed delta. Report that as p < 1e-4.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 5 || isempty(nBoot), nBoot = 10000; end
if nargin < 6 || isempty(nPerm), nPerm = 10000; end
if nargin < 7 || isempty(seed),  seed  = 1;     end

aG1 = aG1(:); bG1 = bG1(:); aG2 = aG2(:); bG2 = bG2(:);
n = [numel(aG1), numel(bG1), numel(aG2), numel(bG2)];
if numel(unique(n)) > 1
    error('pairedGroupDelta:sizeMismatch', ...
        ['All four inputs must have one value per dyad, in the same order ' ...
         '(got %d, %d, %d, %d).'], n(1), n(2), n(3), n(4));
end

valid = isfinite(aG1) & isfinite(bG1) & isfinite(aG2) & isfinite(bG2);
aG1 = aG1(valid); bG1 = bG1(valid);
aG2 = aG2(valid); bG2 = bG2(valid);

d1    = aG1 - bG1;          % condition effect per dyad, group 1
d2    = aG2 - bG2;          % condition effect per dyad, group 2
delta = d1 - d2;            % difference of differences, per dyad

R = struct('N', numel(delta), 'diffG1', NaN, 'diffG2', NaN, 'delta', NaN, ...
           'CI', [NaN NaN], 'pPerm', NaN, 'pPaired', NaN);

if R.N < 2
    warning('pairedGroupDelta:tooFew', ...
        'Fewer than 2 dyads have all four values; returning NaN.');
    return
end

R.diffG1 = mean(d1);
R.diffG2 = mean(d2);
R.delta  = mean(delta);

if std(delta) == 0
    % every dyad gives the same delta: nothing to resample or permute
    R.CI      = [R.delta, R.delta];
    R.pPerm   = 1;
    R.pPaired = 1;
    return
end

[~, R.pPaired] = ttest(delta);          % the parametric version, for comparison

rs = RandStream('mt19937ar', 'Seed', seed);

% ---------- bootstrap CI of delta: BCa, resampling whole dyads ----------
% BCa, so that every bootstrap in the pipeline is the same procedure and the
% methods section can describe it once: BCa, 10,000 resamples, the dyad as the
% unit, a fixed private seed.
try
    opt  = statset('Streams', RandStream('mt19937ar', 'Seed', seed));
    ci   = bootci(nBoot, {@mean, delta}, 'Options', opt);
    R.CI = ci(:)';
catch ME
    warning('pairedGroupDelta:bootci', ...
        'bootci failed (%s); falling back to a percentile interval.', ME.message);
    idx       = randi(rs, R.N, R.N, nBoot);
    deltaBoot = mean(delta(idx), 1);
    R.CI      = [quantile(deltaBoot, 0.025), quantile(deltaBoot, 0.975)];
end

% ---------- permutation: flip each dyad's delta sign ----------
flip      = 1 - 2 * (rand(rs, R.N, nPerm) < 0.5);
nullDelta = mean(delta .* flip, 1);
R.pPerm   = mean(abs(nullDelta) >= abs(R.delta));
end
