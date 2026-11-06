function [X, nFixed, info] = graphInputVelocity(velocity, method)
%GRAPHINPUTVELOCITY  The matrix that goes into the temporal mapper.
%
%   [X, nFixed, info] = graphInputVelocity(velocity, method)
%
% velocity : nSamples-by-22 signed angular velocity, both partners
% method   : 'zscore' (default, the reported analysis), 'median', or
%            'abszscore'
%
% 'zscore'  X = (v - mean(v)) ./ std(v) per column, SIGNED. Identical to
%           zscoreSafe(velocity) - this function calls it.
%
% 'median'  X = |v| ./ median(|v|) per column. Magnitude first, so 1 means that
%           joint moving at its typical speed, and the SIGN IS DISCARDED: a joint
%           bending and straightening at the same speed become the same value.
%           This is the same transform the behavioural categories use.
%
% WHY 'median' AND 'abszscore' EXIST
% The graph takes the z-scored SIGNED velocity, while the behavioural categories
% take the median-normalised speed. The argument for keeping the sign in the
% graph is that bending and straightening are different states; the categories
% are about amount only. 'median' tests whether direction matters to the graph
% by giving the graph the same transform as the categories.
% The counter-argument is that the sign does NOT reliably encode opening against
% closing: for a one-dimensional rotation the angle can grow, shrink through zero
% and grow again on the other side, so the same sign can mean either movement
% depending on where the joint came from, and with a three-dimensional velocity
% one cannot tell which angle produced the change. 'abszscore' drops the sign
% but keeps the z-transform, so it changes ONE thing where 'median' changes two.
%
% Neither 'median' nor 'abszscore' is the default: 'zscore' is used everywhere
% and is the reported analysis.
%
% NaN HANDLING IS THE SAME FOR BOTH METHODS, and it matters: a dyad must never be
% dropped for a few bad values. Non-finite values are counted, a column that is
% bad throughout becomes 0 (that joint then contributes nothing to the distances
% for that dyad), and isolated gaps are filled by linear interpolation in time.
% nFixed reports how many values were filled so the caller can warn.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(method)
    method = 'zscore';
end

switch lower(method)

    case 'zscore'
        [X, nFixed] = zscoreSafe(velocity);
        info = struct('method', 'zscore', 'jointScale', std(velocity, 0, 1, 'omitnan'), ...
                      'nGuardedJoints', 0, 'signDiscarded', false);

    case 'median'
        v = velocity;
        v(~isfinite(v)) = NaN;
        nFixed = nnz(isnan(v));

        speed = abs(v);
        m     = median(speed, 1, 'omitnan');

        % a joint with no usable scale (all NaN, or a median of 0 because it did
        % not move at all) would divide by zero; it is set to 0 for this dyad
        guarded    = (m <= 0 | ~isfinite(m));
        m(guarded) = 1;

        X = speed ./ m;
        X(:, guarded) = 0;

        if nFixed > 0
            allNaN = all(isnan(X), 1);
            X(:, allNaN) = 0;
            if any(isnan(X(:)))
                X = fillmissing(X, 'linear', 1, 'EndValues', 'nearest');
            end
        end

        info = struct('method', 'median', 'jointScale', m, ...
                      'nGuardedJoints', nnz(guarded), 'signDiscarded', true);

    case 'abszscore'
        % Drop the SIGN but keep the z-transform: the magnitude is taken first
        % and then z-scored, column by column, exactly as 'zscore' does - the
        % only difference from 'zscore' is abs(). This is NOT the same as
        % 'median' above: 'median' also replaces the z-transform with a division
        % by each joint's median speed, which is two changes at once.
        [X, nFixed] = zscoreSafe(abs(velocity));
        info = struct('method', 'abszscore', ...
                      'jointScale', std(abs(velocity), 0, 1, 'omitnan'), ...
                      'nGuardedJoints', 0, 'signDiscarded', true);

    otherwise
        error('graphInputVelocity:badMethod', ...
            'method must be ''zscore'', ''median'' or ''abszscore'', not ''%s''.', method);
end
end
