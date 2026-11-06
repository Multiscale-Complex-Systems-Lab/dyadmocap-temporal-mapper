function [c, isSig] = DYMO_sigColor(x)
%DYMO_SIGCOLOR  Black when a result is significant, grey when it is not.
%
%   DYMO_sigColor(0.003)          -> black   (p < .05)
%   DYMO_sigColor(0.144)          -> grey
%   DYMO_sigColor([0.055 0.501])  -> black   (CI excludes 0)
%   DYMO_sigColor([-0.086 0.613]) -> grey    (CI contains 0)
%   DYMO_sigColor(NaN)            -> grey    (no test, or n.s.)
%
% A second output says whether the result was significant, so the same rule
% that picks the colour can also size the star:
%     [sigCol, isSig] = DYMO_sigColor(p);
%     starSize = baseSize * (1 + 0.5*isSig);   % 50 % larger when significant
%
% Give it a p-value (a scalar) or a confidence interval (two elements). The CI
% form is the one that matches the reading rule for the group comparisons:
% entirely above or below zero is a difference, containing zero is not.
%
% WHY ONE HELPER
% addPValueAnnotation greyed its significance star but not its p-value, and the
% other two bar plotters greyed neither, so "p = .365" was printed in the same
% black as "p < .001". Everything that states a result now asks this function
% for its colour, so a reader can see at a glance which panels found something.
%
% The grey is the [0.6 0.6 0.6] that addPValueAnnotation already used, so
% nothing that was already grey changes.
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

sigColour = [0   0   0  ];
nsColour  = [0.6 0.6 0.6];

if numel(x) == 2 && all(isfinite(x))
    isSig = (min(x) > 0) || (max(x) < 0);        % CI excludes zero
elseif isscalar(x) && isfinite(x)
    isSig = x < 0.05;                            % p-value
else
    isSig = false;                               % NaN, empty, n.s.
end

if isSig
    c = sigColour;
else
    c = nsColour;
end
end
