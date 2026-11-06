function [rho, p, CI, N] = spearmanWithCI(x, y, nBoot, seed)
%SPEARMANWITHCI  Spearman rho, p-value and bootstrap (BCa) 95% CI, with the
%NaN / degenerate-data handling done in one place.
%
%   [rho, p, CI, N] = spearmanWithCI(x, y)
%   [rho, p, CI, N] = spearmanWithCI(x, y, nBoot, seed)
%
% * drops pairs where x or y is not finite
% * returns NaN when there are < 3 pairs or either variable is constant
% * CI from bootci (bias-corrected and accelerated), with a fixed seed on
%   a private stream so repeated runs give the same CI
%
% Old scripts computed bootci TWICE for every metric x category (once for
% the figure, once for the table); compute it once with this function and
% re-use the result.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(nBoot), nBoot = 10000; end
if nargin < 4 || isempty(seed),  seed  = 1;     end

x = x(:); y = y(:);
valid = isfinite(x) & isfinite(y);
x = x(valid); y = y(valid);
N = numel(x);

rho = NaN; p = NaN; CI = [NaN NaN];

if N < 3 || numel(unique(x)) < 2 || numel(unique(y)) < 2
    return
end

[rho, p] = corr(x, y, 'Type', 'Spearman');

try
    opt = statset('Streams', RandStream('mt19937ar','Seed',seed));
    ci  = bootci(nBoot, {@(a,b) corr(a,b,'Type','Spearman'), x, y}, 'Options', opt);
    CI  = ci(:)';
catch ME
    warning('spearmanWithCI:bootci', 'bootci failed (%s); CI set to NaN.', ME.message);
end
end
