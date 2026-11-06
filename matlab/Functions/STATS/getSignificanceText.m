function sig = getSignificanceText(p)

% Written by Patience Akatuhwera.

% Returns significance label from a p-value.
%
% Example:
%   sig = getSignificanceText(0.003)
%   % returns '**'

if isnan(p)
    sig = 'n.s.';
elseif p < 0.001
    sig = '***';
elseif p < 0.01
    sig = '**';
elseif p < 0.05
    sig = '*';
else
    sig = 'n.s.';
end

end