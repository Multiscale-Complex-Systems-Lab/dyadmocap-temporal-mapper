function C = categorizeVelocity(zVelocity1, zVelocity2, thresholdMethod)
%CATEGORIZEVELOCITY  Label every time point with one of four dyadic
%behavioural categories from the two partners' z-scored joint-angle
%velocities.
%
%   C = categorizeVelocity(zVelocity1, zVelocity2)
%   C = categorizeVelocity(zVelocity1, zVelocity2, 'median')   (default)
%   C = categorizeVelocity(zVelocity1, zVelocity2, 'mean')
%
% Inputs
%   zVelocity1, zVelocity2 : N-by-F NORMALISED angular velocities of Person 1
%                            and Person 2 (same N, one column per angle).
%                            Whatever normalisation the caller chose - see
%                            normalizeVelocity.m - this function only averages
%                            across the columns and splits at the threshold:
%                              'zscore' : signed z, so "Active" means net
%                                         velocity above this person's median
%                                         and joints can cancel each other;
%                              'median' : speed / median speed per joint, so
%                                         everything is >= 0, nothing cancels,
%                                         and "Active" means moving faster than
%                                         this person's typical.
%                            (The name zVelocity is kept although it is not
%                            necessarily a z-score.)
%   thresholdMethod        : how the per-person activity threshold is set
%                            from that person's own frame-wise mean velocity.
%                            'median' (default) or 'mean'.
%
% Method
%   1. meanVelocityP(t) = mean over angles of zVelocityP(t,:)
%      -- plain mean of the signed z-velocity: NO log, NO absolute value.
%   2. thresholdP       = median (or mean) of meanVelocityP over time.
%   3. ActiveP(t)       = meanVelocityP(t) > thresholdP
%   4. category         = 1 Both Inactive | 2 Both Active |
%                         3 Person 1 Active | 4 Person 2 Active
%
% Output struct C with fields
%   colorvar, meanVelocity1, meanVelocity2, threshold1, threshold2,
%   thresholdMethod, BehaviouralCategory, cmap, colorvarname
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 3 || isempty(thresholdMethod)
    thresholdMethod = 'median';
end
if size(zVelocity1,1) ~= size(zVelocity2,1)
    error('categorizeVelocity:sizeMismatch', ...
        'zVelocity1 and zVelocity2 must have the same number of rows (time points).');
end

% -- frame-wise mean velocity of each person (signed, no log, no abs)
meanVelocity1 = mean(zVelocity1, 2);
meanVelocity2 = mean(zVelocity2, 2);

% -- per-person threshold
switch lower(thresholdMethod)
    case 'median'
        threshold1 = median(meanVelocity1, 'omitnan');
        threshold2 = median(meanVelocity2, 'omitnan');
    case 'mean'
        threshold1 = mean(meanVelocity1, 'omitnan');
        threshold2 = mean(meanVelocity2, 'omitnan');
    otherwise
        error('categorizeVelocity:badMethod', ...
            'thresholdMethod must be ''median'' or ''mean''.');
end

Active1 = meanVelocity1 > threshold1;
Active2 = meanVelocity2 > threshold2;

colorvar = zeros(size(meanVelocity1));
colorvar(~Active1 & ~Active2) = 1; % Both Inactive
colorvar( Active1 &  Active2) = 2; % Both Active
colorvar( Active1 & ~Active2) = 3; % Person 1 Active
colorvar(~Active1 &  Active2) = 4; % Person 2 Active

C.colorvar            = colorvar;
C.meanVelocity1       = meanVelocity1;
C.meanVelocity2       = meanVelocity2;
C.threshold1          = threshold1;
C.threshold2          = threshold2;
C.thresholdMethod     = lower(thresholdMethod);
C.BehaviouralCategory = {'Both Inactive','Both Active','Person 1 Active','Person 2 Active'};
C.cmap                = [0 0 0; 0 1 0; 0 0 1; 1 0 0];
C.colorvarname        = 'Behavioural Categories';
end
