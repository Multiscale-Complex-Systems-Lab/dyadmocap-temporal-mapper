function s = DYMO_numText(x, nSig)
%DYMO_NUMTEXT  A number as reporting text: 3 significant figures, never
%coarser than whole numbers, leading zero dropped when it cannot exceed 1.
%
%   DYMO_numText(0.825777679) -> '.826'
%   DYMO_numText(-0.0621765)  -> '-.0622'
%   DYMO_numText(0.00123456)  -> '.00123'
%   DYMO_numText(2966.43)     -> '2966'
%
% Matches DYMO_roundTable, so a figure and its table round the same way. The
% leading zero is dropped only for |x| < 1, which is APA's rule for quantities
% that cannot exceed one (correlations, proportions, p-values).
%
% Written by Patience Akatuhwera with help from Claude (Anthropic, an AI
% assistant). The author reviewed the code and is responsible for it.

if nargin < 2 || isempty(nSig), nSig = 3; end

if ~isfinite(x)
    s = 'n/a';
    return
end
if x == 0
    s = '0';
    return
end

d = max(nSig - 1 - floor(log10(abs(x))), 0);
s = sprintf('%.*f', d, round(x, d));

if abs(x) < 1
    s = regexprep(s, '^0\.',  '.');
    s = regexprep(s, '^-0\.', '-.');
end
end
