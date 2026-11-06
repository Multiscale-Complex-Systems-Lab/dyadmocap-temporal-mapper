function P = spearmanPairDelta(XGTK, XMAN, i, j, nBoot, seed)
%SPEARMANPAIRDELTA  Is the Casual Chat-Conflict correlation different between
%two behavioural categories? Delta rho (category i minus category j) with
%dyad-level BCa intervals at 95 %, 99 % and 99.9 %, and the star level they give.
%
%   P = spearmanPairDelta(Stats.GTK.(metric), Stats.MAN.(metric), 1, 3)
%   P = spearmanPairDelta(XGTK, XMAN, i, j, nBoot, seed)
%
% OUTPUT struct: i, j, rhoI, rhoJ, delta, CI95, CI99, CI999, stars, nDyads
%   stars = ''    95 % CI contains 0         (not drawn)
%           '*'   95 % CI excludes 0
%           '**'  99 % CI excludes 0
%           '***' 99.9 % CI excludes 0
%
% SAME PROCEDURE AS spearmanGroupDelta, with one category per side: the dyad is
% the resampling unit, one draw of dyads builds BOTH categories (they are
% measured on the same dyads), BCa, 10,000 resamples, fixed private seed. With
% the same seed every level uses the same dyad draws, so the three intervals
% are nested. The 95 % interval is what spearmanGroupDelta(X, Y, i, j) returns.
% The stricter levels are only computed when the one before excluded zero.
%
% The CI is the inference; there are no p-values. Six pairs are tested per
% metric and no correction is applied: say so in the caption.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 5 || isempty(nBoot), nBoot = 10000; end
if nargin < 6 || isempty(seed),  seed  = 1;     end

P = struct('i',i,'j',j,'rhoI',NaN,'rhoJ',NaN,'delta',NaN, ...
           'CI95',[NaN NaN],'CI99',[NaN NaN],'CI999',[NaN NaN],'stars','','nDyads',0);

usable  = any(isfinite(XGTK(:,[i j])) & isfinite(XMAN(:,[i j])), 2);
dyadIdx = find(usable);
P.nDyads = numel(dyadIdx);
if P.nDyads < 3, return; end

P.rhoI  = rhoOf(XGTK, XMAN, i, dyadIdx);
P.rhoJ  = rhoOf(XGTK, XMAN, j, dyadIdx);
P.delta = P.rhoI - P.rhoJ;
if ~isfinite(P.delta), return; end

statfun = @(ii) rhoOf(XGTK, XMAN, i, ii) - rhoOf(XGTK, XMAN, j, ii);
alphas  = [0.05 0.01 0.001];
fields  = {'CI95','CI99','CI999'};
for a = 1:3
    ci = [NaN NaN];
    try
        opt = statset('Streams', RandStream('mt19937ar','Seed',seed));
        c   = bootci(nBoot, {statfun, dyadIdx(:)}, 'Alpha',alphas(a), 'Options',opt);
        ci  = c(:)';
    catch ME
        warning('spearmanPairDelta:bootci', 'bootci failed (%s).', ME.message);
    end
    P.(fields{a}) = ci;
    if all(isfinite(ci)) && (ci(1) > 0 || ci(2) < 0)
        P.stars = repmat('*', 1, a);
    else
        break      % a stricter interval cannot exclude zero if this one did not
    end
end
end

function r = rhoOf(XGTK, XMAN, c, ii)
x = XGTK(ii, c);  y = XMAN(ii, c);
v = isfinite(x) & isfinite(y);
x = x(v);  y = y(v);
if numel(x) < 3 || numel(unique(x)) < 2 || numel(unique(y)) < 2
    r = NaN;  return
end
r = corr(x, y, 'Type','Spearman');
end
