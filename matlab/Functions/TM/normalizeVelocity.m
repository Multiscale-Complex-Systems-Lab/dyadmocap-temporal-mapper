function [Vn, info] = normalizeVelocity(velocity, method)
%NORMALIZEVELOCITY  Normalise each joint's angular velocity before the
%frame-wise activity score that decides the four behavioural categories.
%
%   [Vn, info] = normalizeVelocity(velocity, 'median')   % the reported analysis
%   [Vn, info] = normalizeVelocity(velocity, 'zscore')
%   [Vn, info] = normalizeVelocity(velocity, 'absz')
%
% INPUT
%   velocity : N-by-F signed angular velocity, one column per joint angle
%              (diff(angle) * Fs). Note it is SIGNED: joint angles go up and
%              down, so each column is negative about as often as positive.
%   method   : 'zscore' (default), 'absz' or 'median'.
%
% THE THREE METHODS
%
%   'zscore'  z = (v - mean(v)) / std(v), per joint, on the SIGNED velocity.
%             This is what `zscoreSafe` does. The frame score is then the mean of z
%             across joints, so a joint above its mean and a joint below its
%             mean cancel, and one motion peak in one channel can move the
%             mean and SD of that channel.
%
%   'absz'    |z| = |v - mean(v)| / std(v), per joint. This follows the
%             definition "a person was considered active if the average RATE
%             OF CHANGE across their 11 joint angles was greater than the
%             median": a rate of change is a magnitude, which is what the
%             absolute value provides. Because each joint's mean velocity is
%             close to zero, |z| is in practice the joint's SPEED divided by its
%             SD - a normalised rate of change - so this differs from 'median'
%             only in the normaliser (SD instead of the median).
%
%   'median'  r = |v| / median(|v|), per joint. The reported analysis, for two
%             reasons: the z-transform does not handle outliers (motion peaks
%             in specific channels), and joints can level each other out in
%             the active/passive assignment.
%             Properties: every value is >= 0, so nothing cancels when the
%             joints are averaged; the joint's typical speed lands at exactly
%             1, so the scale is interpretable (1.8 means 1.8 times this
%             joint's typical speed); and the median ignores peaks instead of
%             being pulled by them.
%
% WHY THE ABSOLUTE VALUE IS TAKEN FIRST (and it is a decision, not a detail)
%   The three properties - typical value at 1, no negative values, no
%   cancellation - hold only for a non-negative quantity. The velocity here is
%   signed and its median is close to ZERO, so dividing the signed velocity by
%   its median would divide by nearly nothing and would keep (or flip) every
%   sign. Taking the magnitude first - the angular SPEED - is what makes the
%   three properties true. It also changes what "Active" means: with 'median',
%   Active means "moving faster than this person's typical", whereas with
%   'zscore' it means "net signed velocity above this person's median".
%
% OUTPUT
%   Vn   : N-by-F normalised velocity, to be passed to categorizeVelocity.
%   info : struct with
%            method          the method actually used
%            nFilled         how many non-finite values were filled
%            nGuardedJoints  joints whose median speed was 0 or not finite
%                            ('median' only); those columns are set to 0, so
%                            that joint simply adds nothing for this dyad,
%                            the same convention zscoreSafe uses for a
%                            constant column
%            jointScale      the divisor used per joint (SD, or median speed)
%
% Bad values are handled exactly as in `zscoreSafe`, so that no dyad is ever
% dropped here: non-finite values are ignored when the divisor is computed,
% isolated gaps are filled by linear interpolation in time, and a joint that
% is missing for the whole window becomes 0.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(method)
    method = 'zscore';
end

velocity(~isfinite(velocity)) = NaN;
info.method  = lower(method);
info.nFilled = nnz(isnan(velocity));
info.nGuardedJoints = 0;

switch lower(method)

    case 'zscore'
        % identical to zscoreSafe, kept here so both methods live in one place
        mu = mean(velocity, 1, 'omitnan');
        sd = std(velocity, 0, 1, 'omitnan');
        guarded = (sd == 0 | isnan(sd));
        sd(guarded) = 1;
        info.nGuardedJoints = nnz(guarded);
        info.jointScale     = sd;
        Vn = (velocity - mu) ./ sd;

    case 'absz'
        % The magnitude of the z-scored velocity, i.e.
        % how far this joint is from its own mean rate, in SD units. Since the
        % mean rate is near zero, this is a normalised rate of change.
        mu = mean(velocity, 1, 'omitnan');
        sd = std(velocity, 0, 1, 'omitnan');
        guarded = (sd == 0 | isnan(sd));
        sd(guarded) = 1;
        info.nGuardedJoints = nnz(guarded);
        info.jointScale     = sd;
        Vn = abs((velocity - mu) ./ sd);
        Vn(:, guarded) = 0;

    case 'median'
        % 1. angular SPEED: the magnitude, so nothing can cancel later
        speed = abs(velocity);

        % 2. each joint's typical speed
        m = median(speed, 1, 'omitnan');

        % 3. a joint that does not move (median speed 0) would blow up here,
        %    so it is set aside rather than dividing by ~0
        guarded = (m <= 0 | ~isfinite(m));
        m(guarded) = 1;
        info.nGuardedJoints = nnz(guarded);
        info.jointScale     = m;

        % 4. ratio to typical: 1 = this joint's typical speed
        Vn = speed ./ m;
        Vn(:, guarded) = 0;

    otherwise
        error('normalizeVelocity:badMethod', ...
            'method must be ''zscore'', ''absz'' or ''median'' (got ''%s'').', method);
end

% ---- keep the dyad even if a few values were bad (same rule as zscoreSafe) ----
if info.nFilled > 0
    allNaN = all(isnan(Vn), 1);
    Vn(:, allNaN) = 0;
    if any(isnan(Vn(:)))
        Vn = fillmissing(Vn, 'linear', 1, 'EndValues', 'nearest');
    end
end
end
