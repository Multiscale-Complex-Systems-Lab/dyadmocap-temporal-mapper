function [z, nFixed] = zscoreSafe(x)
%ZSCORESAFE  Column-wise z-score, (x - mean) ./ std  (std with N-1), that
%never drops a dyad because of a few bad values.
%
%   [z, nFixed] = zscoreSafe(x)
%
% * A column with zero variance gets z = 0 (instead of NaN).
% * NaN/Inf values (e.g. an angle at a frame where two markers coincide, or
%   a marker missing for the whole window) are handled so the dyad is KEPT:
%     - mean/std are computed ignoring them,
%     - isolated NaNs are filled by linear interpolation in time,
%     - a column that is NaN everywhere becomes 0 (it then adds nothing to
%       the distances, i.e. that angle is simply left out for this dyad).
%   nFixed returns how many values were filled, so the script can report it.
% For clean data the result is identical to (x - mean(x)) ./ std(x).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

x(~isfinite(x)) = NaN;
nFixed = nnz(isnan(x));

mu = mean(x, 1, 'omitnan');
sd = std(x, 0, 1, 'omitnan');
sd(sd == 0 | isnan(sd)) = 1;
z  = (x - mu) ./ sd;

if nFixed > 0
    allNaN = all(isnan(z), 1);
    z(:, allNaN) = 0;
    if any(isnan(z(:)))
        z = fillmissing(z, 'linear', 1, 'EndValues', 'nearest');
    end
end
end
