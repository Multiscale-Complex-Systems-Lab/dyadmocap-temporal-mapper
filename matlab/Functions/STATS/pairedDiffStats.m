function S = pairedDiffStats(a, b, nBoot, nPerm, seed)
%PAIREDDIFFSTATS  Paired comparison of two conditions: t-test, effect size, a
%bootstrap CI that assumes no distribution, and the nonparametric p-values.
%
%   S = pairedDiffStats(GTK, MAN)
%   S = pairedDiffStats(GTK, MAN, nBoot, nPerm, seed)
%
% INPUT
%   a, b  : one value per dyad, in the SAME dyad order (a = GTK, b = MAN).
%           Pairs where either value is not finite are dropped, which is how a
%           dyad missing from one condition is handled - never as a zero.
%   nBoot : bootstrap resamples, default 10000 (as the correlation scripts use).
%   nPerm : permutations, default 10000 (as the correlation scripts use).
%   seed  : seed of a private random stream, default 1, so a rerun reproduces
%           the interval and the permutation p exactly.
%
% OUTPUT, a struct with
%   N            pairs used
%   meanA, meanB the two condition means
%   meanDiff     mean of (a - b), i.e. GTK minus MAN
%   sdDiff       SD of the paired differences (N-1)
%   dz           Cohen's dz = meanDiff / sdDiff, the paired effect size
%   t, df, p     paired t-test
%   ciT          95 % CI of meanDiff from the t-test (assumes the differences
%                are approximately normal)
%   ciBoot       95 % CI of meanDiff from the bootstrap (assumes nothing about
%                their shape)
%   pPerm        two-sided permutation p-value, by sign flipping (below)
%   pWilcoxon    Wilcoxon signed rank, the nonparametric partner of the t-test
%   nPos, nNeg   dyads where a > b and where a < b
%   pSign        sign test, which uses only the direction of each difference
%
% WHY BOTH INTERVALS, AND WHY THIS IS NOT A REPLACEMENT FOR THE T-TEST
% The paired scripts already report a CI: the one `ttest` returns, which comes
% from the t distribution and therefore assumes the paired differences are
% roughly normal. At n = 30 that assumption is fairly safe for the mean, by the
% central limit theorem - it is skew and outliers, not mild non-normality, that
% hurt it. So the bootstrap interval here is a CHECK, not a better answer:
%   * if ciBoot and ciT agree, the normality assumption was doing no work and
%     the result can be reported without leaning on it;
%   * if they disagree, the differences are skewed or outlier-driven, and that
%     is worth knowing before the number is written up.
% The same logic applies to p against pWilcoxon and pSign.
%
% WHAT IS RESAMPLED, WHICH IS THE ONE THING TO GET RIGHT
% The bootstrap resamples DYADS - whole pairs, keeping each dyad's two
% conditions together - because the dyad is the independent unit. Resampling the
% two conditions separately would destroy the pairing and give an interval for
% the wrong quantity (a between-group comparison), which would be too wide and
% would silently discard the design's main advantage.
%
% THE PERMUTATION TEST, AND WHY SIGN FLIPPING IS THE PAIRED VERSION
% The correlation scripts permute by shuffling group labels over the pooled
% pairs. The paired equivalent is not a shuffle across dyads but a shuffle
% WITHIN each dyad: under the null that the two conversations do not differ, the
% labels GTK and MAN are exchangeable inside a dyad, so each dyad's difference is
% equally likely to have come out with the opposite sign. Flipping each dyad's
% sign at random, 10,000 times, therefore builds the null distribution of the
% mean difference for exactly this design, and
%       pPerm = mean( |mean(d_permuted)| >= |mean(d_observed)| )
% two-sided, the same convention spearmanGroupDelta uses. This is a randomisation
% test: it assumes nothing about the shape of the differences, only that the two
% condition labels could have been swapped within a dyad.
%
% Note on reading pPerm: with nPerm = 10000 the smallest value it can return is
% 0, which means no permutation reached the observed difference. Report that as
% p < 1e-4 rather than as p = 0.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(nBoot), nBoot = 10000; end
if nargin < 4 || isempty(nPerm), nPerm = 10000; end
if nargin < 5 || isempty(seed),  seed  = 1;     end

a = a(:); b = b(:);
if numel(a) ~= numel(b)
    error('pairedDiffStats:sizeMismatch', ...
        'a and b must have one value per dyad, in the same order (got %d and %d).', ...
        numel(a), numel(b));
end

valid = isfinite(a) & isfinite(b);       % a dyad missing either condition is dropped
a = a(valid); b = b(valid);
d = a - b;

S = struct('N', numel(d), 'meanA', NaN, 'meanB', NaN, 'meanDiff', NaN, ...
           'sdDiff', NaN, 'dz', NaN, 't', NaN, 'df', NaN, 'p', NaN, ...
           'ciT', [NaN NaN], 'ciBoot', [NaN NaN], 'pPerm', NaN, ...
           'pWilcoxon', NaN, 'nPos', NaN, 'nNeg', NaN, 'pSign', NaN);

if S.N < 2
    return                               % nothing to test; every field stays NaN
end

S.meanA    = mean(a);
S.meanB    = mean(b);
S.meanDiff = mean(d);
S.sdDiff   = std(d);                     % N-1, as MATLAB does by default
if S.sdDiff > 0
    S.dz = S.meanDiff / S.sdDiff;        % Cohen's dz for a paired design
end

[~, S.p, ciT, st] = ttest(a, b);
S.ciT = ciT(:)';
S.t   = st.tstat;
S.df  = st.df;

% ---- bootstrap CI of the mean difference: resample whole pairs ----
if S.sdDiff > 0
    try
        opt = statset('Streams', RandStream('mt19937ar', 'Seed', seed));
        ci  = bootci(nBoot, {@mean, d}, 'Options', opt);     % BCa, as spearmanWithCI uses
        S.ciBoot = ci(:)';
    catch ME
        % percentile interval, so a missing toolbox or a bootci failure still
        % leaves a distribution-free interval rather than nothing
        warning('pairedDiffStats:bootci', ...
            'bootci failed (%s); using a percentile interval instead.', ME.message);
        rs = RandStream('mt19937ar', 'Seed', seed);
        bm = nan(nBoot, 1);
        for i = 1:nBoot
            idx   = randi(rs, S.N, S.N, 1);      % resample dyads with replacement
            bm(i) = mean(d(idx));
        end
        S.ciBoot = [quantile(bm, 0.025), quantile(bm, 0.975)];
    end
else
    S.ciBoot = [S.meanDiff, S.meanDiff];         % every difference identical
end

% ---- permutation test: flip each dyad's sign, all permutations at once ----
if S.sdDiff > 0
    rsP  = RandStream('mt19937ar', 'Seed', seed);
    flip = 1 - 2 * (rand(rsP, S.N, nPerm) < 0.5);    % +1 or -1 per dyad per permutation
    nullMeans = mean(d .* flip, 1);                  % 1-by-nPerm
    S.pPerm = mean(abs(nullMeans) >= abs(S.meanDiff));
else
    S.pPerm = 1;                                     % no variation to permute
end

% ---- nonparametric p-values ----
if exist('signrank', 'file')
    S.pWilcoxon = signrank(a, b);
end
S.nPos = nnz(d > 0);
S.nNeg = nnz(d < 0);
nTied  = S.nPos + S.nNeg;
if nTied > 0
    S.pSign = min(1, 2 * min(binocdf(S.nPos, nTied, 0.5), ...
                             1 - binocdf(S.nPos - 1, nTied, 0.5)));
end
end
